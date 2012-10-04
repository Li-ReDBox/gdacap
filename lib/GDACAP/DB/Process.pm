package GDACAP::DB::Process;

use strict;
use warnings;

use Try::Tiny;
require Carp;

require GDACAP::DB::File;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id name tool configuration creation_time);
our $brief_fields = join(',',@fields);
@fields = (@fields, qw(category comment));
my $query_fields = join(',',@fields);
my $graph_node = 'in_copy_id,out_copy_id, name, category, tool';

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM process_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub project_id {
	my ($self) = @_;
	return $self->row_value('SELECT get_project_id(?,?)','process',$$self{id});
}

# my @fields = qw(iname tool_id configuration category comment creation_time);
# {iname=>, tool_id=>, configuration=>, category=>, comment=>, creation_time=>, in_copy_ids, out_copy_ids}
# Steps: 1. map input file hash to id if exist
# 2. register or get tool_id
# 3. create meta record of Process
# 4. register output files if they have not, get file_copy_ids
# 5. link in and out
# Steps 2 to 5 are in a transcation.
sub create {
	my ($self, $info) = @_;
	
	my $id = undef;
# TODO: how to avoid multiple content creation ?	
	$id = $self->search($info);
	if ($id && @$id >= 1) { # created before, the return could have undef, skip them
		for (@$id) {
			return $_ if $_;
		}
	}
#	if ($id && @$id > 1) {
#		Carp::croak("Error: more than one Porcess with same content created before.");
#	} 

	my %meta = (iname => $$info{Name}, category => $$info{Category});
	$meta{configuration} = $$info{Configuration} if $$info{Configuration};
	$meta{comment} = $$info{Comment} if $$info{Comment};

	my $in_ids = [];
	if (exists($$info{Input})) {
		my $fdal = GDACAP::DB::File->new();
		$in_ids = $fdal->hashes2ids($$info{project_id},$$info{Input});
	}

	$dbh->begin_work;
	try {
		require GDACAP::DB::Tool;
		my $tool = GDACAP::DB::Tool->new();
		$meta{tool_id} = $tool->get_create_tool($$info{Tool}->{'Name'},$$info{Tool}->{'Version'});
		$id = $self->SUPER::create('process', \%meta);
		if ( $id ) {
			my $out_ids = $self->register_outfiles($$info{person_id}, $$info{project_id}, $$info{Output});
			if ($in_ids) {
				for my $in_id (@$in_ids) {
					foreach(@$out_ids) { 
						Carp::croak("Error: new link creates loop $in_id => $_ => $in_id") if( $self->is_loop($in_id, $_));
					}
				}
				$self->link_files($id, 'in', $in_ids) if $in_ids;
			}
			$self->link_files($id, 'out', $out_ids);
#			$self->link_files($id, 'in', $in_ids) if $in_ids;
			$dbh->commit;
			$$self{id} = $id;
		} else {
			$dbh->rollback;
		}
	} catch {
		print STDERR "$_\nRooling back.";
		$id = undef;
		$dbh->rollback;
	};
	return $id;
}

# When a file_copy cannot be created, the whole process dies as here has no error trap
# Currently processed hash keys are:
	# "OriginalName":"transmeta_ping.txt",
	# "Hash":"8d49cc9195dd9dfbfbd583f48441b0ca",
	# "Type":"text",
	# "Size":1471587756
sub register_outfiles {
	my ($self, $person_id, $project_id, $outfiles) = @_;

	my ($file_type_id, $file_copy_id, @file_copy_ids);

	my $fdal = GDACAP::DB::File->new();
	foreach(@$outfiles) {
		$file_type_id = $fdal->create_file_type($$_{'Type'});
		# $project_id, $person_id, $hash, $file_type_id, $original_name, $size
		$file_copy_id = $fdal->register_file_copy($project_id, $person_id, $$_{'Hash'}, $file_type_id, $$_{'OriginalName'}, $$_{'Size'});
		push(@file_copy_ids,$file_copy_id);
	}
	return \@file_copy_ids;
}

# Stop self-link by checking if out_file_copy_id is in the linked path
# If the order can be reversed with existing relations, then new link is creating a loop
sub is_loop {
	my ($self, $in_copy_id, $out_copy_id) = @_;
	return $self->row_value("SELECT count(*) FROM seek_process_children(?) WHERE out_copy_id = ? ",$out_copy_id, $in_copy_id);
}

sub link_files {
	my ($self, $process_id, $direction, $file_copy_ids) = @_;
    my $sth = $dbh->prepare('INSERT INTO process_'.$direction.'_file (process_id, file_copy_id) VALUES (?, ?)') or Carp::croak($dbh->errstr."\n\t");
	for (@$file_copy_ids) {
		$sth->execute($process_id, $_) or Carp::croak($dbh->errstr);
	}
}

# End of creation

# Files associate with a single process
sub files {
	my ($self, $direction) = @_;
	$direction = 'out' unless $direction;
	return $self->array_hashref('SELECT file_copy_id,original_name,added_time FROM process_'.$direction.'_file_info WHERE process_id = ?',$$self{id});
}

# Get the immediate processes from which a file is from
sub processed {
	my ($self, $file_copy_id) = @_;
	my $sql = "SELECT $brief_fields FROM process_info, process_out_file WHERE process_info.id = process_out_file.process_id AND file_copy_id = ?";
	return $self->array_hashref($sql,$file_copy_id);
}

# Get the immediate downstream processes which takes a file as input
sub took {
	my ($self, $file_copy_id) = @_;
	my $sql = "SELECT $brief_fields FROM process_info, process_in_file WHERE process_info.id = process_in_file.process_id AND file_copy_id = ?";
	return $self->array_hashref($sql,$file_copy_id);
}

# Collections
# Tree (chain, pipeline) search
# Get all derived processes and files of a file_copy_id
sub all_descendants {
	my ($self, $file_copy_id) = @_;
	return $self->array_hashref("SELECT $graph_node FROM seek_process_children(?) spc, process_info WHERE process_info.id = spc.process_id",$file_copy_id);
}

# Get all source processes and files of a file_copy_id
sub all_ancestors {
	my ($self, $file_copy_id) = @_;
	return $self->array_hashref("SELECT $graph_node FROM seek_parent_file(?) spc, process_info WHERE process_info.id = spc.process_id",$file_copy_id);
}

# Get all linked processes and files of a file_copy_id in both direction.
# When the file is the very last one, seek_process will return nothing as direction is wrong, then try all_ancestors.
sub full_tree {
	my ($self, $file_copy_id) = @_;
	my $rv = $self->array_hashref("SELECT $graph_node FROM seek_process(?) spc, process_info WHERE process_info.id = spc.process_id",$file_copy_id);
	if (@$rv == 0) { $rv = $self->all_ancestors($file_copy_id); }
	return $rv;
}

# Query 

# Find a Process by its metadata
# Process Name, Category and etc
# Tool Name and Version have to appear at the same time.
# TODO: run_upload is the same for some users: only Outcome changes which is not part of Metadata.
sub search {
	my ($self, $info) = @_;

	my $tool_id;
	if (exists($$info{Tool})) {
		unless (defined($$info{Tool}->{'Name'}) && defined($$info{Tool}->{'Version'})) {
			Carp::carp('In completed Tool information: needs Name and Version.');
			return;
		}
		$tool_id = $self->row_value("SELECT id FROM tool WHERE iname = ? AND version =? ", ($$info{Tool}->{'Name'},$$info{Tool}->{'Version'}));
		return unless $tool_id;
	}
	
	my %meta = ();
	$meta{iname} = $$info{Name} if $$info{Name};
	$meta{category} = $$info{Category} if $$info{Category};
	$meta{configuration} = $$info{Configuration} if $$info{Configuration};
	$meta{comment} = $$info{Comment} if $$info{Comment};
	
	unless (%meta || $tool_id) {
		Carp::carp('No meta key is given for searching Process');
		return;
	}
	
    my @fields = sort keys %meta;
    my @values = @meta{@fields};
    my $qualifier;
    if (%meta) { $qualifier = "WHERE ".join(" AND ", map { "$_=?" } @fields); }
    if ($tool_id) {
		if ($qualifier) { $qualifier .= ' AND tool_id = ?'; 
		} else { $qualifier = "WHERE tool_id = ?"; }
		push(@values, $tool_id);
	}

	my $ids = $self->rows_in_one($self->arrayref("SELECT id FROM process $qualifier", @values));
#	print "$dbh->{Statement}\n";
	if (@$ids >= 1 ) {
		unless (defined($$info{project_id})) {
			Carp::carp('No project id is provided and file copy cannot be identified.');
			return;
		}
#		"Meta leads to one match of Process so you can verify files: all listed files have to come from the same Process.\n";
		my $frcd = GDACAP::DB::File->new();
		my ($fc_ids, $statement, $f2pid);
		my @hashes = ();
		my $id_num = scalar(@$ids) -1;
CHECK: for my $index (0 .. $id_num) {
			if (exists($$info{Output})) {
				@hashes = ();
				foreach(@{$$info{Output}}) {
					if (ref($_) eq '') { push(@hashes, $_); }  # Less useful but simple and direct
					elsif (defined($$_{'Hash'})) { push(@hashes, $$_{'Hash'}); }
					else { Carp::crok("Unkonw Output type: neither an arrary of strings or hashes with key Hash."); }
				}
				undef $fc_ids;
				try { $fc_ids = $frcd->hashes2ids($$info{project_id},\@hashes); };
				unless ($fc_ids) { 
					delete $$ids[$index];
					next CHECK; 
				}
				$statement = sprintf("SELECT DISTINCT process_id FROM process_out_file WHERE process_id = ? AND file_copy_id IN (%s)", join(',', ('?')x@$fc_ids));
				$f2pid = $dbh->selectrow_array($statement,{},$$ids[$index],@$fc_ids);
				unless ($f2pid) {
					delete $$ids[$index];
					next CHECK;
				}
			}
			if ($f2pid && exists($$info{Input})) {
				try { $fc_ids = $frcd->hashes2ids($$info{project_id},$$info{Input}); };
				unless ($fc_ids) { # if file is not in system return null
					delete $$ids[$index];
					next CHECK; 
				}
				$statement = sprintf("SELECT DISTINCT process_id FROM process_in_file WHERE process_id = ? AND file_copy_id IN (%s)", join(',', ('?')x@$fc_ids));
				$f2pid = $dbh->selectrow_array($statement,{},$$ids[$index],@$fc_ids);
				unless ($f2pid) { # not associate with this process, return null
					delete $$ids[$index];
				}
			}	
		}	
	}
	
	
#	if (@$ids == 1 ) {
#		unless (defined($$info{project_id})) {
#			Carp::carp('No project id is provided and file copy cannot be identified.');
#			return;
#		}
##		"Meta leads to one match of Process so you can verify files: all listed files have to come from the same Process.\n";
#		my $frcd = GDACAP::DB::File->new();
#		my ($fc_ids, $statement, $f2pid);
#		if (exists($$info{Input})) {
#			try { $fc_ids = $frcd->hashes2ids($$info{project_id},$$info{Input}); };
#			return unless $fc_ids; # if file is not in system return null
#			$statement = sprintf("SELECT DISTINCT process_id FROM process_in_file WHERE process_id = ? AND file_copy_id IN (%s)", join(',', ('?')x@$fc_ids));
#			$f2pid = $dbh->selectrow_array($statement,{},$$ids[0],@$fc_ids);
#			return unless $f2pid; # not associate with this process, return null
#		}	
#		if (exists($$info{Output})) {
#			my @hashes = ();
#			foreach(@{$$info{Output}}) {
#				if (ref($_) eq '') { push(@hashes, $_); }  # Less useful but simple and direct
#				elsif (defined($$_{'Hash'})) { push(@hashes, $$_{'Hash'}); }
#				else { Carp::crok("Unkonw Output type: neither an arrary of strings or hashes with key Hash."); }
#			}
#
#			undef $fc_ids;
#			try { $fc_ids = $frcd->hashes2ids($$info{project_id},\@hashes); };
#			return unless $fc_ids;
#			$statement = sprintf("SELECT DISTINCT process_id FROM process_out_file WHERE process_id = ? AND file_copy_id IN (%s)", join(',', ('?')x@$fc_ids));
#			$f2pid = $dbh->selectrow_array($statement,{},$$ids[0],@$fc_ids);
#			return unless $f2pid;
#		}	
#	}
	return $ids;
}

1;

__END__

=head1 NAME

GDACAP::DB::Process - Create or query Process from database

