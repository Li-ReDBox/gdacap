package GDACAP::DB::Project;

use strict;
use warnings;

use Try::Tiny;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

# Read from project_info (VIEW)
my @fields = qw(id iname alias description start_date end_date phase expoint);
our $brief_fields = join(',',@fields); # This is a summary of a project
@fields = (@fields, qw(anzsrc_for_code anzsrc_for phase_status_id memo));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

# for Web interface, operates on project table
our @creation = qw(iname alias description start_date anzsrc_for_code);
our @update_fields = (@creation,'phase_status_id');
our @creation_optional = qw(end_date memo expoint);
	
sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
# returns 1: successful, undef: failed
sub create {
    my ( $self, $person_id, $info ) = @_;
	my $insert_list = join(',',@creation);
	my @values = @{$info}{@creation};
	# pick up from optional fields which are not empty
	for (@creation_optional) {
		if ($$info{$_}) { push(@values,$$info{$_}); $insert_list .= ','.$_; }
	}
    my $sql = "INSERT INTO project ($insert_list) VALUES (". join(",", ("?")x(@values)) .') RETURNING id';
	my $id = 0;
	$dbh->begin_work;
	try {
		$id = $dbh->selectrow_array($sql,{}, @values);
		if ( $id ) {
			my $role = GDACAP::DB::Personrole->new($person_id);
			my $role_type_id = $role->type_id('Administrator');
			$role->assign($id, $role_type_id) or die $dbh->errstr;
		}
		$dbh->commit;
	} catch {
		print STDERR "$_\n";
		$id = 0;
		$dbh->rollback;
	};
	return $id;
}

sub update {
    my ( $self, $info ) = @_;
	$self->SUPER::update('project',$$self{id},$info);
	$self->by_id($$self{id});
}

sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM project_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub alias2id {
	my ($self, $alias) = @_;
	return $self->row_value("SELECT id FROM project WHERE alias = ?",$alias);
}

sub has_Manager {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	return  $self->row_value("SELECT count(*) FROM personrole pr, role_type rt WHERE pr.project_id = ? AND pr.role_type_id = rt.id AND rt.iname = 'Manager'", $project_id);	
}

sub members {
	my ($self) = @_;
	require GDACAP::DB::Personrole;
	return GDACAP::DB::Person::pretty_all_titles($self->array_hashref("SELECT $GDACAP::DB::Personrole::person_fields FROM personrole_info WHERE project_id = ?",$$self{id}));
}

# returns all people can have a role in a project
sub non_members {
	my ($self) = @_;
	return GDACAP::DB::Person::pretty_all_titles($self->array_hashref("SELECT $GDACAP::DB::Person::brief_fields FROM person WHERE is_active = 'true' AND id NOT IN (SELECT person_id FROM personrole WHERE project_id = ?)", $$self{id}));
}

sub samples {
	my ($self) = @_;
	require GDACAP::DB::Sample;
	my $brief_fields = $GDACAP::DB::Sample::brief_fields;
	return $self->array_hashref("SELECT $brief_fields FROM sample WHERE project_id = ?",$$self{id});
}

sub studies {
	my ($self) = @_;
	require GDACAP::DB::Study;
	my $brief_fields = $GDACAP::DB::Study::brief_fields;
	return $self->array_hashref("SELECT $brief_fields FROM study_info WHERE project_id = ?",$$self{id});
}

# ## Project file section
# Get current project or some project's file list
sub files {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	return $self->array_hashref('SELECT id, hash, type, original_name, size, added_time FROM file_info WHERE project_id = ?',$project_id);
}

# Check if a project has expoint set
sub can_export {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	return $self->row_value('SELECT expoint FROM project WHERE id = ?',$project_id);
}

# Get files can be decomissioned from a project
sub files_can_dec {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	return $self->array_hashref('SELECT id, hash, type, original_name, size, added_time FROM file_info,single_copy WHERE file_info.file_id = single_copy.file_id AND deleted = FALSE AND project_id = ?',$project_id);
}

# Get files can be exported from a project
sub files_can_expo {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	return $self->array_hashref('SELECT id, hash, type, original_name, size, added_time FROM file_info WHERE deleted = FALSE AND project_id = ?',$project_id);
}

# End of Project file_copy section

# For constructing project navigation panel
# %children = (samples=>[{id,iname},{}id,iname],studies=>[{id=>,iname=>,experiment=[{id,iname}]}]);
sub children {
	my ($self, $id) = @_;
	my %ids = ();
	$ids{samples} = $self->array_hashref('SELECT id,iname FROM sample WHERE project_id = ?', $id);
	$ids{studies} = $self->array_hashref('SELECT id,iname FROM study WHERE project_id = ?', $id);
	for (@{$ids{studies}}) {
		$$_{experiments} = $self->array_hashref('SELECT id, iname FROM experiment WHERE study_id = ?', $$_{id});
	}
	return \%ids;
}

sub root_processes {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	require GDACAP::DB::Process;
	my $sql = "SELECT $GDACAP::DB::Process::brief_fields FROM process_info, root_processes WHERE id=process_id AND project_id = ?";
	return $self->array_hashref($sql,$project_id);
}

sub processes {
	my ($self, $project_id) = @_;
	$project_id = $$self{id} unless $project_id;
	require GDACAP::DB::Process;
	my $sql = "SELECT $GDACAP::DB::Process::brief_fields FROM process_info, process_out_file_info WHERE id=process_id AND project_id = ?";
	return $self->array_hashref($sql,$project_id);
}

1;

__END__

=head1 NAME

GDACAP::DB::Project - Data manipulations to table project and queries to view project_info and associated objects 

=head1 SYNOPSIS
 
 use strict;
 use warnings;
 use Data::Dumper;

 use GDACAP::Resource ();
 GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

 # Create an instance
 use GDACAP::DB::Project;

 my $project = GDACAP::DB::Project->new();
 print "GDACAP::DB::brief_fields = $GDACAP::DB::Project::brief_fields\n";
 print "Perminted keys are \n";
 for (keys %GDACAP::DB::Project::permitted)
 {
 	print "GDACAP::DB::permitted $_\n";
 }

 $project->by_id(26);
 print Dumper($project->values());
 my $members = $project->members();
 print Dumper($members);
 print Dumper($project->studies());
 print Dumper($project->samples());
 print Dumper($project->files());
 print Dumper($project->children($project->id));
 print "Children of non-exit project 100\n";
 print Dumper($project->children(100));
 # get all associated object ids by unitlity function
  my $children_hash = $prj->children($project_id);
 
=head1 DESCRIPTION

C<GDACAP::DB::Project> returns a single record from project_info. As there are other ojbects assoicate to it, it is also the query interface to them. These interfaces only return fields summarise associated objects. The returned field lists are defined in associated fields.

=head1 METHODS

=head2 children

  %children = %{ $project->children($project->id) };
  %children = (samples=>[{id,iname},{id,iname],studies=>[{id,iname,experiments=>[{id,iname}]}, {id,iname,experiments=>[{id,iname}]}]);
 
C<children> - returns a hash reference with keys of 'samples', 'studies' and 'experiments'. The value of 'samples' or 'studies' is an arrary reference of hashes with keys of id and iname. 
Each element of sutdies has also an 'experiment' key which points to a hash reference with keys of id and iname. This is used for constructing project navigation panel.
  
=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
