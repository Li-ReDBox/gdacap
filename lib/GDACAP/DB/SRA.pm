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

sub new {
	my $class;
	($class, $center_name, $working_dir ) = @_;
	Carp::croak "Working folder does not accessible $working_dir" unless (-d $working_dir);
	$prefix = join('',$center_name =~ m/\b\w/g);
	if (length($prefix)<2) { $prefix =  $center_name; }	
	$class->SUPER::new();
	return bless ({}, $class);
}

sub prepare {
	my ($fn) = @_;
	$fn = $working_dir.'/'.$fn;
	my $output = IO::File->new("> $fn") or Carp::croak "Cannot open file handle to write into $fn.";
	my $xw = XML::Writer->new(OUTPUT=>$output);
	$xw->xmlDecl("UTF-8");
	return ($xw, $output);
}

sub action {
	my ($xw, $name,$attributes) = @_;
	$xw->startTag('ACTION');
	$xw->emptyTag($name, %$attributes);
	$xw->endTag('ACTION');
}

# Only supports ADD
sub submission {
	my ($self, $alias, $release_date, $sources) = @_;
	my ($xw, $output) = prepare($alias.'.xml');
	$xw->startTag('SUBMISSION_SET',%xmls, 'xsi:noNamespaceSchemaworking_dir'=>'ftp://ftp.sra.ebi.ac.uk/meta/xsd/sra_1_3/SRA.submission.xsd');
	$xw->startTag('SUBMISSION', alias=>$alias, center_name=>$center_name);
    $xw->startTag('ACTIONS');
	for (keys %$sources) {
		action($xw, 'ADD', {source=>$$sources{$_}, schema=>"$_"});
	}
	if ($release_date eq 'now') {
		action($xw, 'RELEASE', {});
	} elsif (!$release_date) {
		action($xw, 'HOLD', {});
	} else {
		action($xw, 'HOLD', {HoldUntilDate=>$release_date});
	}	
	$xw->endTag('ACTIONS');
	$xw->endTag('SUBMISSION');
	$xw->endTag('SUBMISSION_SET');
	$xw->end();
	$output->close();
}

sub get_SRA_samples {
	my ($self, $ids) = @_;
	my $id_list = join(",", ("?")x@$ids);
	my $statement = "SELECT a.accession, a.id, a.iname, a.description, a.tax_id, b.name_txt AS sci_name FROM sample a,tax_name b 
			WHERE a.id IN ($id_list) AND a.tax_id = b.tax_id AND name_class='scientific name'";
	return $self->array_hashref($statement, @$ids);
}

sub sample {
	my ($self, $ids) = @_;
	my $rcs = $self->get_SRA_samples($ids);
	my $fn = 'sample.xml';
	my $has_to_add = 0;
	my ($xw, $output) = prepare($fn);
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
	my $statement = 'SELECT a.id, a.accession, a.iname, a.abstract, b.description AS type FROM study a, study_type b WHERE a.id = ? AND a.study_type_id = b.id';
	return $self->row_hashref($statement,$id);
}

sub study {
	my ($self, $id) = @_;
	my $rc = $self->get_SRA_study($id);
	$$rc{accession} =~ s/$tail_space// if $$rc{accession};
	return if $$rc{accession};
	
	my $fn = 'study.xml';
	my ($xw, $output) = prepare($fn);
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
		FROM experiment a, platform d WHERE a.id IN ($id_list) AND a.platform_id = d.id";
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
	my $fn = 'experiment.xml';
	my ($xw, $output) = prepare($fn);
	my $rcs = $self->get_SRA_experiments($ids);
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
	my $statement = 'SELECT id,experiment_id,hash,raw_file_name,run_date,type FROM run WHERE experiment_id = ?';
	return $self->array_hashref($statement,$exp_id);
}

# Sequence reads have significant size, no gzip or md5 is done in our script.
# read the md5 of a file: the file has only one line with two parts: md5 and file name split by space
sub read_md5 {
	my ($fn, $needle) = @_;
	my $md5;
	open(FILE, $fn) or Carp::croak "$!, $fn";
	($md5, $fn) = split(' ',<FILE>);
	close FILE;
	return unless (index($fn, $needle)>=0);
	return $md5;
}

