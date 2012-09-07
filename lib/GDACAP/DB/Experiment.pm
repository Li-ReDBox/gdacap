package GDACAP::DB::Experiment;

use strict;
use warnings;

use Try::Tiny;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id iname sample platform accession);
our $brief_fields = join(',',@fields); 
@fields = (@fields, qw(study_id sample_id platform_id design lib_source));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;
$permitted{nominal_size} = 1;

our @creation = qw(iname study_id sample_id platform_id design lib_source);
our @edit = qw(iname sample_id platform_id design lib_source);
our @creation_optional = qw(nominal_size); 

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM experiment_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	$self->nominal_size();
	$self->in_rda();
	return $self->values();
}

# $iname, $design, $study_id, $sample_id, $platform_id, $internal_name, $nominal_size
sub create {
	my ($self, $info) = @_;
	my $nominal_size = $$info{nominal_size};
	delete $$info{nominal_size};
	my $id = undef;
	$dbh->begin_work;
	try {
		$id = $self->SUPER::create('experiment', $info);
		if ( $id ) {
			if ($nominal_size) {
				my $statement = qq(INSERT INTO attribute (table_name,item_id,atype,avalue) values('experiment',?,'nominal_size',?));
				$dbh->do($statement, {}, ($id, $nominal_size)) or die  $dbh->errstr;
			}
			$dbh->commit;
		} else {
			$dbh->rollback;
		}
	} catch {
		print STDERR "$_\n";
		$dbh->rollback;
	};
	return $id;
}

sub project_id {
	my ($self) = @_;
	return $self->row_value('SELECT get_project_id(?,?)','experiment',$$self{id});
}

sub nominal_size {
	my ($self) = @_;
	$$self{nominal_size} = '';
	my $nominal_size = $self->row_value('SELECT avalue FROM attribute WHERE table_name= ? and item_id = ?','experiment', $$self{id});
 	$$self{nominal_size} = $nominal_size if ($nominal_size);
	return $nominal_size;
}

# attribute if an Experiment record has been ready for RDA to harvest - in oai_headers
sub in_rda {
	my ($self) = @_;
	$$self{in_rda} = 0;
	my $in_rda = $self->row_value('SELECT ori_id FROM oai_headers WHERE ori_table_name= ? and ori_id = ?','experiment', $$self{id});
 	$$self{in_rda} = $in_rda if ($in_rda);
	return $in_rda;
}

# Insert a record about current Experiment in oai_headers to allow RDA to harvest
# All dependencies are checked
sub rda_allow {
	my ($self) = @_;
	$dbh->begin_work;
	try {
		rda_insert('experiment',$$self{id});
		my $person_id = $self->row_value("SELECT pr.person_id FROM experiment ex, study st, role_type rt, personrole pr WHERE ex.id = ? AND st.id = ex.study_id AND pr.project_id = st.project_id AND pr.role_type_id = rt.id AND rt.iname = 'Manager'", $$self{id});
		die "No Manager role exists" unless $person_id;
		my $created = $self->row_value('SELECT count(oai_identifier) FROM rda_person WHERE person_id = ?', $person_id); # First check if it has been pre-created
		unless ($created) { # Have to use our local data to create a Party record
			$created = $self->row_value('SELECT count(ori_id) FROM oai_headers WHERE ori_table_name = ? AND ori_id = ?', 'person', $person_id);
			rda_insert('person',$person_id) unless $created;
		}
		$created = $self->row_value('SELECT count(ori_id) FROM oai_headers WHERE ori_table_name = ? AND ori_id = ?', 'study', $$self{study_id});
		rda_insert('study',$$self{study_id}) unless $created;
		$dbh->commit;
	} catch {
		print STDERR "$_\n";
		$dbh->rollback;
	};
}

# Insert a record about current Experiment in oai_headers to allow RDA to harvest
#     oai_set      | set_type | ori_table_name 
#------------------+----------+----------------
# class:party      | person   | person
# class:activity   | project  | study
# class:collection | dataset  | experiment
sub rda_insert {
	my ($type, $id) = @_;
	my %parts = (experiment => ['class:collection','dataset','experiment'],
				 person     => ['class:party', 'person', 'person'], 
				 study      => ['class:activity','project','study']);
	$dbh->do('INSERT INTO oai_headers (oai_set, set_type, ori_table_name,ori_id) values(?,?,?,?)',undef,@{$parts{$type}},$id) or die $dbh->errstr;
}

sub layout_changeable {
	my ($self) = @_;
	my $run_ids = $self->row_value('SELECT count(id) FROM run_core WHERE experiment_id = ?',$$self{id});
	return $run_ids ? 0 : 1;
}

sub runs {
	my ($self) = @_;
	my $run_ids = $self->arrayref('SELECT id FROM run_core WHERE experiment_id = ?',$$self{id});
	return {} unless $run_ids;

	require GDACAP::DB::Run;
	my $run = GDACAP::DB::Run->new();
	my @runs = ();
	foreach(@$run_ids) {
		$run->by_id($$_[0]);
		push(@runs, $run->values());
	}
	return \@runs;
}

# Get current project's files registered in 'run upload' category and which have not been registered as runs
# The run file type can be set by $file_type. The default is FASTQ
sub run_candidates {
	my ($self, $file_type) = @_;
	$file_type = 'FASTQ' unless $file_type;
	my $project_id = $self->project_id();
	my $statement = "SELECT finf.id,original_name,added_time FROM file_info finf, process p, process_out_file po 
	  WHERE finf.type = '$file_type' AND finf.project_id = ? AND finf.id = po.file_copy_id AND p.id = po.process_id and p.category = 'run upload'
	  AND finf.id NOT IN (SELECT file_copy_id FROM run)";
	return $self->array_hashref($statement, $project_id);
}

sub update {
	my ($self, $info) = @_;
	my ($nominal_size, $in_rda) = delete @$info{qw(nominal_size in_rda)};
	$self->SUPER::update('experiment',$$self{id},$info);
	$self->update_nominal_size($nominal_size);
	$self->rda_allow() if $in_rda && !$$self{in_rda};
	$self->by_id($$self{id});
}

# It can be used when the value has not been set yet - an insert instead of update
sub update_nominal_size {
	my ($self, $new_size) = @_;
	my ($rv, $statement);
	my $old_size = $$self{nominal_size};
	if ($old_size ne $new_size) {
		$statement = qq(UPDATE attribute SET avalue = ? WHERE table_name = 'experiment' AND item_id = ? AND atype = 'nominal_size');
	} else {
		return unless $new_size;
		$statement = qq(INSERT INTO attribute (table_name,atype,avalue,item_id) values('experiment','nominal_size',?,?));
	}
	$dbh->do($statement,undef,($new_size, $$self{id})) or die $dbh->errstr;
}

# Section -- for submission to EBI
# Return run file list for preparing submission
sub run_files {
	my ($self, $exp_id) = @_;
	$exp_id = $$self{id} unless $exp_id;
	return $self->arrayref('SELECT hash, raw_file_name FROM run WHERE experiment_id = ?', $exp_id);
}

# Returns study and sample ids of an Experiment
sub sample_ids {
	my ($self, $exp_id) = @_;
	$exp_id = $$self{id} unless $exp_id;
	return $self->row_value('SELECT study_id, sample_id FROM experiment WHERE id = ?', $exp_id);
}

# sub register_submission {
	# my ($self, $release_date, $exp_id) = @_;
	# $exp_id = $self->id unless $exp_id;
	# Carp::croak('Experiment id has not been set in either constructor or here.') unless $exp_id;
	# my $statement = Ands::ADB::build_insert('submission', [qw(type item_id release_date)],1);
	# my $sth = $self->dbh->prepare_cached($statement);
	# my $id = undef;
	# $self->dbh->begin_work;
	# try {
		# $id = $self->dbh->selectrow_array($sth,{},('experiment',$exp_id,$release_date));
		# # print "Newly registered submission ID is $id.\n";
		# # $self->dbh->rollback;
		# $self->dbh->commit if $id;
	# } catch {
		# print STDERR "$_\n";
		# $self->dbh->rollback;
	# };
	# return $id;
# }

# Collections
sub platforms {
	my ($self) = @_;
	return $self->array_hashref("SELECT id, iname, model FROM platform ORDER BY description");
}

1;

__END__

=head1 NAME

GDACAP::DB::Experiment - Experiment object

=head1 Synopsis

	my $exp = GDACAP::DB::Experiment->new();
	# Register file_copy as run to an Experiment by its id
	# Not optional experiment.id is the last argument
	$exp->register_run('run_name',32,2),"\n"; 
	# Get the parent Project.id
	print "Project id = ", $exp->get_project_id(2),"\n";
	# Get the data of an Experiment by its id
	print Dumper($exp->get_by_id(2));
	# get sequence files of this project which have not been registered:
	print Dumper($exp->run_cadidates());
	# Get run_files
	# Reister file_copy as run to the current Experiment
	print "registration of run returns: ", $exp->register_run('run_name',32),"\n";
	# Get run files of current Experiment
	my $runs = $exp->runs();
	# runs are in a hash with keys of run.id's
	print Dumper($runs);
	foreach my $run (sort(keys %$runs)) {
		print $run, '=', Dumper($$runs{$run}), "\n";
	}
	# get platforms:
	print Dumper($exp->platforms());
	$dbh->disconnect();

=head1 DESCRIPTION

C<GDACAP::DB::Experiment> returns a single record from experiment_info. As there are other ojbects assoicate to it, it is also the query interface to them. These interfaces only return fields summarise associated objects. The returned field lists are defined in associated fields.

Most of attributes describe an experiment are defined in Table experiment expcept two: nominal_size and in_rda.
nominal_size is defined in Table attribute and only be used when Run is in FASTQ and paired read.
in_rda is a boolean and defined by if there is a corresponding record in oai_headers. It can only be set once - once published it cannot be deleted.
 
=head1 METHODS

=head2 run_candidates

  @candidates = @{ $exp->run_candidates($file_type) };
 
C<run_candidates> - returns the files filtered by $file_type in category 'run upload' of a C<Process> which have not registered yet.

=head2 rda_allow

C<rda_allow> - inserts current Experiment into Table oai_headers in current format. It also checks if the depended Party and Activity records have been created in oai_headers. If they have not been inserted, insert them. The Person can be inserted has to have Manager role eithwise it dies.
  
=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
