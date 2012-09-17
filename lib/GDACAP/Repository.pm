package GDACAP::Repository;

use strict;
use warnings;

require File::Spec;
require Carp;

my $tail_space = qr/\s+$/;

sub new {
	my ($class, $root) = @_;
	return unless ($root && -e -r $root);
	my $self = {
		ROOT => $root,  # Root path of the repository
	};
	bless ($self, $class);
	return $self;
}

sub root {
	my ($self) = @_;
	return $self->{ROOT};
}

# Real path should not be revealed to outside.
sub fpath {
	my ($self, $hash) = @_;
	$hash =~ s/$tail_space//;
	return File::Spec->catfile($self->root,$hash);
}

sub exist {
	my ($self, $hash) = @_;
	my $fpath = $self->fpath($hash);
	return (-e $fpath);
}

sub file_handle {
	my ($self, $hash) = @_;
	my $fpath = $self->fpath($hash);
	return unless (-e $fpath);
	open(my $fh, '<', $fpath) or Carp::croak("Failed to open $fpath!", "\nreason=",$!);
	return $fh;
}

1;

__END__

=head1 NAME

GDACAP::Repository - Repository query module

=head1 DESCRIPTION

C<GDACAP::Repository> provides interface of a file repository. It 

=head1 SYNOPSIS

	use GDACAP::Resource qw(get_repository);
	my $repository = get_repository;
	print "Repository settings:\n";
	print "source path = $$repository{source}, target path = $$repository{target}\n";
	use GDACAP::Repository;
	my $repo = GDACAP::Repository->new($$repository{target});
	croak('Cannot access repository at '.$$repository{target}) unless $repo;

	my $file_key = '90543c99fb044bde396f0246174c904d';
	if ($repo->exist($file_key)) {
		my $fpath = $repo->fpath($file_key);
		print "Real path of $file_key = $fpath\n";
	}

=head1 METHODS

=head2 new($repository_file_path)

The constructor. If the directory does not exist or readable, it returns undef.
The module only supports OO methods. 
All files are saved in a directory which is set in the constructor.This path is
saved as ROOT. To oustside, the only way to communicate is to provide file key - name.

=head2 root

Returns where the current repository root is.

=head2 fpath($file_key)

Private method. Returns the real path of a given file hash key. Currently, it is concstructed by:
	File::Spec->catfile($self->root,$hash);

=head2 exist($file_key)

Returns if a file identified by the $file_key exist.

=head2 file_handle($file_key)

Opens a file identified by $file_key and returns file handler for reading.

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
