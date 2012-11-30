package GDACAP::DB::Study;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);
 
my @fields = qw(id iname abstract phase accession);
our $brief_fields = join(',',@fields); 
@fields = (@fields, qw(internal_name description study_type_id study_type project_id phase_status_id));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

our @creation = qw(iname internal_name abstract study_type_id project_id);
our @creation_optional = qw(description); 

our @update = qw(iname internal_name abstract study_type_id phase_status_id);
our @update_optional = qw(description);

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM study_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	return $rcd;
}

sub create {
    my ( $self, $info ) = @_;
	return $self->SUPER::create('study', $info);
}

sub update {
    my ( $self, $info ) = @_;
	$self->SUPER::update('study',$$self{id},$info);
	$self->by_id($$self{id});
}

sub experiments {
	my ($self) = @_;
	require GDACAP::DB::Experiment;
	my $brief_fields = $GDACAP::DB::Experiment::brief_fields;
	return $self->array_hashref("SELECT $brief_fields FROM experiment_info WHERE study_id = ?",$$self{id});
}

# Section -- for submission to EBI
# Returns run file list for preparing submission
# Published Run files are excluded
sub run_files {
	my ($self, $study_id) = @_;
	$study_id = $$self{id} unless $study_id;
	return $self->arrayref('SELECT hash, raw_file_name FROM run, experiment WHERE run.accession = \'\' AND run.experiment_id = experiment.id AND experiment.study_id = ?', $study_id);
}

# Log this Study has been submitted even it does not mean sumbmission is or going to be successful.
sub log_submission {
	my ($self, $id) = @_;
	$id = $$self{id} unless $id;
	$dbh->do("INSERT INTO submission (type, item_id) VALUES(?,?)", {}, ('study', $id)) or die  $dbh->errstr;
}

# Returns experiment and sample ids of a Study for a submission
# Only include Experiments which having run files and not excluded from submission and their associated Samples.
# SRA has to check accession status
sub submission_object_ids {
	my ($self, $study_id) = @_;
	$study_id = $$self{id} unless $study_id;
	return $self->arrayref('SELECT DISTINCT exp.id, sample_id FROM experiment exp, run WHERE study_id = ? 
	AND for_ebi = true AND run.experiment_id=exp.id', $study_id);
}

# Utility function
# Study type supported by the system
sub types {
	my ($self) = @_;
	return $self->array_hashref('SELECT id, description FROM study_type ORDER BY id');
}


1;

__END__

=head1 NAME

GDACAP::DB::Study - Access to experiment information

=head1 SYNOPSIS


=head1 DESCRIPTION

Users need to log in to access this page. $person_id is needed.

=head1 METHODS

=head2 submission_object_ids( [ $id ])

Returns Experiment and Sample ids of a Study for a Submission.
Only Experiments which having run files and not excluded from submission and their associated Samples
are returned. GDACAP::DB::SRA has to check accession status

=head2 log_submission([ $id ])

Logs a Study is being requested to be submitted. This occurs when a user clicks Submit button
on a Study information page. A Study can register for submission only once and it has to have all
its Experiments have at least one run.

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
