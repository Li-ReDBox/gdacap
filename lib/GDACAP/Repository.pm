package GDACAP::Repository;

use strict;
use warnings;

use Try::Tiny;
require File::Spec;
require Carp;
require GDACAP::Resource;

my $tail_space = qr/\s+$/;

# $root: top path of where files are
# $req_path: optional, only when exporting or decommission is involved and Repository instance cannot write
# $maps: exporting names with their full paths
sub new {
	my ($class, $root, $req_path, $maps) = @_;
	return unless ($root && -e $root);
	my $self = {
		ROOT => $root,  # Root path of the repository
	};
	bless ($self, $class);
	return $self;
}

sub root {
	my ($self) = @_;
	return $self->{ROOT};
}

# Real path should not be revealed to outside.
sub fpath {
	my ($self, $hash) = @_;
	$hash =~ s/$tail_space//;
	return File::Spec->catfile($self->root,$hash);
}

sub exist {
	my ($self, $hash) = @_;
	my $fpath = $self->fpath($hash);
	return (-e $fpath);
}

sub file_handle {
	my ($self, $hash) = @_;
	my $fpath = $self->fpath($hash);
	return unless (-e $fpath);
	open(my $fh, '<', $fpath) or Carp::croak("Failed to open $fpath!", "\nreason=",$!);
	return $fh;
}

# If the second argument presents, just convert hashes to paths, checking is postponed
sub hashes2paths {
	my ($self, $hashes, $no_check) = @_;
	my @fpaths = ();
	my $apath;
	foreach(@$hashes) {
		$apath = $self->fpath($_);
		if ($no_check) {
			push(@fpaths, $apath);
		} else {
			push(@fpaths, $apath) if -e $apath;
		}
	}
	return \@fpaths;
}

# hashes and expoint name
# restore original file name
sub export {
	my ($self, $hash_names, $expoint_name, $sub_dir) = @_;
	my $status = 0;
	my $expoints = GDACAP::Resource::get_section('expoints');
	if (exists($$expoints{$expoint_name})) {
		my @path = split(',',$$expoints{$expoint_name}); # The structure is display name,full path, we need the last one
		my $export_path = File::Spec->canonpath($path[1].'/'.$sub_dir);
		my @fpaths = (); # Array of hash with keys of source (repo full path) and target (target full path)
		my $targetf;
		foreach(@$hash_names) {
			$targetf = File::Spec->catfile($export_path,$$_{original_name});
#			unless (-e -s $targetf) { # skip existing and non-zero size files, will not work if Apache cannot read
				push(@fpaths, {source=>$self->fpath($$_{hash}),target=>$targetf});
#			}
		}
		
		# `ls` is used because of -r $self->root cannot test reliably on a NFS mount.
		my $can_read_write; # strict test
		{
			use filetest 'access';
			$can_read_write = -w $export_path && -r $self->root;
		}
#		if (-w $export_path && system('ls',$self->root) == 0) { # writable to expoint, copy them 		
		if ($can_read_write) { # writable to expoint, copy them 		
			try {
				for (@fpaths) {
					if (-e $$_{source}) {
#						print "ln $_ $export_path\n" ;
						return unless system('ln',$$_{source},$$_{target}) == 0;
					} else {
						Carp::croak("Cannot find $_."); 
					}
				}
				$status = 1;
			} catch {
				print STDERR "Failed to copy file. More reason: $_";
			};
		} elsif (-e $path[1]) {
			my $repo = GDACAP::Resource::get_section('repository');
			my $requests = $$repo{requests};
			# Setting problem, die
			Carp::croak("Cannot create job request in $requests: not writable.") unless -w $requests;
			# Create job to there
			my $job_fn = File::Spec->catfile($requests,'exp',time().'.req');
			try {
				open(my $fh, '>', $job_fn) or Carp::croak "Cannot open $job_fn!", "\nreason=",$!,"\n";
				my $root = $$self{ROOT};
				foreach(@fpaths) {
					print $fh "$$_{source} $$_{target}\n";
				}
				close $fh;
				$status = 2;
			} catch {
				print STDERR $_;
			};
		} else {
			print STDERR "Expoint does not appear to exist - either has not been created or labelled correctly.\n";
		}
	} else {
		print STDERR "Expoint mapping point setting is wrong.\n";
	}
	return $status;
}

