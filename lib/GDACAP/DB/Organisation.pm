package GDACAP::DB::Organisation;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields= qw(id iname);
our $brief_fields = join(',',@fields);
@fields = (@fields, qw(abbreviation street suburb state postcode country phone fax webpage));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM organisation WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub name_list {
    my ($self) = @_;
	return $self->array_hashref("SELECT $brief_fields FROM organisation");
}

sub get_all {
    my ($self) = @_;
	return $self->array_hashref("SELECT $query_fields FROM organisation");
}

1;

__END__

=head1 NAME

GDACAP::DB::Organisation - ANZSRC-FOR code query methods

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');
  
  use GDACAP::DB::Organisation;
  my $org = GDACAP::DB::Organisation->new();

  my $all = $org->get_all();
  
=head1 DESCRIPTION

This is a utility module for querying organisation table. 

=head1 METHODS

=over 4

=item * name_list -- returns list of id and inames

=item * get_all -- returns all organisations

=back

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut