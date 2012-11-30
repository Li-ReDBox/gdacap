package GDACAP::DB::SRA;

use strict;
use warnings;

use IO::File;
use XML::Writer;
require Carp;
use Try::Tiny;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);


use GDACAP::Repository;
use GDACAP::FileOp qw(md5_file);
use Data::Dumper;

my %xmls = ("xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance");
my $center_name; # The name of submission centre
my $working_dir; # where is the working directory? where to save?
my $tail_space = qr/\s+$/;
my $prefix;
my $filename_root = '';

sub new {
	my ($class, $fn_root);
	($class, $center_name, $working_dir, $fn_root ) = @_;
	Carp::croak "Working folder does not accessible $working_dir" unless (-d $working_dir);
	$prefix = join('',$center_name =~ m/\b\w/g);
	if (length($prefix)<2) { $prefix =  $center_name; }
	$filename_root = $fn_root if $fn_root;
	$class->SUPER::new();
	return bless ({}, $class);
}

sub prepare {
	my ($fn) = @_;
	$fn = $working_dir.'/'.$filename_root.'_'.$fn;
	my $output = IO::File->new("> $fn") or Carp::croak "Cannot open file handle to write into $fn.";
	my $xw = XML::Writer->new(OUTPUT=>$output);
	$xw->xmlDecl("UTF-8");
	return ($xw, $output, $fn);
}

sub action {
	my ($xw, $name,$attributes) = @_;
	$xw->startTag('ACTION');
	$xw->emptyTag($name, %$attributes);
	$xw->endTag('ACTION');
}

# Only supports ADD
sub submission {
	my ($self, $alias, $holduntil_date, $sources) = @_;
	my ($xw, $output, $xml_filename) = prepare($alias.'.xml');
	$xw->startTag('SUBMISSION_SET',%xmls, 'xsi:noNamespaceSchemaworking_dir'=>'ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_3/SRA.submission.xsd');
	$xw->startTag('SUBMISSION', alias=>$alias, center_name=>$center_name);
    $xw->startTag('ACTIONS');
	for (keys %$sources) {
		action($xw, 'ADD', {source=>$$sources{$_}, schema=>"$_"});
	}
	if (!$holduntil_date) {
		action($xw, 'HOLD', {});
	} elsif ($holduntil_date eq 'now') {
		action($xw, 'RELEASE', {});
	} else {
		action($xw, 'HOLD', {HoldUntilDate=>$holduntil_date});
	}
	$xw->endTag('ACTIONS');
	$xw->endTag('SUBMISSION');
	$xw->endTag('SUBMISSION_SET');
	$xw->end();
	$output->close();
	return $xml_filename;
}

sub get_SRA_samples {
	my ($self, $ids) = @_;
	my $id_list = join(",", ("?")x@$ids);
	my $statement = "SELECT a.id, a.iname, a.description, a.tax_id, b.name_txt AS sci_name FROM sample a,tax_name b
			WHERE a.accession = '' AND a.id IN ($id_list) AND a.tax_id = b.tax_id AND name_class='scientific name'";
	return $self->array_hashref($statement, @$ids);
}

sub sample {
	my ($self, $ids) = @_;
	my $rcs = $self->get_SRA_samples($ids);
	return unless @$rcs > 0;
	
	my $has_to_add = 0;
	my ($xw, $output, $fn) = prepare('sample.xml');
	$xw->startTag('SAMPLE_SET',%xmls);
	for my $rc (@$rcs) {
		next if $$rc{accession};
		$xw->startTag('SAMPLE', alias=>$prefix.'_sample_'.$$rc{id}, center_name=>$center_name);
		$xw->dataElement('TITLE',$$rc{iname});
		$xw->startTag('SAMPLE_NAME');
		$xw->dataElement('SCIENTIFIC_NAME',$$rc{sci_name});
		$xw->dataElement('TAXON_ID',$$rc{tax_id});
		$xw->endTag('SAMPLE_NAME');
		if ($$rc{description}) {
			$xw->dataElement('DESCRIPTION',$$rc{description});
		} else {
			$xw->dataElement('DESCRIPTION','unspecified');
		}
		$xw->endTag('SAMPLE');
		$has_to_add = 1;
	}
	$xw->endTag('SAMPLE_SET');
	$xw->end();
	$output->close();
	return $fn if $has_to_add;
}

