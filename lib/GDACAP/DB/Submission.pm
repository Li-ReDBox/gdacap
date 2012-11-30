package GDACAP::DB::Submission;

use strict;
use warnings;

use Carp ();
use DBI ();
use GDACAP::Table;

our @ISA = qw(GDACAP::Table);

my $state_query = 'SELECT alias, successful, action, act_time, message FROM submission_state 
		WHERE submission_id = ? ORDER BY act_time DESC';

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# The information of a submission: type, (proposed) release date, id for state query
sub info {
	my ($self, $type, $id) = @_;
	return $self->row_hashref('SELECT id FROM submission WHERE type = ? AND item_id = ?', $type, $id);
}

# alias         | character varying(20)       | not null
# submission_id | integer                     | 
# action        | character varying(7)        | default 'ADD'::character varying
# act_time      | timestamp without time zone | not null default ('now'::text)::timestamp(0) without time zone
# successful    | boolean                     | default false
# message       | text                        | default ''::text

sub log_state {
	my ($self, $new_state) = @_;
	if ($self->row_value('SELECT count(*) FROM submission_state WHERE alias = ?',$$new_state{alias})) {
		warn "$$new_state{alias} has been logged already.\n";
	} else {
		$self->SUPER::create('submission_state', $new_state, 'no_id');
	}
}

# Returns the last action state to normal user
sub latest {
	my ($self, $sub_id) = @_;
	return $self->row_hashref($state_query.' LIMIT 1', $sub_id);
}

# Get full histroy of the submissions of a Study or Experiment
# We do not submit samples directly to EBI
sub history {
	my ($self, $sub_id) = @_;
	return $self->array_hashref($state_query, $sub_id);
}

1;

__END__

=head1 NAME

GDACAP::DB::Submission - Queries about a submission to EBI of either a Study or an Experiment

=head1 SYNOPSIS

  # Connect to database
  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

  # Register a submission of Experiment
  use GDACAP::DB::Experiment ();
  my $exp = GDACAP::DB::Experiment->new();
  exp->by_id(7);
  $exp->log_submission('2014-11-01') unless (exp->in_submission);
  
  # Later, check what has happened:
  use GDACAP::DB::Submission;
  my $subm = GDACAP::DB::Submission->new();

  my $info = $subm->info('experiment',7);
  print $info;
  
  
  my $state = $subm->latest($$info{id});
  print $state;

=head1 DESCRIPTION

It mainly works on Table submission_state. Entry is created by either
Experiment or Study (not implemented). An Experiment or a Study can
only be registered for submission once. But they can have many submissions.

Note: Study contains Experiment. So anyone wants to submit a Study, system
should allow a user to pick up which Experiments to be included. Or just as
currently supported to submit every Experiments included which have runs.

=head1 METHODS

=head2 info($submission_type, $object_id) 

Retrieve submission_id and relesase date of a submission defined by submission
type (Experiment  or Study) and its id.

When a record was found, it returns a hash with id as key.
Otherwise it returns undef.

=head2 log_state(\%state)

Log result of a submission act. %state has keys of:
 
 # alias         | character varying(20)       | submission alias
 # submission_id | integer                     | 
 # action        | character varying(7)        | read from MESSAGES -> INFO using pattern: xxx action
 # act_time      | timestamp without time zone | read from receiptDate of submission receipt
 # successful    | boolean                     | default false
 # message       | text                        | default ''::text

When it was successful, message is empty.

=head2 latest($submission_id)

Retrieve the latest state information of a submission. It allows a user to 
check if a submission was successful and error message if it was failed.

Study and Experiment can be submitted many times with Actions like ADD, MODIFY.
There is only one main entry for each Study or Experiment in terms of submission
but they can be submitted many times with different contents or actions. 
Each time when a submission occurs, it can either by successful or not.

It returns a hash with keys: alias, successful, action, act_time, message if found any.
Otherwise it returns undef.

=head2 history($submission_id)

Like latest() but returns full history.

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
