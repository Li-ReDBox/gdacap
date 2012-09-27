package GDACAP::DB::File;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id hash type original_name size added_time);
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM file_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub project_id {
	my ($self) = @_;
	return $self->row_value('SELECT get_project_id(?,?)','file_copy',$$self{id});
}

# Utility functions
sub type {
	my ($self, $file_copy_id) = @_;
	return $$self{type} unless $file_copy_id;
	return $self->row_value('SELECT type FROM file_info WHERE id = ?', $file_copy_id);
}

# retrieve original_name and type identified by file's hash key from a project
# File copies share hash key, $project_id is needed
sub extend_hash {
	my ($self, $project_id, $hash) = @_;
	return $self->row_hashref("SELECT original_name, type FROM file_info WHERE project_id = ? AND hash = ?",$project_id, $hash);
}

# hash to file_copy_id
sub hash2id {
	my ($self, $project_id, $hash) = @_;
	return $self->row_value("SELECT id FROM file_info WHERE project_id = ? AND hash = ?",$project_id, $hash);
}

# hash to file id
sub hash2file_id {
	my ($self, $hash) = @_;
	return $self->row_value("SELECT id FROM file WHERE hash = ?", $hash);
}

# Used for checking a batch of files given their hash keys.
# This is used to verify input files.
sub hashes2ids {
	my ($self, $project_id, $hashes) = @_;
	my $statement = sprintf('SELECT id FROM file_info WHERE project_id = ? AND hash IN (%s) ORDER BY id',join(',', ('?')x@$hashes));
	my $arrref = $dbh->selectall_arrayref($statement,{},$project_id,@$hashes);
	if (@$arrref != @$hashes) {
		die("Not all files have been found in the DB\n\t",scalar(@$arrref), ' vs ',scalar(@$hashes));
	}	else {
		return $self->rows_in_one($arrref);
	}
}

# Not asscociated with any particular file
# file_type
# Retrieve a file_type_id if match any.
sub type2id {
	my ($self, $name) = @_;
	return $self->row_value('SELECT id FROM file_type WHERE iname = ?',$name);
}

# First check if it is in system, otherwise, create new file_type and return file_type_id
sub create_file_type {
	my ($self, $name, $ext) = @_;
	$name = uc($name);
	my $type_id = $self->type2id($name);
	return $type_id if $type_id;

	$ext = lc($name) unless $ext;
	return $dbh->selectrow_array('INSERT INTO file_type (iname, extension) VALUES (?, ?) RETURNING id',{},($name,$ext));
}

sub register_file {
	my ($self, $hash, $type_id, $size) = @_;
	return $dbh->selectrow_array('INSERT INTO file (hash, file_type_id, size) VALUES (?, ?, ?) RETURNING id',{}, $hash, $type_id, $size);
}

## file_copy
# no check is done, only die when duplication happens
# Someone can try to register a process again and again, so first check if it has been there
# If have record, return id and no other action is taken
sub register_file_copy {
	my ($self, $project_id, $person_id, $hash, $file_type_id, $original_name, $size) = @_;
	my $file_id = $self->hash2file_id($hash);
	# print "File id = $file_id\n";
	unless ($file_id) {
		$file_id = $self->register_file($hash, $file_type_id, $size) ;
		return $dbh->selectrow_array('INSERT INTO file_copy (file_id, original_name, person_id, project_id) VALUES (?, ?, ?, ?) RETURNING id',{},($file_id,$original_name,$person_id,$project_id));
	} else {
		return $self->hash2id($project_id, $hash);
	}
}

1;

__END__

=head1 NAME

GDACAP::DB::File - Access file information

=head1 SYNOPSIS

	my $frcd = GDACAP::DB::File->new();

  #	Get file_copy_id by hash indentifier
	$file_copy_id = $frcd->hash2file_id($project_id, $hash);

  # Get file type of a file
	$type = $frcd->type(file_copy_id);

  # Register a File (copy)
	$created_copy_id = $frcd->register_file_copy($project_id, $person_id, $hash, $file_type_id, $original_name, $size);

=head1 DESCRIPTION

This module provides interface to files in the GDACAP database scheme.
It operates on <file_info>, <file>, <file_copy> and <file_type> in database.

file_id is very private used only internally and file_copy_id is used as public identification.

Files are identified by their contents and known to users by file copies. If user files have the same content,
they are recorded only once.
If they are registered in different projects, different copies are recorded to reflect user preferences.
If they are in the same project, the second registration is ignored.

=head1 METHODS

=head2 File type

Naive file type is defined by a name and its extension. Extension is merely a description.
New file types can be created with unique names.

=over 4

=item * type

Returns the file type of current file or a file of the given id.

  my $finfo = GDACAP::DB::File->new();

  $file_type = $finfo->type($file_copy_id);
  # or in two steps
  $finfo->by_id($file_copy_id);
  $file_type = $finfo->type();

=item * create_file_type($name, $extension)

First check if it is in system, otherwise, create new file_type and return file_type_id

=back

=head2 File

Methods concern a file. For example, by calling $file->project_id() to identify to which it registered.

=over 4

=item * extend_hash($project_id, $hash)

Retrieves original_name and type identified by file's hash key from a project.
File copies share hash key, so $project_id is needed.

=item * hash2id($project_id, $hash)

Returns the file_copy_id identified by hash and project id.

=item * hashes2ids($project_id, $hashes)

Returns file copy id's of hashes in an arrary. If any one cannot be found, throws an error:
"Not all files have been found in the DB found_number vs input_number".
Used for other modules to check a batch of files given their hash keys.
One example of usage is to verify input files by their hashes.

=item * register_file_copy($project_id, $person_id, $hash, $file_type_id, $original_name, $size)

Registers a file into a project and returns the file copy id. It records into which project a file is
registered, who, what identifier hash is, what file type id is, what the original name is
and the size of a file. If it is the first time, it creates a file record and file copy record
at the same time. If file record exists in the system, but no file copy is registered in the project,
a new copy in this project is created. Otherwise no action is taken.

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