sub get_SRA_study {
	my ($self, $id) = @_;
	my $statement = 'SELECT a.id, a.iname, a.abstract, b.description AS type FROM study a, study_type b WHERE a.accession = \'\' AND a.id = ? AND a.study_type_id = b.id';
	return $self->row_hashref($statement,$id);
}

sub study {
	my ($self, $id) = @_;
	my $rc = $self->get_SRA_study($id);
	return unless $rc && %$rc;

	my ($xw, $output, $fn) = prepare('study.xml');
	$xw->startTag('STUDY_SET',%xmls);
	$xw->startTag('STUDY', alias=>$prefix.'_study_'.$$rc{id}, center_name=>$center_name);
    $xw->startTag('DESCRIPTOR');
    $xw->emptyTag('STUDY_TYPE', existing_study_type=>$$rc{type});
    $xw->dataElement('STUDY_ABSTRACT',$$rc{abstract});
    $xw->dataElement('STUDY_TITLE',$$rc{iname});
    $xw->endTag('DESCRIPTOR');
	$xw->endTag('STUDY');
	$xw->endTag('STUDY_SET');
	$xw->end();
	$output->close();
	return $fn;
}

sub platform_map {
	my $key = shift;
	my %dic = ('Illumina'=>'ILLUMINA','454'=>'LS454','AB SOLiD'=>'ABI_SOLID','Ion Torrent'=>'ION_TORRENT',PacBio=>'PacBio');
	return $dic{$key} if exists($dic{$key});
}

sub get_SRA_experiments {
	my ($self, $ids) = @_;
	my $id_list = join(",", ("?")x@$ids);
	my $statement = "SELECT a.id, a.iname, a.design, a.lib_source, a.study_id, a.sample_id, d.iname AS platform, d.model
		FROM experiment a, platform d WHERE a.accession = '' AND a.id IN ($id_list) AND a.platform_id = d.id";
	return $self->array_hashref($statement, @$ids);
}

sub nominal_length {
	my ($self, $exp_id) = @_;
	my $statement = 'SELECT avalue FROM attribute WHERE table_name= ? and item_id = ?'; # currently only one attribute per experiment
	return $self->row_value($statement,('experiment', $exp_id));
}

# FASTQ files have quality scores
sub score_offset {
	my ($self, $exp_id) = @_;
	my $statement = "SELECT avalue FROM attribute WHERE table_name='run_core' AND atype='phred_offset' AND item_id IN (SELECT id FROM run_core WHERE experiment_id = ?)";
	return $self->row_value($statement, $exp_id);
}

sub experiment {
	my ($self, $ids) = @_;
	my ($xw, $output, $fn) = prepare('experiment.xml');
	my $rcs = $self->get_SRA_experiments($ids);
	return unless @$rcs > 0;
	
	$xw->startTag('EXPERIMENT_SET',%xmls);
	foreach (@$rcs) {
		$self->experiment_element($_, $xw);
	}
	$xw->endTag('EXPERIMENT_SET');
	$xw->end();
	$output->close();
	return $fn;
}

sub experiment_element {
	my ($self, $rc, $xw) = @_;
	$xw->startTag('EXPERIMENT', alias=>$prefix.'_experiment_'.$$rc{id}, center_name=>$center_name);

	$xw->emptyTag('STUDY_REF',refname=>$prefix.'_study_'.$$rc{study_id});
	$xw->startTag('DESIGN');
	$xw->dataElement('DESIGN_DESCRIPTION',$$rc{design});
	$xw->emptyTag('SAMPLE_DESCRIPTOR',refname=>$prefix.'_sample_'.$$rc{sample_id});
	$xw->startTag('LIBRARY_DESCRIPTOR');
	$xw->dataElement('LIBRARY_NAME','unspecified');
	$xw->dataElement('LIBRARY_STRATEGY','OTHER');
	$xw->dataElement('LIBRARY_SOURCE',$$rc{lib_source});
	$xw->dataElement('LIBRARY_SELECTION','unspecified');
	$xw->startTag('LIBRARY_LAYOUT');
	my $nominal_length = $self->nominal_length($$rc{id});
	if ($nominal_length) {
		$xw->emptyTag('PAIRED',NOMINAL_LENGTH=>$nominal_length);
	} else {
		$xw->dataElement('SINGLE');
	}
	$xw->endTag('LIBRARY_LAYOUT');
	$xw->endTag('LIBRARY_DESCRIPTOR');
    $xw->endTag('DESIGN');
    $xw->startTag('PLATFORM');
	my $platform = platform_map($$rc{platform});
	Carp::croak('Unsupported platform found - '.$$rc{platform}) unless $platform;
    $xw->startTag($platform);
    $xw->dataElement('INSTRUMENT_MODEL',$$rc{platform}.' '.$$rc{model});
    $xw->endTag($platform);
    $xw->endTag('PLATFORM');

	$xw->endTag('EXPERIMENT');
}

# This model can be wrong when there are multiple runs and every run has pair-end reads (2 files)
sub get_SRA_run {
	my ($self, $exp_id) = @_;
	my $statement = 'SELECT id,experiment_id,hash,raw_file_name,run_date,type FROM run WHERE accession = \'\' AND experiment_id = ?';
	return $self->array_hashref($statement,$exp_id);
}

# Sequence reads have significant size, no gzip or md5 is done in our script.
# read the md5 of a gzipped fastq file: the file has only one line with two parts: md5 and file name split by space
# file name is xxx.fastq.gz
sub read_md5 {
	my ($fn, $needle) = @_;
	#print "Incoming needle in read_md5 is $needle.\n";
	my $md5;
	open(FILE, $fn) or Carp::croak "$!, $fn";
	($md5, $fn) = split('  ',<FILE>); # md5sum use two spaces to separate md5 and file name
	close FILE;
	#print "md5=$md5, fn=$fn\n";
	return unless (index($fn, $needle)>=0);
	return $md5;
}

# Used for identifing the read direction of a fastq file. Not FASTQ.GZ
#sub read_header {
#	my ($fn, $zipped) = @_;
#	my $head;
#	if ($zipped) {
#		$head = qx(zcat $fn 2>/dev/null | head -n 1);
#	} else {
#		open(FILE, $fn) or Carp::croak "Couldn't open file: $!";
#		$head = <FILE>;
#		close FILE;
#	}
#	if ($head =~ /\w+#[ACTG]+\/([12]){1}/) { 
#		return $1; 
#	} else {
#		Carp::croak "Pair-reading direction cannot be detected: $fn";
#	}
#}
# Detect fastq file type: has to be either gzip or ASCII
sub file_type {
	my ($fn) = @_;
	my $type = qx(file -bL $fn);
	if (index($type,'gzip') >= 0) {
		$type = 'gzip';
	} elsif (index($type, 'ASCII') >= 0) {
		$type = 'ASCII';
	} else {
		Carp::croak "Neither gzip or ASCII file: $fn\n";
	}
	return $type;
}
# Similar with above but with the help of file magic
sub read_header {
	my ($fn) = @_;
	my $head;
	if (file_type($fn) eq 'gzip') {
		$head = qx(zcat $fn 2>/dev/null | head -n 1);
	} else {
		$head = qx(head -n 1 $fn);
	}
	if ($head =~ /\w+#[ACTG]+\/([12]){1}/) { 
		return $1; 
	} else {
		Carp::croak "Pair-reading direction cannot be detected: $fn";
	}
}

# run_id, and GDACAP::Repository object for reading FASTQ file.
# md5's of gzipped files info are read from the files (name pattern: $hash.md5) under $sub_dir
sub run {
	my ($self, $exp_ids, $repo) = @_;
	my ($xw, $output, $fn) = prepare('run.xml');
	$xw->startTag('RUN_SET',%xmls);
	foreach (@$exp_ids) {
		$self->run_element($_, $xw, $repo);
	}
	$xw->endTag('RUN_SET');
	$xw->end();
	$output->close();
	return $fn;
}

# each run of an experiment - FASTQ type
sub run_element {
	my ($self, $exp_id, $xw, $repo) = @_;
	
	my @run_file_rcs = @ { $self->get_SRA_run($exp_id) }; # can be two or one
	return unless @run_file_rcs > 0;
	
	my ($n, $run);

	# We trust only fastq, fastq.gz and bam have been added as run files.
	# Carp::croak('Only FASTQ and ZIPPEDFATQ files are currently allowed.') unless index($run_file_rcs[0]->{type}, 'FASTQ') >= 0;
	if (index($run_file_rcs[0]->{type}, 'BAM') >= 0) {
		run_element_bam($exp_id, $xw);
		return;
	}
	my $score_offset = $self->score_offset($exp_id);

	$xw->startTag('RUN', alias=>$prefix.'_run_'.$run_file_rcs[0]->{id}, run_date=>$run_file_rcs[0]->{run_date}.'T00:00:00', center_name=>$center_name);
	$xw->emptyTag('EXPERIMENT_REF', refname=>$prefix.'_experiment_'.$run_file_rcs[0]->{experiment_id});
    $xw->startTag('DATA_BLOCK');
    $xw->startTag('FILES');
	my %labels =('1'=>,'F1','2'=>'R2');
	my ($needle, $md5sum, $zipped);
	try {
		foreach (@run_file_rcs) {
			$$_{hash} =~ s/$tail_space//;	# remove tailing spaces
			# print $$_{hash},"\n";
			# print $$_{raw_file_name},"\n";
			if ($$_{type} eq 'FASTQ') {
				$zipped = 0;
				$needle = $$_{raw_file_name}.'.gz';
			} elsif ($$_{type} eq 'ZIPPEDFASTQ') {
				$zipped = 1;
				$needle = $$_{raw_file_name}; # Already has .gz in the raw file name
				$$_{type} = 'FASTQ'; # Reveal its real nature
			} else {
				Carp::croak("Unsuppored run file type for submission to EBI/ERA found: $$_{type}.");
			}
			$md5sum = read_md5($working_dir.'/'.$$_{hash}.'.md5',$needle);
			# print "Received md5sum=$md5sum\n";
			$xw->startTag('FILE', quality_scoring_system=>"phred", quality_encoding=>"ascii", ascii_offset=>$score_offset,
			 checksum=>$md5sum, checksum_method=>"MD5",
			 filename=>$needle, filetype=>lc($$_{type}));
			if (scalar(@run_file_rcs)>1) {
				$run = $repo->fpath($$_{hash}); # raw, ungzipped read file
				$n = read_header($run, $zipped); # only be useful if there is a pair
				$xw->dataElement('READ_LABEL',$labels{$n}) ;
			}
			$xw->endTag('FILE');
		}
	} catch {
		print STDERR "Run submission XML file cannot be created. $_";
	} finally {
		$xw->endTag('FILES');
		$xw->endTag('DATA_BLOCK');
		$xw->endTag('RUN');
	};
}

# each run of an experiment - BAM type
sub run_element_bam {
	my ($self, $exp_id, $xw) = @_;

	my @run_file_rcs = @ { $self->get_SRA_run($exp_id) }; # can be two or one
	my ($n, $run);

	Carp::croak('BAM is the only type supported in this function') unless index($run_file_rcs[0]->{type}, 'BAM') >= 0;

	$xw->startTag('RUN', alias=>$prefix.'_run_'.$run_file_rcs[0]->{id}, run_date=>$run_file_rcs[0]->{run_date}.'T00:00:00', center_name=>$center_name);
	$xw->emptyTag('EXPERIMENT_REF', refname=>$prefix.'_experiment_'.$run_file_rcs[0]->{experiment_id});
    $xw->startTag('DATA_BLOCK');
    $xw->startTag('FILES');
	my $needle;
	try {
		foreach (@run_file_rcs) {
			$$_{hash} =~ s/$tail_space//;	# remove tailing spaces
			# print $$_{hash},"\n";
			if ($$_{type} eq 'BAM') {
				$needle = $$_{raw_file_name};
				$$_{type} = 'FASTQ';
			} else {
				die "Unsuppored run file type for submission to EBI/ERA found, or called wrong function: $$_{type}.";
			}
			$xw->startTag('FILE', checksum=>read_md5($working_dir.'/'.$$_{hash}.'.md5',$needle), checksum_method=>"MD5",
			 filename=>$needle, filetype=>lc($$_{type}));
			$xw->endTag('FILE');
		}
	} catch {
		print STDERR "Run submission XML file cannot be created. $_";
	} finally {
		$xw->endTag('FILES');
		$xw->endTag('DATA_BLOCK');
		$xw->endTag('RUN');
	};
}

# After successfully submitted to EBI, update accession in the table
# Also update release_date of Study previously empty or set.
# run(_core) is a part of Experiment.
# In February 2013, it has been notified by EBI, only Study has holdUntilDate
# other objects have only status as PUBLIC or PRIVATE.
sub update_accession {
	my ($self, $table_name, $id, $accession, $release_date ) = @_;
	unless ($accession) {
		warn("Is this a new pattern? No accession is given for $table_name ( $id ).");
		return;
	}
	my $sql = "UPDATE $table_name SET accession = '$accession'";
	if ($release_date && $table_name eq 'study') {
		$sql .= ", release_date = '$release_date'";
	} 
	$sql .= " WHERE id = $id";
	$dbh->do($sql) or die ("Update to $table_name failed:\n $sql\n Deatail: ", $dbh->errstr);
}

