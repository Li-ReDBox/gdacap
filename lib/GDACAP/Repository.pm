package GDACAP::Repository;

use strict;
use warnings;

require File::Spec;
require Carp;

my $tail_space = qr/\s+$/;

sub new {
	my ($class, $root) = @_;
	return unless ($root && -e $root);
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