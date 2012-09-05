package GDACAP::DB::Anzsrc4;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# PostgreSQL specfic key word ILIKE is used for case-insensitive matching according to the active locale.
sub by_code_or_name {
    my ( $self, $cond, $max_rows ) = @_;
	$cond = '%'.$cond.'%';
    my $sql = "SELECT for_code, for_name FROM anzsrc WHERE for_code LIKE ? OR for_name ILIKE ? LIMIT ?";
	return $self->array_hashref($sql, $cond, $cond, $max_rows);
}

sub name_by_code {
    my ( $self, $code ) = @_;
    my $sql = "SELECT for_name FROM anzsrc WHERE for_code = ?";
	return $self->row_value($sql, $code);
}

sub get_all {
    my ($self) = @_;
	return $self->array_hashref("SELECT for_code, for_name FROM anzsrc ORDER BY for_name");
}

1;

__END__

=head1 NAME

GDACAP::DB::Anzsrc4 - ANZSRC-FOR code query methods

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');
  
  use GDACAP::DB::Anzsrc4;
  my $code = GDACAP::DB::Anzsrc4->new();

  my $all = $code->get_all();
  
  # Query name by code
  my $for_code = $code->name_by_code('06');
  # Query by code part
  my @gen_like = @{ $code->by_code_or_name('0604') }; 
  # Or by name part
  my @gen_like = @{ $code->by_code_or_name('geno') }; 
	
=head1 DESCRIPTION

This is a utility module for querying ANZSRC-FOR code and name from either name or code. 

=head1 METHODS

=over 4

=item * get_all -- returns all ANZSRC-FOR code and name pairs ordered by name

=item * name_by_code -- returns ANZSRC-FOR name of given code. Exact match

=item * by_code_or_name -- returns code and name pairs in an array of hash reference of given code or name part

=back

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut