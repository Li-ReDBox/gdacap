The files under this directory are scripts come with the package.

ebi-submitter.* are scripts for submitting sequence files and XML files to fasp.sra.ebi.ac.uk.
There are two versions: 
	ebi-submitter.sh: a shell script version which was designed for setting free usage.
		It sets Perl environment variable of library path and calls ebi-submitter.pl;
	ebi-submitter.pl: a Perl script which provides actual functionalities. It can be 
		called by the above shell script or called directly with correct
		Perl environment variable of library path: either set by user or in Perl default @INC.
	   
ebi-submitter.pl needs a configuration file. One example is shown as ex_submission.conf. 
Replace the example with actual installation and account information and save as submission.conf.  

copy2ebi is a shell script for sending files to fasp.sra.ebi.ac.uk using Aspera. 
It is called by ebi-submitter.pl. Reference ebi.ac.uk for more information.