# Used for identifing the read direction of a fastq file.
sub read_header {
	my $fn = shift;
	open(FILE, $fn) or Carp::croak "Couldn't open file: $!";
	my $line = <FILE>;
	close FILE;
	if ($line =~ /\w+#[ACTG]+\/([12]){1}/) { return $1; } else { Carp::croak "Pair-reading direction cannot be detected: $fn"; }
}

# run_id, and GDACAP::DB::Repository object for retriving file
# md5's of gzipped files info are read from the files (name pattern: $hash.gz.md5) under $sub_dir
sub run {
	my ($self, $exp_ids, $repo) = @_;
	my $fn = 'run.xml';
	my ($xw, $output) = prepare($fn);
	$xw->startTag('RUN_SET',%xmls);
	foreach (@$exp_ids) {
		$self->run_element($_, $xw, $repo);
	}
	$xw->endTag('RUN_SET');
	$xw->end();
	$output->close();
	return $fn;
}

# each run of an experiment
sub run_element {
	my ($self, $exp_id, $xw, $repo) = @_;
	
	my @run_file_rcs = @ { $self->get_SRA_run($exp_id) }; # can be two or one
	my ($n, $run);

	Carp::croak('Only FASTQ files are allowed') unless $run_file_rcs[0]->{type} eq 'FASTQ';
	my $score_offset = $self->score_offset($exp_id);

	$xw->startTag('RUN', alias=>$prefix.'_run_'.$run_file_rcs[0]->{id}, run_date=>$run_file_rcs[0]->{run_date}.'T00:00:00', center_name=>$center_name);
	$xw->emptyTag('EXPERIMENT_REF', refname=>$prefix.'_experiment_'.$run_file_rcs[0]->{experiment_id});
    $xw->startTag('DATA_BLOCK');
    $xw->startTag('FILES');
	my %labels =('1'=>,'F1','2'=>'R2');
	try {
		foreach (@run_file_rcs) {
			$$_{hash} =~ s/$tail_space//;	# remove tailing spaces
			# print $$_{hash},"\n";
			$xw->startTag('FILE', quality_scoring_system=>"phred", quality_encoding=>"ascii", ascii_offset=>$score_offset,
			 checksum=>read_md5($working_dir.'/'.$$_{hash}.'.gz.md5',$$_{raw_file_name}.'.gz'), checksum_method=>"MD5", 
			 filename=>$$_{raw_file_name}.'.gz', filetype=>lc($$_{type}));
			if (scalar(@run_file_rcs)>1) {
				$run = $repo->fpath($$_{hash}); # raw, ungzipped read file
				$n = read_header($run); # only be useful if there is a pair
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

# After successfully submitted to EBI, update accession in the table
sub update_accession {
	my ($table_name, $id, $accession ) = @_;
	$dbh->do("UPDATE $table_name SET accession = '$accession' WHERE id = $id");
}

1;

__END__

=head1 NAME

GDACAP::DB::SRA - Create XML files and submission for Short Read Archive (SRA)

=head1 Synopsis

  # Generally, it is used as following:
  my @add_list = qw(experiment run);
  my $sra = GDACAP::DB::SRA->new('UNIVERSITY OF ADELAIDE',$working_folder);
  
  # XML of a Run
  my $sample_xml = $sra->sample($sample_id);
  $add_list{sample} = 1;
  my $run_xml = $sra->run($run_id);
  # submission xml:
  for @add_list {
  }

=head1 Description

C<GDACAP::DB::SRA> generates XML files of SRA models of B<Submission>, B<Study>, B<Sample>, B<Experiment> and B<Run> for a submission. 
A B<Submission> genereally B<ADD> B<Study>, B<Sample>, B<Experiment> and B<Run>. But B<Study> or B<Sample> can be submitted before.
In such cases, B<Submission> only has to B<ADD> has yet subitted SRA objects. But they have to be referenced either by B<refname> or B<accession>.
In short, a B<Submission> at least has to have three XML files: submission.xml, experiment.xml and run.xml.

The caller deceides where the files are to save but C<GDACAP::DB::SRA> decide what naming convention to use. Currenty, it is schema plus .xml.

Currently, SRA XML schemas version 1.3 is supported. Detail can be found at http://www.ebi.ac.uk/ena/about/sra_format. Note, only B<Submission> has schema information and the rests do not need.

=head1 Copyright

Ands package and its modules are copyrighted under the GPL, Version 3.0.


=head1 Authors

Jianfeng Li


=cut

