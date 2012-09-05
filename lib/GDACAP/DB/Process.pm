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

	my %meta = (iname => $$info{Name}, category => $$info{Category});
	$meta{configuration} = $$info{Configuration} if $$info{Configuration};	
	$meta{comment} = $$info{Comment} if $$info{Comment};	

	my $in_ids = [];
	if (exists($$info{Input})) {
		my $fdal = GDACAP::DB::File->new();
		$in_ids = $fdal->hashes2ids($$info{project_id},$$info{Input}); 
	}
	
	my $id = undef;
	$dbh->begin_work;
	try {
		require GDACAP::DB::Tool;
		my $tool = GDACAP::DB::Tool->new();
		$meta{tool_id} = $tool->get_create_tool($$info{Tool}->{'Name'},$$info{Tool}->{'Version'});
		$id = $self->SUPER::create('process', \%meta);
		if ( $id ) {
			my $out_ids = $self->register_outfiles($$info{person_id}, $$info{project_id}, $$info{Output});
			$self->link_files($id, 'out', $out_ids);
			$self->link_files($id, 'in', $in_ids) if $in_ids;
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

sub link_files {
	my ($self, $process_id, $direction, $file_copy_ids) = @_;
    my $sth = $dbh->prepare('INSERT INTO process_'.$direction.'_file (process_id, file_copy_id) VALUES (?, ?)') or Carp::croak($dbh->errstr."\n\t");
	for (@$file_copy_ids) {
		$sth->execute($process_id, $_) or Carp::croak($dbh->errstr);
	}
}

# Files associate with a single process
sub files {
	my ($self, $direction) = @_;
	$direction = 'out' unless $direction;
	return $self->array_hashref('SELECT file_copy_id,original_name,added_time FROM process_'.$direction.'_file_info WHERE process_id = ?',$$self{id});
}

sub processed {
	my ($self, $file_copy_id) = @_;
	my $sql = "SELECT $brief_fields FROM process_info, process_out_file WHERE process_info.id = process_out_file.process_id AND file_copy_id = ?";
	return $self->row_hashref($sql,$file_copy_id);
}

# Collections
# Get downstream processes which takes a file as input or generated it
sub downstream {
	my ($self, $file_copy_id) = @_;
	my $sql = "SELECT $brief_fields FROM process_info, process_in_file WHERE process_info.id = process_in_file.process_id AND file_copy_id = ?";
	return $self->array_hashref($sql,$file_copy_id);
}

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

1;

__END__

=head1 NAME

GDACAP::DB::Process - Create or query Process from database

=head1 Synopsis

	my $procd = GDACAP::DB::Process->new();
	
	# To get all information about a process given its $id
	my $proc_info = $procd->by_id($id);
	$in_file_copy_ids = $proc_info->files('in',$id);
	$out_file_copy_ids = $proc_info->files('out',$id);
	
	# Create a new process
	my $process_id = $procd->create(\{});
	
	# Get downstream processes which takes a file as input or generated it - one step
	@downstream_proc_infos = @{$procd->downstream($file_copy_id)};
	
	# Query which process this file_copy was processed from - should be only one
	$proc_info = $procd->processed($file_copy_id);
	
	# look back where this file is from
	@process_id_in_copy_id_out_copy_id = @{$proc->all_descendants($file_copy_id)};
	# look forward to find out where this file ends up at
	@process_id_in_copy_id_out_copy_id = @{$proc->all_ancestors($file_copy_id)};

=head1 Description

This is a utility module for registering a process and associated files. It is the only way to put files into system.

C<Process> provides functions to establish a process chain or pipeline. To crawl through, do:

=over 2

=item 1. Find the Process in which a file copy was generated from by calling C<processed($file_copy_id)>.

=item 2. Find information of a process by calling C<by_id($id)>;

=item 3. To find all files generated from the current process by calling C<files('out')>; or if want to go backwards, by calling C<files('in')>;

=item 4. To find out the processes further process a file by calling C<downstream($file_copy_id)>.

=item 5. Repeate steps of 2 to 4.

=back

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut