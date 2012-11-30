package GDACAP::Table;

use strict;
use warnings;

use Carp ();
use DBI ();

use Try::Tiny;

use GDACAP::Resource qw(get_dbh);

our @ISA = qw(Exporter);
our $dbh;
our @EXPORT = qw($dbh);  # to make them availabe to derivated modules. might not be used in future
our $AUTOLOAD;

# my %permitted = (); # part of template
# sub new {
# my $class = shift;
# my $self  = $class->SUPER::new();
# my($element);
# foreach $element (keys %fields) {
	# $self->{_permitted}->{$element} = $fields{$element};
# }
# @{$self}{keys %fields} = values %fields;
# return $self;
# }

# allowed default list of fields
sub new {
	# print STDERR 'ref($dbh)=',ref($dbh),"\n";
	$dbh = get_dbh() unless ref($dbh) eq 'DBI::db';
}

sub AUTOLOAD {
	return if $AUTOLOAD =~ /::DESTROY$/; # Not dealing with DESTROY: I am not defining any
	my $self = shift;
	my $class = ref($self) or Carp::croak "$self is not an object";
	# print "Calling from $class\n";
	no strict "refs";
	my $field = $AUTOLOAD;
	$field =~ s/.*:://;
	my %t = %{$class.'::permitted'};
	unless (exists ${$class.'::permitted'}{$field} ) {
	   Carp::croak "Can't access `$field' field in class ".$class;
	}
	
	return $self->property($field,@_);
}

# Only expecting a scalar variable as $value, not for direct calling
sub property {
	my ($self, $field, $value) = @_;
	if ($value) {
	    $self->{$field} = $value;
	} 
	return $self->{$field} if exists($self->{$field});
}

# Return all values in a hash reference
sub values {
	my ($self) = @_;
	my %rv = %$self;
	return \%rv;
}

# Utilit subroutines which do query
# $class is not used but it forces derived modules to call a utility subroutine by object->xxx
sub array_hashref {
	my ($class, $sql, @bind_values)  = @_;
	my $sth = $dbh->prepare_cached($sql);
    return $dbh->selectall_arrayref($sth, {Slice=>{}}, @bind_values);
}

sub arrayref {
	my ($class, $sql, @bind_values)  = @_;
	my $sth = $dbh->prepare_cached($sql);
    return $dbh->selectall_arrayref($sth, {}, @bind_values);
}

sub row_hashref {
	my ($class, $sql, @bind_values)  = @_;
	my $sth = $dbh->prepare_cached($sql);
    return $dbh->selectrow_hashref($sth, {Slice=>{}}, @bind_values);
}

# Returns a single value
sub row_value {
	my ($class, $sql, @bind_values)  = @_;
	my $sth = $dbh->prepare_cached($sql);
	return $dbh->selectrow_array($sth,{},@bind_values);
}

# Insert a record defined by a hash to a table
# Table has to have id field for returing the id of the newly created record.
# Otherwise, explicitly say no_id as the third argument.
sub create {
    my ( $class, $table_name, $info, $no_id ) = @_;
	my $insert_list = join(',', keys(%$info));
	my @values = CORE::values(%$info);
    my $sql = "INSERT INTO $table_name ($insert_list) VALUES (". join(",", ("?")x(@values)) .')';
    if ($no_id) {
		$dbh->do($sql,{}, @values) or die $dbh->errstr;
	} else {
		return $dbh->selectrow_array($sql.' RETURNING id',{}, @values);
	}
}

sub update {
    my ( $class, $table_name, $id, $info ) = @_;
	my @fields = keys %$info;
	my @values = @{$info}{@fields};
	my @holders = map("$_ = ?", @fields);
	my $sql = "UPDATE $table_name SET ". join(',', @holders) .' WHERE id = ?';
	$dbh->do($sql,{}, @values, $id) or die $dbh->errstr;
}

# put all values in array_ref of size-element-array_ref to an array_ref
# This is used when only ids of same type are quired.
# How to use:
# $array_ref = $self->arrayref('SELECT id FROM study WHERE project_id = ?', $id);
# my $study_array = rows_in_one($array_ref);
sub rows_in_one {
	my ($self, $array_ref) = @_;
	my @value_array = (); 
	for (@$array_ref) {
		push(@value_array,$$_[0]);
	}
	return \@value_array;
}

1;

__END__

=head1 NAME

GDACAP::Table - Base module for database operations on a table

=head1 SYNOPSIS

  # DBI database handle object has to be prepared before any <Table> derived object can be created. 
	use GDACAP::Resource ();
	GDACAP::Resource->prepare('../lib/GDACAP/config.conf');
  
  # Use it to define a module to operate on a table/view by:
	use GDACAP::Table;
	our @ISA(GDACAP::Table);

	# Declare fullly qualifiled variables to allow Table or other moldules to access	
	my @fields = qw();
	our $query_fields = join(',',@fields);
	our %permitted = map { $_ => 1 } @fields;

	sub new {
		my ($class) = @_;
		$class->SUPER::new(); # make sure database handler is available
		return bless ({}, $class);
	}
	# Define whatever operations to a table/view is provided by this module
	sub example_query { ... }

=head1 DESCRIPTION

C<Table> provides a set of utility subroutines to operate on a table/view. It is not bounded to any table/view. 
For accessing data from table/view, a derived module is needed. Derived module has to define subroutine C<new> 
to call C<new> in this module to ensure C<$dbh> has been initialised.

The value of a field in a table object can be accessed/set by $Object->filed_name().

Each derived module also has to declare module variables %permitted and $query_fields. 
The %permitted just a cautious procedure to filter what can be accessed.
The second variable stores pre-built query field list. $query_fields can also provides other modules 
to reuse what field set a module normally returns to users to enable these modules to return the same set of fields. 
This is mainly used when joint tables are concerned.

To support database operations, it uses C<DBI> and holds $dbh (DBI::db).

The values held in the object can be returned in a hash reference by C<values()>. This is useful when only values are interested in instead of object itself.

=head1 METHODS

These methods are utility subrountine. They do not access any module/object data. 
They all have $class as the first argument. It forces derived modules to call a utility subroutine by $slef->xxx instead of a fully qualified name.

=over 4

=item * array_hashref - returns an array reference of hashes. 

=item * arrayref - returns an arrary reference

=item * row_hashref - returns a hash reference

=item * row_value - returns a scalar value

=item * rows_in_one - put all values in array_ref of array_ref to an array_ref

This is used when only ids of same type are queried. This is similar to C<DBI::selectcol_arrayref>. The differences are: 1. this only transpose one column and does not do query.

 How to use:
 $array_ref = $self->arrayref('SELECT id FROM study WHERE project_id = ?', $id);
 my $study_array = rows_in_one($array_ref);

=back
 
=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
