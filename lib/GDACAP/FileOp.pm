package GDACAP::FileOp;

use strict;
use warnings;

use File::Spec;
use File::Copy;
use Digest::MD5 ();
use Digest::SHA ();

our $VERSION = '1.0';
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_files md5_file sha1_file copy_file read_file);

our $Debugging = 0;

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
	my ($folder) = @_;
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
	my ($fn) = @_;
	return unless $fn;
	return unless (-e $fn);
	print "Function md5_file: Reading $fn\n" if $Debugging;
	open(FILE, $fn) or die "Can't open '$fn': $!";
	binmode(FILE); # in case binary files are being read.
	return Digest::MD5->new->addfile(*FILE)->hexdigest;
} ## --- end sub md5_file

#===  FUNCTION  ================================================================
#         NAME: sha1_file
#      PURPOSE: Get SHA-1 checksum of a file
#   PARAMETERS: File name: $fn (string)
#      RETURNS: Returns the SHA-1 digest encoded as a hexadecimal string.
#===============================================================================

sub sha1_file {
	my ($fn) = @_;
	return unless $fn;
	return unless (-e $fn);
	print "Function sha1_file: Reading $fn\n" if $Debugging;
	my $sha = Digest::SHA->new(1);
	$sha->addfile($fn);
	return $sha->hexdigest;
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
	my ($fn) = @_;
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

__END__

=head1 NAME

GDACAP::FileOp - Common file operations in Genomics Data Capturer package

=head1 SYNOPSIS

 use GDACAP::FileOp qw(list_files md5_file sha1_file copy_file read_file);
 $GDACAP::FileOp::Debugging = 1;
 
 @files = @{ list_files('.') };
 copy_file($fn, 'new_name', $target_dir); 
 $data = read_file($fn);
 $digest_sha1 = sha1_file($fn);
 $digest_md5 = md5_file($fn);
 

=head1 DESCRIPTION

The functions included in this module are simple but commonly used. They have simple error handling to provide robust performance.

If needed, some debugging information can be printed out by setting 
 GDACAP::FileOp::Debugging = 1;

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
