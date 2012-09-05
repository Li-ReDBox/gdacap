package GDACAP::DB::Phase;

use strict;
use warnings;

use Carp ();

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(description);
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
	return $self->row_value('SELECT description FROM phase_status WHERE id = ?',$id);
}

sub phases {
	my ($self) = @_;
	return $self->array_hashref('SELECT id, description FROM phase_status');
}

# Might not useful
sub mapper { 
	my ($self) = @_;
	my $rv = $self->phases();
	my %rhash = ();
	for (@$rv) {
		$rhash{$$_{id}} = $$_{description};
	}
	return \%rhash;
}

1;

__END__

=head1 NAME

GDACAP::DB::Phase - Project or Study phases 

=head1 SYNOPSIS


=head1 DESCRIPTION

Project can have multiple phases. Namely, Unfinished, Assessing,Finished, Publishable and Published. Onece Published, it will be read-only.

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut