package GDACAP::DB::Personrole;

use strict;
use warnings;

use Carp ();

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

require GDACAP::DB::Person;
require GDACAP::DB::Project;

my @fields = qw(id title given_name family_name email phone role role_type_id);
our $person_fields = join(',', @fields);
our %permitted = ();

# Project role control
my %access = (
	manager          => {project=>'w', study=>'w', sample=>'w', experiment=>'w', run=>'w', process=>'w',role=>'w'},
	administrator    => {project=>'w', study=>'w', sample=>'w', experiment=>'w', run=>'w', process=>'w',role=>'w'},
	bioinformatician => {project=>'w', study=>'w', sample=>'w', experiment=>'w', run=>'w', process=>'w'},
	operator         => {project=>'r', study=>'r', sample=>'r', experiment=>'r', run=>'w', process=>'w'}, 
	observer         => {project=>'r', study=>'r', sample=>'r', experiment=>'r', run=>'r', process=>'r'},
);

sub new {
	my ($class, $person_id) = @_;
	$class->SUPER::new();
	if ($person_id) {
		return bless ({person_id => $person_id}, $class);
	} else {
		return bless ({}, $class);
	}
}

# Project role check
sub has_right {
	my ($self, $project_id, $asset) = @_;
	return unless $project_id; return unless $asset;
	my $role = $self->project_role($project_id);
	return unless $role;
	$role = lc($role);
	return unless exists($access{$role});
	return unless exists($access{$role}->{$asset});
	return $access{$role}->{$asset};
}

# System wise Administrative role check
sub is_sys_admin {
	my ($self) = @_;
	my $rv = $self->is_super_admin();
	return defined($rv) ? 1 : 0;
}

# returns '1/0/undef';
sub is_super_admin {
	my ($self) = @_;
	return $self->row_value('SELECT is_super_administrator FROM administrator WHERE person_id = ?', $$self{person_id});
}

# project wise
# Has project role been defined in general? Only if it returns TRUE, queries to project is allowed
sub has_role {
	my ($self) = @_;
	return $self->row_value('SELECT count(*) FROM personrole WHERE person_id = ?', $$self{person_id});;
}

# No one can have more than one role in a project
sub project_role {
	my ($self, $project_id) = @_;
	Carp::croak('Project ID was not provided') unless $project_id;
	return $self->row_value('SELECT role FROM personrole_info WHERE id = ? AND project_id = ?', $$self{person_id}, $project_id);
}

sub assign {
	my ($self, $project_id, $role_type_id) = @_;
	return $dbh->do('INSERT INTO personrole (person_id, project_id, role_type_id) VALUES (?,?,?)', {}, $$self{person_id}, $project_id, $role_type_id);
}

# One person can have only one role so role_type_id is not really necessary
sub remove {
	my ($self, $project_id, $role_type_id) = @_;
	return $dbh->do('DELETE FROM personrole WHERE person_id = ? AND project_id = ? AND role_type_id = ?', {}, $$self{person_id}, $project_id, $role_type_id);
}

# return ids and names of role and project a Person has
sub projects_role {
	my ($self) = @_;
	return $self->array_hashref('SELECT project_id, project_name, role_type_id, role FROM personrole_info WHERE id = ?', $$self{person_id});
}

# returns all project informaion a Person has a role
sub projects {
	my ($self) = @_;
	my $brief_fields = $GDACAP::DB::Project::brief_fields;
	return $self->array_hashref("SELECT $brief_fields FROM project_info prj, personrole pr WHERE prj.id = pr.project_id AND pr.person_id = ?", $$self{person_id});
}

# returns all project a Person can have a role
sub projects_not_in {
	my ($self) = @_;
	return $self->array_hashref('SELECT id, iname FROM project_info WHERE phase = ? AND id NOT IN (SELECT project_id FROM personrole WHERE person_id = ?)', 'Unfinished', $$self{person_id});
}

# Get a role_type_id for insertion
sub type_id {
	my ($self, $type) = @_;
	return $self->row_value('SELECT id FROM role_type WHERE iname = ?', $type);
}

# Get all administrators, super and sysadmin
# Person with administrative roles
sub administrative {
	my ($self, $fields) = @_;
	$fields = $GDACAP::DB::Person::brief_fields unless $fields;
	if (index($fields,'title')>0) {
		return GDACAP::DB::Person::pretty_all_titles($self->array_hashref("SELECT $fields FROM person per, administrator adm WHERE is_active = 'true' AND per.id = adm.person_id"));
	} else {
		return $self->array_hashref("SELECT $fields FROM person per, administrator adm WHERE is_active = 'true' AND per.id = adm.person_id");
	}
}

# Person with normal roles
sub normal {
	my ($self) = @_;
	my $brief_fields = $GDACAP::DB::Person::brief_fields;
	return GDACAP::DB::Person::pretty_all_titles($self->array_hashref("SELECT $brief_fields FROM person WHERE is_active = 'true' AND id NOT IN (SELECT person_id FROM administrator)"));
}

# Collective records from role_type table
sub types {
	my ($self) = @_;
	return $self->array_hashref('SELECT id, iname FROM role_type');
}

1;

__END__

=head1 NAME

GDACAP::DB::Personrole - Personrole in projects and system

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

  use GDACAP::DB::Personrole;
  my $role = GDACAP::DB::Personrole->new($person_id);

  my @administrators = @{ $role->administrative() }; 
  my @projects = @{ $role->projects() }; 
	
=head1 DESCRIPTION

This is a utility module for managing person's system and project role. 

System roles are sys_admin and super_admin. sys_admin manages user accounts, system assets. super_admin manages sys_admin.

One and only role is defined for a C<Person> in a C<Project> and a C<Person> can have roles defined in different projects. To check if a C<Person> has a paticular role or has allowed roles, project identifier $project_id has to be provided. There are different project roles: Manager, Administrator, Bioinformatician, Operator and Observer. Access rights to a projec access is none, read or write. Write right includes read right. If a user has no role in a project, no access is granted. 

=over 4

=item * Manager -- Has all rights, a representive and principal investigator

=item * Administrator -- Has write rights to all assets, default the creator is the Administrator

=item * Bioinformatician -- Has write rights to all assets but role

=item * Operator -- Has write right to experiment and run

=item * Observer -- Has read-only right

=back

=head1 METHODS

=head2 C<has_right($project_id, $asset>

C<has_righ> returns operational right of current <Person> in a project given by $peroject_id: 'w' for write, 'r' fore read or undef for no right.
$asset is one of C<project study sample experiment run process role>.

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