1;

__END__

=head1 NAME

GDACAP::DB::SRA - Create XML files for submitting to Short Read Archive (SRA)

=head1 SYNOPSIS

  # Generally, it is used as following:
	require GDACAP::DB::SRA;

	use GDACAP::Resource qw(get_repository);
	my $config = GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

	# This direcotry has to be crated before
	my $folders = $$config{folders};
	my $submission_dir = $$folders{submission};

	my $sra = GDACAP::DB::SRA->new('UNIVERSITY OF ADELAIDE',$submission_dir);
	my $sources = {}; # place holder for ACTIONS/ADD in submission

	$add = $sra->study(6);
	$$sources{study} = $add if $add;
	my $add = $sra->sample([7]);
	$$sources{sample} = $add if $add;
	$$sources{experiment} = $sra->experiment([7]);

	# run files - need to retrieve from repository
	print "Repository settings:\n";
	my $repository = get_repository;
	print "Absolute repository path = $$repository{target}\n";
	use GDACAP::Repository;
	my $repo = GDACAP::Repository->new($$repository{target});
	croak('Cannot access repository at '.$$repository{target}) unless $repo;

	$$sources{run} = $sra->run([24],$repo);
	
	# hold until 2014-04-30
	$sra->submission('uofa'.time,'2014-04-30', $sources);

=head1 DESCRIPTION

C<GDACAP::DB::SRA> generates XML files of SRA models of B<Submission>, B<Study>,
B<Sample>, B<Experiment> and B<Run> for a submission. A B<Submission> genereally
B<ADD> B<Study>, B<Sample>, B<Experiment> and B<Run>. But B<Study> or B<Sample>
could have been submitted before. In such cases, B<Submission> only has to 
B<ADD> has not submitted SRA objects. But they have to be referenced either by B<refname> or B<accession>.
In other words, a B<Submission> at least has to have three XML files: submission.xml, experiment.xml and run.xml.

The caller deceides where the submission XML files are to save but C<GDACAP::DB::SRA> decide what naming convention to use. Currenty, it is schema plus .xml.

Currently, SRA XML schemas version 1.3 is supported. Detail can be found at http://www.ebi.ac.uk/ena/about/sra_format. Note, only B<Submission> has schema information and the rests do not need.

=head1 METHODS

=over 4

=item * new($centre_name, $submission_dir, [ $fileroot ])

Constructor. It takes two mandatory arguments: the name of the submission
centre, the name of a directory where files will be saved. The third argument
is optional. When it is set, $fileroot is used as the first part of 
XML file names. It is usually the type of submission (Study or 
Experiment), "_" and its ID. It can be used to group all XML files
together. Otherwise, XML files are not distinguishable and will be
overwritten in a new submission.

=item * prepare($simple_fn)

Prepares a XML::Writer object and a file handler for writing. The only
argument $simple_fn is used to create a IO::File handler.

It returns a XML::Writer object and a file handler and the file name
of the XML file.

=item * submission($name_part, $holduntil_date, $sources)

Creates an XML file for a SRA submission. $name_part is used to create 
XML file name. If $fileroot is not set, it is the actual XML file name
of the submission. $holduntil_date is date records to be held for before
release and the format is "YYYY-MM-DD". It can have three possibilites:
1. empty string: hold until to default date set by EBI/SRA;
2. "now": release now;
3. a string in date format of "YYYY-MM-DD": hold until that date.
$source is a hash with XML file names of SRA objects will be included in the submission.
It returns the actual XML file name.

=item * study($id) 

=item * sample(\@ids)

=item * experiment(\@ids)

These three methods behavour in the same way. 
Creates an XML file of a SRA Study or multiple Sample or Experiment objects.
When there is at least one object has to be submitted in this submission,
it returns the XML file name it created. Otherwise,
e.g. object has been assigned accession or could not find, it retruns null.
Only records without accession are included.

=item * run(\@exp_ids, $repo)

Creates an XML file contains run files of a list of Experiments.
$exp_ids is an array of IDs of Experiment. $repo is an GDACAP::Repository
object. 

=back

=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

Copyright (C) 2012 The University of Adelaide

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
