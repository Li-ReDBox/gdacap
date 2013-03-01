#!/bin/bash

# This is the shell script for wrapping Perl scripts come with the library
#   when it is not installed into system but just copied.
# This script uses its path $bin_path as the anchor and assumes the library locates
#   one level up in lib directory: ../lib. If the assumptions are confirmed,
#   it sets environment variable PERLLIB to ../lib and calls Perl script it wraps
#   with arguments were given. 
# The script can be run by absolute path or through a link.

# This is an example how to wrap.

#echo "$@"

if [[ -h $0 ]]; then
	wraper_name=`readlink $0`
else
	wraper_name=`ls $0`
fi

bin_path=`dirname $wraper_name`
	
#echo "wrapper_name=$wraper_name, bin_path=$bin_path"

wd="$bin_path/../lib"
if [[ ! -e "$wd" ]]; then
	echo "Cannot find the library: $wd"
	exit 1
fi	

export PERLLIB=$wd

#echo "Env"
#perl -le 'print for @INC'

perl $bin_path/ebi-submitter.pl "$@"
