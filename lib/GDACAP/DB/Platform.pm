package GDACAP::DB::Platform;

use strict;
use warnings;

use Carp ();

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id iname model);
our $query_fields = join(',',@fields);
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
	my $rcd = $self->row_hashref("SELECT $query_fields FROM platform WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

1;

__END__

=head1 NAME

GDACAP::DB::Platform - Platforms --not used?

=head1 SYNOPSIS


=head1 DESCRIPTION

Project can have multiple Platforms. 

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut