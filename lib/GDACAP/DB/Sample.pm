package GDACAP::DB::Sample;

use strict;
use warnings;

use Carp ();

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id iname internal_name tax_id accessible accession);
our $brief_fields = join(',',@fields); 
@fields = (@fields, qw(project_id description));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

our @creation = qw(iname internal_name description tax_id project_id);

our @update = qw(iname internal_name description tax_id);

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM sample WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub create {
    my ( $self, $info ) = @_;
	my $insert_list = join(',',@creation);
	my @values = @{$info}{@creation};
    my $sql = "INSERT INTO sample ($insert_list) VALUES (". join(",", ("?")x(@values)) .') RETURNING id';
	return $dbh->selectrow_array($sql,{}, @values);
}

sub update {
    my ( $self, $info ) = @_;
	$self->SUPER::update('sample',$$self{id},$info);
	$self->by_id($$self{id});
}

1;

__END__

=head1 NAME

GDACAP::DB::Sample - Samples 

=head1 SYNOPSIS


=head1 DESCRIPTION

Project can have multiple Samples. 

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut