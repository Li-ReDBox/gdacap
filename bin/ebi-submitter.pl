# The usage: 
# This script is in bin directory which is under PACKAGE's installation directory.
# The library is under PACKAGE/lib
# The script assumes this directory structure holds. Otherwise, use any line below:
# export PERLLIB=PACKAGE/lib
# Or include "use lib 'PACKAGE/lib'" 

# perl /var/www/perl/ebi-submitter.pl study=8 release_date
# or 
# perl /var/www/perl/ebi-submitter.pl experiment=2
# if no compression and ascp are needed, anything in the second position will stop calling copy2ebi
# perl /var/www/perl/ebi-submitter.pl experiment=2 release_date skip
# It effectively just submit XML files to EBI/SRA assuming run files are there.

use File::Basename;
#use lib '/var/www/dc08_source/lib';
BEGIN {
	my (undef,$path) = fileparse($0);
	unshift(@INC, "$path../lib") if (-d "$path../lib");
	chdir($path);
}

use warnings;
use strict;

use Carp;
use Data::Dumper; 
use Try::Tiny;
require XML::Simple;

use POSIX qw(strftime);
use Time::Local qw(timelocal_nocheck timegm_nocheck);

# At least one argument is needed
&usage if @ARGV < 1 ;

# Only one argument will be processed
# foreach (@ARGV) { 	print $_,"\n"; }

my ($type, $id) = split('=',$ARGV[0]);
$id ? print "Processing $type(id = $id)\n" : &usage; 
my $release_date = $ARGV[1];

# convert release_date to holduntil_date
my $hold_until_date = release2holdtil($release_date);

my $call_copy2ebi = @ARGV < 3 ? 1 : 0;

print "Proposed release_date=$release_date\n" if $release_date;
if ($hold_until_date) {
	print "Records will be held until $hold_until_date\n";
} else {
	print "Records will be held for a whole default holding period: two years?\n";
}
print "Swith of calling copy2ebi script to compress and ascp run files = $call_copy2ebi\n";
my $r_date = $release_date;
$r_date = 'the date after default holding period' unless $r_date;
# Not an error message but using it for printing to STDERR (STDERR maybe caught to a log)
err_msg("Submission of $type($id) with release date of $r_date is going to start. Calling copy2ebi=$call_copy2ebi.");

# $submission_dir: where all related working files will be saved: run list, gzipped, md5
my ($repo, $submission_dir, $copy2ebi);
my ($center_name, $ebi_url, $ascp_path, $drop_account, $drop_account_pass);

use GDACAP::Repository;
prepare();

#parse_receipt("$submission_dir/receipt_uofa1342067993.xml");
#exit 0;

my $container;
# Prepare according to the submission type
if ($type eq 'experiment') {
	use GDACAP::DB::Experiment;
	$container = GDACAP::DB::Experiment->new();
} elsif ($type eq 'study')  { 
	use GDACAP::DB::Study;
	$container = GDACAP::DB::Study->new();
} else { err_msg("Nothing will be done."); exit;}

# Create a run list file
my $list = run_list($container->run_files($id), $repo);
if (@$list==0) {
	err_msg("No run has been found for publish.");
	exit 0;
}

print Data::Dumper->Dump([$list],[('run_list')]);

# Check if submission has been logged
use GDACAP::DB::Submission;
my $subm = GDACAP::DB::Submission->new();
my $info = $subm->info($type,$id); # Only logged submission can be updated
unless ($info && %$info) {
	$container->log_submission($id);
}

if ($call_copy2ebi) { # Need to transfer run files to EBI/SRA
	my $runlist = $submission_dir.'/'.$type.'_'.$id.'_runlist'.'.txt';
	open(my $fh, '>', $runlist) or die $!;
	foreach (@$list) {
		print "$$_[0]\t$$_[1]\n";
		print $fh "$$_[0]\t$$_[1]\n";	}
	close $fh;

	# Once run file list exported, call bash script to do gzip, md5 and ascp
	my @args = ($copy2ebi,$ascp_path, $drop_account, $drop_account_pass,$submission_dir, $runlist);
	system(@args)  == 0 or die "The call of copy2ebi with @args failed: $?";

	if ($? > 0) { err_msg("$0 has to stop because $copy2ebi did not finish successfully.") ; exit 1; }
}

## Once this long long run step has finished, prepare SRA object XML files
use GDACAP::DB::SRA;
my $sra = GDACAP::DB::SRA->new($center_name,$submission_dir,$type.'_'.$id);

my %sources = ();

my $study_id;
my @samples = ();
my @experiments =();

# Collect related objects: Samples, Experiments or Studies depends on submission type
if ($type eq 'study') {
	from_study();
} else {
	from_exp();
}

# Final check
print "Found ids:\n";
print "\tStudy id = $study_id\n";
print "\tSample ids are:\n\t";
print Data::Dumper->Dump([\@samples],['samples']);
print "\tExperiment ids are:\n\t";
print Data::Dumper->Dump([\@experiments],['experiments']);

die("Invalid study_id: $study_id.\n") unless $study_id > 0;
die("No sample has been found.\n") unless @samples > 0;
die("No experiment has been found.\n") unless @experiments > 0;

# Full set of objects should be reday now
# Create SRA objects
my $add = $sra->study($study_id);
# print "Returned add for study: ",Dumper($add),"\n";
$sources{study} = $add if $add;

$add = $sra->sample(\@samples);
$sources{sample} = $add if $add;
	
$sources{experiment} = $sra->experiment(\@experiments);
$sources{run} = $sra->run(\@experiments, $repo);

# Link actual SRA object XML files to STANDARD NAMED XML files
my @sra_objects = qw(sample study experiment run);
my $cur_xml_file;
foreach (@sra_objects) {
	$cur_xml_file = "$submission_dir/$_.xml";
	if (-e $cur_xml_file) {
		unlink $cur_xml_file or die "Cannot remove existing file $cur_xml_file: $!";
	}
	if (exists($sources{$_})) {
		symlink($sources{$_}, $cur_xml_file) or die "Can't symlink $sources{$_} to $cur_xml_file: $!";
		$sources{$_} = "$_.xml";
	}
}

#my $submission_fn = $sra->submission('uofa'.time,$release_date, \%sources);
$sources{submission} = $sra->submission('uofa'.time,$release_date, \%sources);
chdir $submission_dir;
#my $receipt = upload_xml($submission_fn, \%sources);
my $receipt = upload_xml(\%sources);
parse_receipt($receipt);
# Hard-code for testing parse receipt
#parse_receipt("$submission_dir/receipt_experiment_27_uofa1357626358.xml");

## ============= functions ==================
sub usage {
	die "Usage: $0 submit_type=type_id [release_date(''|'now'|'YYYY-MM-DD') skip_compress_ascp]\n";
}

# Convert local release date to one second earlier.
# All in GMT, no local to GMT conversion
sub release2holdtil {
	my ($release_date) = @_;
	return '' unless $release_date;
	return $release_date if $release_date eq 'now';
	my ($yyyy, $mm, $dd) = ($release_date =~ /(\d+)-(\d+)-(\d+)/);
	my $sec = timelocal_nocheck(-1,0,0, $dd, $mm-1,$yyyy);
	return strftime "%Y-%m-%d", localtime $sec;
}

# Calculates release date given days of holding up for.
# Internal use only. Default and longest holding time is two years (730 days) including today.
# It returns a string of date to be held until.
# Not used in normal cases
sub holdtil {
	my ($day_diff) = @_; # in days
	$day_diff = 730 unless $day_diff; #two years 
	$day_diff = $day_diff > 730 ? 730 : $day_diff; #two years only
	return strftime "%Y-%m-%d", localtime time+($day_diff-1)*86400-1;
}

# Convert holdUntil to release date
sub hold2release_date {
	my ($hold_date) = @_; # in days
	my ($yyyy, $mm, $dd) = ($hold_date =~ /(\d+)-(\d+)-(\d+)/);
	my $sec = timelocal_nocheck(59,59,23, $dd, $mm-1,$yyyy)+1;
	return strftime "%Y-%m-%d", localtime $sec;
}

# Prepare a list for bash script to gzip, md5 and send to EBI
# \@run_file_hashes comes either from run_files() of a Study or Experiment
# It calls Repository::fpath to map hashes to file pathes.
# It ruturns a list of [full_path, original_file_name]  
sub run_list {
	my ($run_file_hashes, $repo) = @_;

	my @list = ();	
	foreach (@$run_file_hashes) {
		push(@list,[$repo->fpath($$_[0]), $$_[1]]);
	}
	return \@list;
}