# Decommission files
# Returns -1: no files found: all files in the given list cannot be found, it is an error.
sub decommission {
	my ($self, $hashes) = @_;
	my $status = 0;
	my $repo = GDACAP::Resource::get_section('repository');
	my $fpaths = $self->hashes2paths($hashes, exists($$repo{requests}));
	return -1 unless @$fpaths; # If no given files found, returns -1. Something is not quite right.
	if (exists($$repo{requests})) { # Do not delete them directly, create a job request, this maybe because scheduler cannot write or even read repo->root
		my $dec_job_path = File::Spec->catfile($$repo{requests},'dec');
#		 Setting problem, die
		Carp::croak("Cannot create job request in $dec_job_path: not writable.") unless -w $dec_job_path;
#		 Create job to there
		my $job_fn = File::Spec->catfile($dec_job_path,time().'.req');
		try {
			open(my $fh, '>', $job_fn) or Carp::croak "Cannot open $job_fn!", "\nreason=",$!,"\n";
			foreach(@$fpaths) {
				print $fh "$_\n";
			}
			close $fh;
			$status = 2;
		} catch {
			print STDERR $_;
		};
	} else {
		try {
			for (@$fpaths) {
				if (-e $_) {
					return unless system('rm',$_) == 0;
				} else {
					Carp::croak("Cannot find $_."); 
				}
			}
			$status = 1;
		} catch {
			print STDERR "Failed to decommission/rm file. More reason: $_";
		};
	}
	return $status;
}

1;

__END__

=head1 NAME

GDACAP::Repository - Repository management module

=head1 DESCRIPTION

C<GDACAP::Repository> provides interface of a file repository. Fies are identified by their checksums instead of
names. Currently sha1 checksum is used. These checksums are also referenced as hashes. It processes querying, exporting, 
removing and other tasks to the files under management.

=head1 SYNOPSIS

	use GDACAP::Resource qw(get_repository);
	my $repository = get_repository;
	print "Repository settings:\n";
	print "source path = $$repository{source}, target path = $$repository{target}\n";
	use GDACAP::Repository;
	my $repo = GDACAP::Repository->new($$repository{target});
	croak('Cannot access repository at '.$$repository{target}) unless $repo;

	my $file_key = '90543c99fb044bde396f0246174c904d';
	if ($repo->exist($file_key)) {
		my $fpath = $repo->fpath($file_key);
		print "Real path of $file_key = $fpath\n";
	}

=head1 METHODS

=head2 new($repository_file_path)

The constructor. If the directory does not exist or readable, it returns undef.
The module only supports OO methods. 
All files are saved in a directory which is set in the constructor.This path is
saved as ROOT. To oustside, the only way to communicate is to provide file key - name.

=head2 root

Returns where the current repository root is.

=head2 fpath($file_key)

Private method. Returns the real path of a given file hash key. Currently, it is concstructed by:
	File::Spec->catfile($self->root,$hash);

=head2 exist($file_key)

Returns if a file identified by the $file_key exist.

=head2 file_handle($file_key)

Opens a file identified by $file_key and returns file handler for reading.

=head2 hashes2paths(\@hashes)

Returns a list of file paths of the list of file hashes. Any none-existing files is siliently skipped.

=head2 export(\@hashes, $expoint_name)

Exports a list of files identified by their checksums(@hashes) to a location ($expoint_name).
When successful, returns 1 for directly exported or 2 for job request. When failed, returns 0.

$expoint_name is the key of an expoint in the section [expoints] in a configuration file. Each expoint has format of:

 key = display name,full path

When a file is at expoint and the size is not zero (-s), copy is skipped. 
If the destination is writable, it copies files. If not and B<requests> path has
been set, it generates an export request in B<requests>/exp/time_stamp.reg with lines:

   /full/path/source /export/path

It has basic error handling and prints to STDERR when error raises.

=head2 decommission(\@hashes)

Decommission (physically remove) files of the given file hash list.

When B<requests> is set for the repository, a job request file is created in B<requests>/dec/time_stamp.reg with lines:

/full/path/file

Otherwise, it directly removes them.

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
