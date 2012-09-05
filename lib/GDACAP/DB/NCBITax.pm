package GDACAP::DB::NCBITax;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my $query_fields = 'tax_id, name_txt, name_class';

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

sub by_id_or_name {
    my ( $self, $cond, $max_rows ) = @_;
    my $sql = "SELECT $query_fields FROM tax_name WHERE name_class NOT IN ('misspelling')";
    if ($cond =~ /^\d+\z/) {   # whole number, check tax_id column
		$sql .= ' AND CAST(tax_id AS TEXT) LIKE ?';
		$cond = $cond.'%';
    } else{           # not a whole number check name_txt and unique_name
		$sql .= ' AND name_txt ILIKE ?';
		$cond = '%'.$cond.'%';
    }
	$sql .= ' ORDER BY tax_id  LIMIT ?';
	return $self->array_hashref($sql, $cond, $max_rows);
}

# sub with_tax_id_and_name_txt_and_unique_name_like {
    # $hash{statement} = "SELECT 	tax_id, name_txt, unique_name, name_class FROM tax_name WHERE CAST(tax_id AS TEXT) LIKE $cond LIMIT ?";
# sub with_name_txt_and_unique_name_like {
    # $hash{statement} = "SELECT 	tax_id, name_txt, unique_name, name_class FROM tax_name WHERE (name_txt ILIKE $cond )	LIMIT ?  ";

sub by_id {
    my ( $self, $tax_id ) = @_;
	my $sql = "SELECT $query_fields FROM tax_name WHERE tax_id = ? AND name_class NOT IN ('misspelling') ORDER BY name_class, name_txt";
	return $self->array_hashref($sql, $tax_id);
}

1;

__END__

=head1 NAME

GDACAP::DB::NCBITax - Queries to a local NCBI taxonomy database

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');
  
  use GDACAP::DB::Anzsrc4;
  my $tax = GDACAP::DB::NCBITax->new();

  my $all = $tax->get_all();
  
  # Query name by tax
  my $for_code = $tax->name_by_code('06');
  # Query by code part
  my @gen_like = @{ $tax->by_code_or_name('0604') }; 
  # Or by name part
  my @gen_like = @{ $tax->by_code_or_name('geno') }; 
	
=head1 DESCRIPTION

This is a utility module for querying a local copy of NCBI taxonmy database. 

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