##All we need are study, samples, experiments and runs.
# One study, multiple samples and mulitple experiments
sub from_study {
	$study_id = $id;
	my $rcs = $container->submission_object_ids($id);
	return unless scalar(@$rcs)>0;

	foreach (@$rcs) {
#		print "experiment_id = $$_[0], sample_id = $$_[1]\n";
		push(@experiments, $$_[0]);
		push(@samples, $$_[1]);
	}
}

sub err_msg {
	print STDERR scalar(localtime), ": ", @_, "\n";
}

# One study, one sample and one experiment
sub from_exp {
	my $sample_id;
	($study_id, $sample_id) = $container->submission_object_ids($id);
	return unless ($study_id >0 and $sample_id > 0);
	
	push(@samples, $sample_id);
	push(@experiments, $id);
}

#sub upload_xml {
#	my ($file_names) = @_;
#	my $submission_xml = $$file_names{submission};
##	print Dumper($file_names);
##	print "$submission_xml\n";
	
#	use File::Basename;
#	my $receipt = $submission_dir.'/'.'receipt_'.basename($submission_xml);
#	my $curl_call = sprintf("curl -k -F \"SUBMISSION=\@%s\" -F \"STUDY=\@%s\" -F \"SAMPLE=\@%s\" -F \"EXPERIMENT=\@%s\" -F \"RUN=\@%s\"  \"%s\" > %s", $submission_xml,$$file_names{study},$$file_names{sample},$$file_names{experiment},$$file_names{run},$ebi_url, $receipt);
##	print STDERR "$curl_call\n";

#	unless (system($curl_call)  == 0) {
#		err_msg("XML file submission failed: $!"); 
#		unlink $receipt if -z $receipt; 
#		exit 1; 
#	}

##	print STDERR "Upload xml was successful. \n\n";
#	return $receipt;
#}

sub upload_xml {
	my ($file_names) = @_;
	my $submission_xml = $$file_names{submission};
#	print Dumper($file_names);
#	print "$submission_xml\n";
	
	my $receipt = $submission_dir.'/'.'receipt_'.basename($submission_xml);
	my $curl_call = sprintf("curl -k -F \"SUBMISSION=\@%s\"", $submission_xml,$$file_names{study});
	# Keep the order of objects is important
	foreach (qw(study sample experiment run)) {
		$curl_call .= " -F \"" . uc($_) . "=\@$$file_names{$_}\"" if exists($$file_names{$_});
	}
	$curl_call .= " \"$ebi_url\" > $receipt";
#	print STDERR "$curl_call\n";

	unless (system($curl_call)  == 0) {
		err_msg("XML files submission failed. More from curl: $!"); 
		unlink $receipt if -z $receipt; 
		exit 1; 
	}

#	print STDERR "Upload xml was successful. \n\n";
	return $receipt;
}

# ----------------------- XML Parsing Section -------------------------

# In an EBI/ENA submission receipt, MESSAGE node has multiple INFO nodes.
# One of it contains what ACTION this receipt was about.
# The pattern is:
# ACTION action ...
sub get_receipt_action {
	my ($info_arr) = @_;
	my $action;
	foreach (@$info_arr) {
		if ($_=~/(\S+) action/) {
			$action = $1;
			last;
		}
	}
	return $action;
}

# Errors are returned in an array by XML::Simple. EBI has lots spaces infront and end of
# error message, it needs to be cleaned and put into a string for easy handling.
sub get_receipt_error {
	my ($err_arr) = @_;
	my $err_msg = '';
	if ($err_arr) {
		$err_msg = $$err_arr[0];
		$err_msg =~ s/^\s+//; $err_msg =~ s/\s+$//; $err_msg .= '.';
		for (1..$#$err_arr) {
			$$err_arr[$_] =~ s/^\s+//; $$err_arr[$_] =~ s/\s+$//;
			$err_msg .= " $$err_arr[$_].";
		}
	}
	return $err_msg;
}

# EBI used two formats for time:
# receiptDate="2012-07-12T05:40:04.370+01:00";
# receiptDate="2013-01-08T06:05:30.963Z" # current format
sub get_action_time {
	my ($gmt) = @_;
	
	my ($yyyy, $mm, $dd, $h, $m, $s) = ($gmt =~ /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+\.\d+)\w+/);
	die "$gmt is not anticipated in the formats of 2012-07-12T05:40:04.370Z or 2012-07-12T05:40:04.370+01:00." unless $yyyy && $m;
    return strftime "%Y-%m-%d %H:%M:%S", localtime timegm_nocheck $s, $m, $h, $dd, $mm-1, $yyyy;
}

# create a state: after we interpret a submission receipt
# Parse the receipt XML file and update objects if receipt indicates successful
sub parse_receipt {
	my ($fn) = @_;
	$fn = $fn ? $fn : 'err.xml';
#	print STDERR "Parsing the receipt $fn.\n";

#	use GDACAP::DB::Submission;
#	my $subm = GDACAP::DB::Submission->new();
	my $info = $subm->info($type,$id); # Only logged submission can be updated
	die "The submission of $type($id) has not been logged in Table submission.\n" unless $info && %$info;

	my $xml = XML::Simple->new();

	my $receipt;
	return unless try {
		$receipt = $xml->XMLin($fn,ForceArray=>[qw/INFO ERROR/]); 1;
	} catch {
		err_msg("$fn: XML parsing failed. Might not a valid XML.\nParser said:$_"); 0;
	};
	# print output
#	print Data::Dumper->Dump([$receipt],["receipt_xml"]);
#	print Dumper($$receipt{MESSAGES}->{INFO});
	my $action = get_receipt_action($$receipt{MESSAGES}->{INFO});
	die "Action was not found. Is there a new pattern other than \"xxxx action ...\"?" unless $action;
	my $err_msg = get_receipt_error($$receipt{MESSAGES}->{ERROR});

# Prepare a hash for database insertion	
	my %state = (alias=>$$receipt{SUBMISSION}->{alias},
				submission_id=>$$info{id},
				action=>$action,
				act_time=>get_action_time($$receipt{receiptDate}),
				successful=>$$receipt{success},
				message=>$err_msg,
				);

#	print Dumper({%state});
	$subm->log_state(\%state); # Update the state of a submission in Table submission_state

# Object alias pattern: cenerPrefix_Object_id
#
# 31/01/2013 06:53:10 :
# I have not had a chance to test Action other than ADD or VALIDATE, 
# so do not know what are in receipts of other actions.
# Might have something unexpected show up and kill the program.
# ACTION - VALIDATE does not return accessions.
	if ($$receipt{success} eq 'true') {
		my @ebi_objects = qw(STUDY SAMPLE EXPERIMENT RUN); # We only interest these object
		my @parts = ();
		foreach (@ebi_objects) {
			if (exists($$receipt{$_}) && exists($$receipt{$_}->{accession})) { 
				# If this object exists in a submission and has accession, process it
				@parts = split('_',$$receipt{$_}->{alias});	
				$parts[1] = 'run_core' if $parts[1] eq 'run';
				if (exists($$receipt{$_}->{holdUntilDate}) && $parts[1] ne 'run_core') {
					GDACAP::DB::SRA->update_accession($parts[1],$parts[2],$$receipt{$_}->{accession},hold2release_date($$receipt{$_}->{holdUntilDate}));
				} else {
					GDACAP::DB::SRA->update_accession($parts[1],$parts[2],$$receipt{$_}->{accession});
				}
			}
		}
	}
}

