package GDACAP::DB::Submission;

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

# The information of a submission: type,release date, id for state query
sub info {
	my ($self, $type, $id) = @_;
	return $self->row_hashref('SELECT id, release_date FROM submission WHERE type = ? AND item_id = ?', $type, $id);
}

# Returns the last action state to normal user
sub state {
	my ($self, $sub_id) = @_;
	return $self->row_hashref('SELECT successful, action, action_time FROM submission_state WHERE submission_id = ? ORDER BY action_time DESC LIMIT 1', $sub_id);
}

1;

__END__

=head1 NAME

GDACAP::DB::Submission - Queries about a submission to EBI of either a Study or an Experiment

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

  use GDACAP::DB::Submission;
  my $subm = GDACAP::DB::Submission->new();

  my $info = $subm->info('experiment',7);
  print $info;
  my $state = $subm->state($$info{id});
  print $state;

=head1 DESCRIPTION

It mainly works on Table submission_state.

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
