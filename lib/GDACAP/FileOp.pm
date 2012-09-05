package GDACAP::FileOp;

use strict;
use warnings;

use File::Spec;
use File::Copy;
use Digest::MD5 ();
use Digest::SHA1 ();

our $VERSION = '1.0';
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_files md5_file sha1_file copy_file read_file);

my $Debugging = 0;
# set debug level for __PACKAGE__
sub set_debug {
	$Debugging = shift;
}

#===  FUNCTION  ================================================================
#         NAME: list_files
#      PURPOSE: Generates a list of file names of a directory
#   PARAMETERS: $folder (string)
#      RETURNS: reference of an array: the list of full path file names found
#  DESCRIPTION: It checkes the file names and only returns the names of file not directory
#       THROWS: no exceptions
#     COMMENTS: Full paths are returned.
#===============================================================================
sub list_files {
	my $folder = shift;
	return unless $folder;
	return unless (-e $folder);
	my @list = glob(File::Spec->catfile($folder,'*'));
	my @rt_list;
	foreach my $fn (@list) {
		print "$fn\n" if $Debugging; 
		#if (-f $fn) { print "Adding $fn\n"; push(@rt_list,$fn); }
		push(@rt_list,$fn) if (-f $fn);
	}
	return \@rt_list;
}

#===  FUNCTION  ================================================================
#         NAME: md5_file
#      PURPOSE: Get md5 checksum of a file
#   PARAMETERS: File name: $fn (string)
#      RETURNS: MD5 checksum in hex
#===============================================================================

sub md5_file {
	my $fn = shift;
	return unless $fn;
	return unless (-e $fn);
	print "Reading $fn\n" if $Debugging;
	open(FILE, $fn) or die "Can't open '$fn': $!";
	binmode(FILE); # in case binary files are being read.

	my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
	print "$fn: MD5 checksum\n",$md5 , "\n" if $Debugging;

	return $md5;
} ## --- end sub md5_file

#===  FUNCTION  ================================================================
#         NAME: sha1_file
#      PURPOSE: Get md5 checksum of a file
#   PARAMETERS: File name: $fn (string)
#      RETURNS: SHA1 checksum in hex
#===============================================================================

sub sha1_file {
	my $fn = shift;
	return unless $fn;
	return unless (-e $fn);
	print "Reading $fn\n" if $Debugging;
	open(FILE, $fn) or die "Can't open '$fn': $!";
	binmode(FILE); # in case binary files are being read.
	my $sha1 = Digest::SHA1->new->addfile(*FILE)->hexdigest;
	print "$fn: SHA1 checksum:\n",$sha1 , "\n" if $Debugging;
	return $sha1;
} ## --- end sub sha1_file

#===  FUNCTION  ================================================================
#         NAME: copy_file
#      PURPOSE: Copy original uploaded file to a folder with a given name
#   PARAMETERS: File name: $fn (string)
#				New file name: $new_fn (string)
#				Destination directory: $des_dir (string)
#      RETURNS: Boolean: true for successful
#===============================================================================

sub copy_file {
	my ($fn, $new_fn, $des_dir) = @_;
	print "Copying file $fn to $des_dir with new name $new_fn\n" if $Debugging;
	# if catfile($des_dir,$new_fn) exists, file will be overwritten.
	return copy($fn,File::Spec->catfile($des_dir,$new_fn));
} ## --- end sub copy_file

#===  FUNCTION  ================================================================
#         NAME: read_file
#      PURPOSE: Read a file line by line
#   PARAMETERS: File name: $fn (string)
#      RETURNS: String, content
#  DESCRIPTION: It reads text file by the given name
#===============================================================================

sub read_file {
	my $fn = shift;
	open(my $fh, '<', $fn) or die "can't open $fn!", "\nreason=",$!,"\n";
	my $content ='';
	while (<$fh>) {
		$content .= $_;
	}
	close $fh;
	return $content;
}
## --- end sub read_file 

1;