# Prepare database, repository and submission variables with settings in submission.conf
# saved in current directory. 
# It sets $repo, $submission_dir, $copy2ebi, $ascp_path, $drop_account, $drop_account_pass, $center_name, $ebi_url.
# $submission_dir: where all related working files will be saved: run list, gzipped, md5 and XML, receipt.
sub prepare {
	use GDACAP::Resource ();
	GDACAP::Resource->prepare('submission.conf',1);
	my $repository = GDACAP::Resource->get_repository;
#	print "Settings of submission:\n";
#	print "Repository path = $$repository{target}\n";
	$repo = GDACAP::Repository->new($$repository{target});
	croak('Cannot access repository at '.$$repository{target}) unless $repo;

	my $folders = GDACAP::Resource::get_section('folders');
	my $ebi_settings = GDACAP::Resource::get_section('ebi');
#	print Data::Dumper->Dump([$folders, $ebi_settings],[qw(folders ebi_settings)]);

	$submission_dir = $$folders{submission};
	croak('Cannot find submission folder') unless -d $submission_dir;
	my $bin_dir = $$folders{bin}; # bash script copy2ebi saved in $$folders{bin} with the name hard coded.
	$copy2ebi = $bin_dir.'/copy2ebi';
	croak('Cannot find bash script copy2ebi') unless -e $copy2ebi;

	$center_name = $$ebi_settings{center};
	$ebi_url = $$ebi_settings{url};
	$ascp_path = $$ebi_settings{ascp_path};
	$drop_account = $$ebi_settings{drop_account};
	$drop_account_pass = $$ebi_settings{drop_account_pass};
}

__END__

=head1 NAME

ebi-submitter - Publish SRA objecs in a Study or an Experiment to EBI

=head1 SYNOPSIS

 # Submit all required objects of the experiemnt of id=24 with all default settings:
 # objects will be released in two years, transferring files to ebi first.
 perl ebi-submitter.pl experiment=24
 
 # Use default holding tiem but do not transfer files:
 perl ebi-submitter.pl experiment=24 '' 1

 # give a release date:
 perl ebi-submitter.pl experiment=24 2014-11-30

 # log error message to a log file:
 perl ebi-submitter.pl experiment=24 2014-11-30 2>>submission.log

=head1 DESCRIPTION

This script is part of GDACAP package. Normally it is not used from web user interface directly
but from command line by an administrator or in a cron job because time involved is significant.

It includes a few steps:
 1. checking type
 2. preparing run files if needed
 3. copying over run files if skip copying is not set
 4. generating xml files
 5. submitting xml files
 6. updating related records

The envrionmental variables concern EBI/SRA submission will be read from a configuration file.

Variable used in this scrip 
  $ebi_url: used by curl to upload XML files of Submission, Study, Example, Sample and Run
 	It has hard-coded drop box account and password.
 	Reference to EBI/SRA submission help file for how to create it.

Variables used in copy2ebi script
  $ascp_path: absolute path of local installation of ascp. Installed by running aspera-connection
  $drop_account: SRA drop box account, e.g. era-drop-xxx
  $drop_account_pass: password of drop box account

The run list file which is generated for a submission and passed to bash script copy2ebi is
saved in $submission_dir. The file name is $type.'_'.$id.'_runlist'.'.txt'.

By default, the script displays messages using STDOUT and STDERR. By redirecting them, the
messages can be logged files. e.g. perl ebi-submitter.pl experiment=1 2>>/my.log
 
Note: on 31/01/2013 06:53:10, I have not had a chance to test Action other than ADD or VALIDATE, 
so do not know what are in receipts of other actions. Might have something unexpected show up and kill the program.
A successful ACTION of VALIDATE does not return accessions.
A HOLD ACTION cannot act alone. It needs either ADD or MODIFY.

=head1 METHODS

These methods are utility subrountine.  

=over 4

=item * release2holdtil($date) - Converts release date set by user to holdUntilDate required by
EBI SRA schema. It is the day one second earlier than the proposed release date. Date is GMT.
If $date is not given, it calls holdtil without argument to get release date.

=item * run_list(\@run_file_hashes, $repo) - Prepare a list of run files for bash script copy2ebi
to gzip, md5 and send to EBI. The returned list contains elements [full_path, original_file_name].
\@run_file_hashes comes either from run_files() of a Study or Experiment.
$repo: GDACAP::Repository object.

=item * upload_xml(\%xml_file_names) - Upload XML files to EBI by calling curl. The hash
%xml_file_names has keys of Submission and other types of SRA objects only if needed to
be included in the submission.

=item * parse_receipt($receipt_xml) - Parses a submission receipt and creates a state of a
submission created before. Error message returned in receipt is saved in message field of Table
submission_state. If successful it updates included objects' accessions.

=item * hold2release_date($date) - Converts holdUntilDate in a SRA submission receipt to
release date. It is the next day of holdUntilDate.

=item * err_msg - Displays critical message to STDERR. It includes event time.

=cut
