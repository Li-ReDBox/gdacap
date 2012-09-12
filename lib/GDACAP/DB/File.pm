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
	my $statement = sprintf('SELECT id FROM file_info WHERE project_id = ? AND hash IN (%s)',join(',', ('?')x@$hashes));
	my $arrref = $dbh->selectall_arrayref($statement,{},$project_id,@$hashes);
	if (@$arrref != @$hashes) { 
		die("Not all files have been found in the DB\n\t",scalar(@$arrref), ' vs ',scalar(@$hashes)); 
	}	else {
		return $self->rows_in_one($arrref);
	}
}

# Not asscociated with any particular file
# file_type
# Retrieve a file_type_id if match any. Otherwise, create new file_type and return file_type_id
sub type2id {
	my ($self, $name) = @_;
	return $self->row_value('SELECT id FROM file_type WHERE iname = ?',$name);
}

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

GDACAP::DB::File - File access

=head1 SYNOPSIS

  # Connect to database

	my $procd = GDACAP::DB::File->new($dbh);
	$dbh->disconnect();

=head1 DESCRIPTION

This module represents <file_info> in the GDACAP database scheme. It also provides functions to operator <file> and <file_copy>.

To facilitate the creation of <file_copy> and <file>, <file_type> operations are also provided in this module. file_id is very private and file_copy_id is used as identification.

=head1 METHODS

=head2 type

  $file_type = $finfo->type($file_copy_id);
  # or 
  $file_type = $finfo->type();
 
C<type> - returns current file's type of a file of the given id.
  
=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