=head1 Synopsis

	my $procd = GDACAP::DB::Process->new();

	# To get all information about a process given its $id
	my $proc_info = $procd->by_id($id);
	$in_file_copy_ids = $procd->files('in',$id);
	$out_file_copy_ids = $procd->files('out',$id);

	# Query from which processes this file_copy was processed - one step
	$proc_info = $procd->processed($file_copy_id);

	# Query downstream processes which takes a file as input - one step
	@downstream_proc_infos = @{$procd->took($file_copy_id)};

	# look back where this file is from
	@process_id_in_copy_id_out_copy_id = @{$procd->all_ancestors($file_copy_id)};
	# look forward to find out where this file ends up at
	@process_id_in_copy_id_out_copy_id = @{$procd->all_descendants($file_copy_id)};

	# Create a new process
	my $info = {Name=>"The first step of analysis",
				Category => "Analysis",
				Configuration => "a=c,d=e",
				Comment => "This is used for testing grow a pipeline",
				Input => ['52a796d5f88c3ce61e75fc1729b39e91'],
				Output => ['eb6108ba2a40e58cae37bf29604bb009'],
				project_id => 26, 
	};
	my $values = $procd->search($info);
	if ($values && @$values) { 
		if (@$values == 1) {
			print "Record has been created before.\n";
		} else {
			print "Multiple records found\n";
		}
	} else { 
		print "No record found\n"; 
		my $process_id = $procd->create($info);
	}

=head1 Description

This module manages records of B<Process> and and associated files in database.
It does not check physical existence of files at any time.

C<Process> provides functions to establish a process chain or pipeline. To crawl through, do:

=over 2

=item 1. Find the B<Process>es in which a file copy was generated from by calling C<processed($file_copy_id)>.
It is possible that files whth same content generated from different B<Process>es.

=item 2. Find information of a process by calling C<by_id($id)>;

=item 3. To find all files generated from the current process by calling C<files('out')>;
or if want to go backwards, by calling C<files('in')>;

=item 4. To find out the immediate processes further process a file by calling C<took($file_copy_id)>.

=item 5. Repeate steps of 2 to 4.

=back

Same file can appear in a chain only once. There is no problem when a file being registered for the first time.
When a previously registered file is being linked to a process chain, to avoid having self-link loop,
it needs to check if a file has been in the chain as input before:

  $existed = $procd->in($in_copy_id,$out_copy_id);
  die "$out_id has been in the chain";

$in_copy_id is to which file the new file ($out_copy_id) link.

=head1 METHODS

=over 4

=item * is_loop($in_copy_id, $out_copy_id)

Private method. A safe guard to stop creating loops in a Process chain. Database checks if it is happening too.

=item * search(\%hash) 

Search for Processes satisfies conditions. If found, returns process ids in an array even there is only one.

This is mainly designed for checking existence of a Process to avoid creating a Process twice. Construct a hash with all keys which completely describe a Process and call the method. If it is found, one id will be returned. Be aware, file copies are defined in project scope, so project id is needed when file checksums are presented. Tool is defined by Name and Version, so both have to be provided.

It can also be used to find out all process which have some metadata, for example, in a category and used a tool. File checksum alone cannot be used. For searches using files as conditions, use other query methods. 

=back

=head2 Information about a Process

=over 4

=item * files($direction)

Returns an array of file information associateed with the current B<Process>.
C<$direction> is optional and can either be 'in' or 'out'.
The default value of the argument is 'out'. Each element of the array has:
file_copy_id original_name added_time.

=item * processed($file_copy_id)

Finds out what process generated the concerned file. It's the short name of processed_from. It's a synonym of generated_from.
It returns when, what tool used and how this file was generated.
It returns information of a B<Process> in a hash with keys of id, name, tool, configuration, creation_time.

=item * took($file_copy_id)

Gets a list of immediate downstream processes which took a file as input. This is similar to C<processed> only returns newer
processes, that is to say goes to the opposite direction. The return structure is the same.

=back

=head2 Information about a set of linked Processes

These information includes in_file_copy_id,out_file_copy_id, process name, category and tool name.

=over 4

=item * all_descendants($file_copy_id)

Gets all linked derived processes and files of a file_copy_id

=item * all_ancestors($file_copy_id)

Gets all linked source processes and files of a file_copy_id

=item * full_tree($file_copy_id)

Gets all linked processes and files of a file_copy_id in both direction.

=back

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

Copyright (C) 2012 The University of Adelaide

This file is part of GDACAP.

GDACAP is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GDACAP is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GDACAP.  If not, see <http://www.gnu.org/licenses/>.

=cut
