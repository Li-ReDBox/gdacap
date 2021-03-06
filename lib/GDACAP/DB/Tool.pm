package GDACAP::DB::Tool;

use strict;
use warnings;

use Carp ();
use DBI ();
use GDACAP::Table;

our @ISA = qw(GDACAP::Table);

my @fields = qw(iname version description);
our $query_fields = join(',',@fields);

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Retrieve a tool_id if match any. Otherwise, create new tool and return tool_id
sub tool_id {
	my ($self, $tool, $version) = @_;
	return $self->row_value('SELECT id FROM tool WHERE iname = ? AND version = ?', $tool, $version);
}

sub create_tool {
	my ($self, $tool, $version) = @_;
	return $dbh->selectrow_array('INSERT INTO tool (iname, version) VALUES (?,?) RETURNING id',{}, $tool,$version);
}

sub get_create_tool {
	my ($self, $tool, $version) = @_;
	my $tool_id = $self->tool_id($tool, $version);
	return $tool_id if $tool_id;
	return $self->create_tool($tool, $version);
}


sub all {
	my $self = shift;
	return $self->array_hashref("SELECT $query_fields FROM tool order by id");
}

1;

__END__

=head1 NAME

GDACAP::DB::Tool - Queries about Tools in the system 

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

  use GDACAP::DB::Tool;
  my $tools = GDACAP::DB::Tool->new();

  my @tool_list = @{ $tools->all() }; 
	
=head1 DESCRIPTION

A tool can be any piece of software or hardware used to generate outcomes which are significant to an analysis.
They can be a software package or a script developed locally. A Tool is identified by Name, Version. It can have
description.

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

Copyright (C) 2012  The University of Adelaide

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
