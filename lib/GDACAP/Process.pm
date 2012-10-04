package GDACAP::Process;

use strict;
use warnings;

use Try::Tiny;
use JSON;
use Carp;

# For checking JSON from transmeta
# Properties in the list will be processed by function property()
my @PROPERTY_LIST = qw(Username ProjectAlias Name Category);
my @SPECIAL_PROPERTY_LIST = qw(Tool Output Input); #hash_ref, arrary_ref, arrary_hash_ref
my @OPTIONAL_PROPERTY_LIST = qw(Serial Comment Configuration);
# Among the above properties, these are optional
my %OPTIONAL_LIST = map {$_ => 1} @OPTIONAL_PROPERTY_LIST;

sub new {
	my ($class) = @_;
	return bless ({}, $class);
}

# Property block
# The property SET and GET interface of GDACAP::Process
# Two types of handerls are called depends on the name of property:
# 1. Simple mandatory properties: When SET is called, $pvalue cannot be empty
# 2. Simple optional properties
# 3. Special properties which have there own property handler.
sub property {
	my ($self, $pname, $pvalue) = @_;
	use feature ":5.10";
	given($pname) {
		when (@PROPERTY_LIST) {
			if (scalar(@_) == 3) {
				croak("Process: ", $pname," was given undefined value.\n") unless $pvalue;
				$self->{$pname} = $pvalue;
			}
			return $self->{$pname} if $self->{$pname};
		}
		when (@OPTIONAL_PROPERTY_LIST) {
			if ($pvalue) { $self->{$pname} = $pvalue; }
			return $self->{$pname} if $self->{$pname};
		}
		when (@SPECIAL_PROPERTY_LIST) {
			if ($pvalue) {
				return $self->$_($pvalue);
			} else {
				return $self->$_();
			}
		}
		default {
			croak "Unrecoginised property name: $_\n";
		}
	}
}

sub Tool {
	my ($self, $t) = @_;
	if ($t) {
		if (exists($$t{Name}) && exists($$t{Version})) {
			$self->{Tool} = $t;
		} else {
			croak "The keys name and version are both needed\n";
		}
	}
	return $self->{Tool};
}

# array of string
sub Input {
	my ($self, $in_hash) = @_;
	if (@$in_hash) {
		if (ref(@$in_hash[0]) eq 'HASH') {
			my @in_hashes = ();
			foreach (@$in_hash) {
				push(@in_hashes, $$_{Hash});
			}
			$self->{Input} = \@in_hashes;
		} else {
			$self->{Input} = $in_hash;
		}

	}
	return $self->{Input};
}

# array of hash
sub Output {
	my ($self, $out_files) = @_;
	if ($out_files) {
		$self->{Output} = $out_files;
		croak "No output file is provided\n" unless $self->{Output};
		croak "No output file is provided\n" unless @{$self->{Output}}>0;
		foreach (@{$self->{Output}}) {
			# print $$_{OriginalName},' ',$$_{Hash},' ',$$_{Type},"\n";
			# Cannot check if they are string type.
			if (not (length($$_{OriginalName})>0 && length($$_{Hash})>0 && length($$_{Type})>0))
			{
				print Data::Dumper->Dump([$_],[qw(output_file)]);
				croak "One of item is missing or in wrong format for output file. Expecting OrginalName, Hash and Type.\n";
			}
			if ( ref($$_{OriginalName}) || ref($$_{Hash})  || ref($$_{Type}))
			{
				print Data::Dumper->Dump([$_],[qw(output_file)]);
				croak "One of item is not a STRING for output file\n";
			}
		}
	}
	return $self->{Output};
}
# End of property block

# Pack GDACAP::Process in a single native Perl hash data type
sub get_hash {
	my ($self) = @_;
	foreach (@PROPERTY_LIST) {
		croak "Mandatory property $_ is missing" unless exists($self->{$_});
	}
	my %rv = %$self;
	return \%rv;
}

# Get a Process as a JSON string
sub get_json{
	my ($self) = @_;
	return to_json($self->get_hash());
}

# Load a Process from a JSON string
sub load_from_json {
	my ($self,$json_text) = @_;
	my $json_hash_ref;
	my $err = 0;
	try {
		# print "JSON_TEXT is\n",$json_text,"\n";
		$json_hash_ref = JSON->new->allow_nonref->decode($json_text);
	} catch {
		$err = 1;
		print STDERR "Cannot get the information of process. Wrong JSON format\n";
	};
	return 0 if $err;
	try {
		foreach (@PROPERTY_LIST) {
			croak "Mandatory property $_ is missing. Check spelling." unless exists($$json_hash_ref{$_});
			$self->property($_,$$json_hash_ref{$_});
		}
		foreach (@OPTIONAL_PROPERTY_LIST) {
			$self->property($_,$$json_hash_ref{$_}) if exists($$json_hash_ref{$_});
		}
		$self->Tool($$json_hash_ref{'Tool'});

		$self->Input($$json_hash_ref{'Input'}) if exists $$json_hash_ref{'Input'};
		$self->Output($$json_hash_ref{'Output'});
	} catch {
		$err = 1;
		print STDERR "Cannot get the information of process. Error was:\n $_";
	};
	if ($err) {	return 0; } else { return 1; }
}

# Paths related to Registration
my $POOLPATHS = undef; 
# string, the paths to file pool, source and target, optional reg_job
# Other paths of Repository operations are not used but just checked
sub pool_paths {
	my ($self, $value) = @_;
	if ($value) {
		# If a path is gviven, it has to be readable
		foreach (keys %$value) {
			croak "Invalid pool path $_:'$$value{$_}'" unless -e -r $$value{$_};
		}
		$POOLPATHS = $value;
	}
	return $POOLPATHS;
}

sub pool_path_source {
	my ($self, $value) = @_;
	if ($value) {
		die "Invalid source pool path ".$value if not -e $value;
		$$POOLPATHS{'source'} = $value;
	}
	croak 'Source path does not exist.' unless (defined($POOLPATHS) && -e $$POOLPATHS{'source'});
	return $$POOLPATHS{'source'};
}

#TODO: Might remove this property as it might be better not worry repository
sub pool_path_target {
	my ($self, $value) = @_;
	if ($value) {
		die "Invalid target pool path ".$value if not -e $value;
		$$POOLPATHS{'target'} = $value;
	}
	croak 'Target path does not exist.' unless (defined($POOLPATHS) && -e $$POOLPATHS{'target'});
	return $$POOLPATHS{'target'};
}

# -----------------------------------------------------------------------
# verify block

# Check user's permission in a project by Username and ProjectAlias in Process
# Mapping username and project alias to ids
sub permission {
	my ($self) = @_;
	my $status = {allowed => 0};
	require GDACAP::DB::Project;
	my $project = GDACAP::DB::Project->new();
	my $project_id = $project->alias2id($$self{ProjectAlias});
	return $status unless $project_id;

	require GDACAP::DB::Person;
	my $person = GDACAP::DB::Person->new();
	my $person_id = $person->username2id($$self{Username});
	return $status unless $person_id;

	require GDACAP::DB::Personrole;
	my $perm = GDACAP::DB::Personrole->new($person_id);
	if ($perm->has_right($project_id,'process') eq 'w') {
		$$status{allowed} = 1;
		$$status{project_id} = $project_id;
		$$status{person_id} = $person_id;
	}
	return $status;
}

# For display and check. Called by provider.
# Return value is a hash_ref with {error} to indicate if it has passed.
# As in files have been in system, they are provided by hash key (sha-1)'s which need some treats
# Check the existence, convert hashes to ids
# Return original information and check results
sub check {
	my ($self) = @_;

	my $process_hash = $self->get_hash();
	$$process_hash{'error'} = 0;
	$$process_hash{'msg'} = '';

	my $permit = $self->permission();
	if ($$permit{allowed}==0) {
		$$process_hash{'error'} = 1; $$process_hash{'msg'} = 'Permission denied';
		return $process_hash;
	}
	
	my @out_files = @{$$self{Output}};
	my $exist = 'No';
	foreach (@out_files) {
		if ($self->verify_outfile($$_{'Hash'})) {
			$exist = 'Yes';
		} else {
			$exist = 'No';
			$$process_hash{'msg'} .= "\n" if $$process_hash{'msg'};
			$$process_hash{'msg'} .= sprintf("%s (%s...) cannot be found.",$$_{OriginalName}, substr($$_{Hash},0,7));
			$$process_hash{'error'} = 1;
		}
		$$_{'flag'} = $exist;
	}

	if (exists($$self{Input}) && ! $$process_hash{'error'}) {
		require GDACAP::DB::File;
		my @infiles = @{$$self{Input}};
		# INPUT can be omitted
		if (@infiles) {
			my $finfo = GDACAP::DB::File->new();
			my $inf_hash_ref = {};
			my $file_rcd;
			for(0..@infiles-1) {
				$file_rcd = $finfo->extend_hash($$permit{project_id}, 	$infiles[$_]);
				if ($file_rcd) {
					$inf_hash_ref = {"OriginalName"=> $$file_rcd{original_name},
							"Hash" => $infiles[$_],
							"Type" => $$file_rcd{'type'}
							};
				} else {
					$$process_hash{'error'} = 1;
					$$process_hash{'msg'} .= "\n" if $$process_hash{'msg'};
					$$process_hash{'msg'} .= $infiles[$_]. ": unknown file provided as Input.";
					$inf_hash_ref = {"OriginalName"=> "Not found",
							"Hash" => $infiles[$_],
							};
				}
				$infiles[$_] = $inf_hash_ref;
			}
			$$process_hash{'Input'} = \@infiles;
		}
	}
	if ($$process_hash{'error'}) {
		my $person = GDACAP::DB::Person->new();
		$$process_hash{contact} = $person->contact($$permit{person_id});
	} else {
		$$self{project_id} = $$permit{project_id};
		$$self{person_id} = $$permit{person_id};
	}
	delete $$process_hash{'msg'} unless $$process_hash{'msg'};
	return $process_hash;
}

# Private function, called by verify_process
# To check if the file with the hash key (sha-1) exists physically at the source before copying.
# returns true or false.
sub verify_outfile {
	my ($self, $hash) = @_;
	my $full_path = File::Spec->catfile($self->pool_path_source,$hash);
	if (-e $full_path) { return 1; }
	else { return 0; }
}
# End of verify block
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# Registration block
# register_process starts the registration from the most vulnerable registration:
# 1. out_files which are from outside, 2. process metadaat, 3. in_files which are in the database.
sub register {
	my ($self) = @_;
	require GDACAP::DB::Process;
	my $proc = GDACAP::DB::Process->new();
	return $proc->create($self->get_hash());
}

# Move files from source into target after successfully registered Process
# return values: 1: successful, 0: not copied, 2: not removed
#TODO: may need to move into Repository pacakge.
sub copy_outfiles {
	my ($self, $perm_handler) = @_;
	# if path for saving registraion job reg_job has been set, only lodge job then returns
	# otherwise, move file into Repository by first copy and then delete
	if (exists($$POOLPATHS{requests})) { return $self->create_job(); }
	my $source_path = $self->pool_path_source;
	my $target_path = $self->pool_path_target;
	my ($cur_fn, $success);
	my @outfiles = @{$self->{Output}};
	foreach(@outfiles) {
		$success = 0;
		$success = try {
			$cur_fn = File::Spec->catfile($source_path,$$_{Hash});
			if ($perm_handler) { 
				system((@$perm_handler,$cur_fn)); 
			}
			if (GDACAP::FileOp::copy_file($cur_fn,$$_{Hash},$target_path)) {
				system('chmod','644',File::Spec->catfile($target_path,$$_{Hash}));
				return 1;
			} else {
				print STDERR "Cannot copy file into secure place. Reason is: $!\nSource=",$cur_fn,"\tTarget=",$target_path;
				return 0;
			}
		} catch {
			0;
		};
		if ($success) {
			if (system('rm','-f',$cur_fn)==0) { $success = 1; }
			else { $success = 2; }
		}
#		if ($success) {
#			if (system('cp','/dev/null',$cur_fn)==0) { $success = 1; }
#			else { $success = 0; }
#		}
		return $success unless $success==1;
	}
	return 1;
}

# Create a put job: to get a file into repository by other software when this running instance have no write permission
# full_path_name repo_target_path
sub create_job {
	my ($self) = @_;
	my $source_path = $self->pool_path_source;
	my $target_path = $self->pool_path_target;
	
	my $status = try {
		my $job_fn = File::Spec->catfile($$POOLPATHS{requests},'reg',time().'.req');
		open(my $fh, '>', $job_fn) or croak "can't open $job_fn!", "\nreason=",$!,"\n";
		foreach(@{$self->{Output}}) {
			print $fh File::Spec->catfile($source_path,$$_{Hash})," ",$target_path,"\n";
		}
		close $fh;
		return 1;
	} catch {
		return 0;
	};
	return $status;
}

1;

__END__

=head1 NAME

GDACAP::Process - Data strucute of Process data type

=head1 SYNOPSIS

	# Generally, it is used as following:
	my $jp = GDACAP::Process->new();

	$jp->property('Name',"name string");
	$jp->property('Category',"category string");
	$jp->property('Comment',"comment string, can be long");
	$jp->property('Tool',$tool_hash);
	$jp->property('Input',$array);
	$jp->property('Output',$array_of_hash);

	# Check a Process instance using function get_hash:
	my %hv = %{$jp->get_hash()};
	print Dumper(\%hv);

	# Convert a Process to JSON
	$json = $jp->get_json();

	# Load a JSON into a Process
	$jp->load_from_json($json);

	use GDACAP::Resource ();
	GDACAP::Resource->prepare('config.conf');
	my $repository = GDACAP::Resource::get_repository();
	$jp->pool_paths($repository);

	my $rt = $jp->check();
	if ($$rt{error}) {
		print("Verificatin failed. More reason:\n", to_json($rt));
		return;
	}


	if ($jp->register()) {
		print "Registration was successful\n";
	} else {
		print "Failed to register your process. More reason: $_\n";
	}
	if ($jp->copy_outfiles()) {
		print "Outcoming files were copied successfully\n";
	} else {
		print "Failed to register your process. More reason: $_\n";
	}
	undef $jp;

=head1 DESCRIPTION

C<GDACAP::Process> is a module to create a Process in the system with metadata describes what it is about, and its inputs and outputs.
It needs the identifiers of project and user to check permission and to save it in correct way. The description can be set by setting
each property and the integrity is checked when the whole set of data is retrieved by C<get_hash()>. It also to load from a JSON string
with all mandatory properties.

Process is an instance of usage of a tool to accomplish a task.
It has C<ProjectAlias>, C<Serial> (optional), C<Username>, C<Name>, C<Category>, C<Configuration>, C<Comment>, C<Tool>, C<Input> and C<Output>. A typical Process defined in Perl looks like this:

  my $p_hash_ref = {
  "ProjectAlias" => "the name of project with which files associate",
  "Username" => "user login name",
  "Serial": "12312267365637543180547980626",
  "Name" => "The name is meaningful to you",
  "Category" => "Agreed process category or type",
  "Configuration" => "Command line arguments",
  "Comment" => "Describe your process",
  "Tool" => {
      "Name" => "Your valuable tool",
      "Version" => "2"
   },
   "Input" => ["c9d05e70ef07fcfc210b618705e1b0e9"],
   "Output" => [	{
		"OriginalName"=> "the name I would like",
		"Hash"=> "SHA-1_name1",
		"Type"=> "BAM",
		"Size":1471587756
		},
		{
		"OriginalName"=> "the name helps me",
		"Hash"=> "SHA-1_name2",
		"Type"=> "BAM",
		"Size":1471587756
	    }]
  };

=head2 Structure of Process

Process has key-value pairs. Except C<Serial>, C<Input>, C<Comment> and C<Configuration>, all other keys cannot be omitted. Important properties are explained:

=over

=item *

C<ProjectAlias> gives an identification string of a project. It has to be the alias of the project.

=item *

C<Username> gives an identification string of a user. It has to be the username used in the system. It is used to put uploaded files with the process in a temporay pool to allow user link them to a project later.

=item *

C<Name> gives an identification string to a Process.

=item *

C<Category> classifies a Process by a string. This has to be an agreed C<Category> otherwise it will fail. I<TODO>: check from C<Category> vocabulary.

=item *

C<Input> provides hashes of input files which can be identified by the system. They should have been in the system. C<Input> and C<Output> together provides history of data (e.g. file). Currently, md5 hash is supported.

=item *

C<Output> gives information of new data to a Process. As for files, it needs C<orignal_name>, C<hash> and C<type>. Only C<hash> is checked before it is registered by C<Ands::ProcessRegister>. None of these items are optional and they have to be strings.

=back

=head2 FUNCTIONS

=over

=item * property($name, $value)

C<property> is a general purpose property SET and GET function. User can use this function to set properties.
When SET version is called but no TRUE value has been given, it croaks for mandatory properties.

=item * get_hash()

It returns a hash reference contains properties which have been set. It checks if mandatory perperties have been set. If not, it croaks.

=item * load_from_json($json_text)

It converts a Process in JSON format. It checks if mandatory perperties have been set. If not, it croaks.

=item * check()

Checks if permission, Inputs have been in the database, Outputs are in Repository{Source}. It returns a Hash reference which contains
all orginal keys and values. If there is an error, Hash{error} = 1 otherwise Hash{error} = 0. It also returns error message in 
Hash{msg} to notify user.

Three typical errors:

=over 2

=item * Permission denied: either wrong username but most likey wrong ProjectAlias in any sense
{
  'msg' => 'Permission denied',
  'Tool' => {
			  'Version' => 'version',
			  'Name' => 'my tool'
			},
  'Username' => 'non-exist',
  'ProjectAlias' => 'testp',
  'Output' => [
				{
				  'Type' => 'text',
				  'Size' => 928,
				  'Hash' => '2db93aa5ee6a9b90b30aebc60d167c55905178dd',
				  'OriginalName' => 'batch.txt'
				}
			  ],
  'error' => 1,
  'Name' => 'test',
  'Category' => 'test',
};

=item * Output file does not exist
{
  'msg' => 'batch.txt (2db93aa...) cannot be found.',
  'contact' => {
				 'email' => 'user@domain',
				 'title' => 'Mr',
				 'family_name' => 'Smith',
				 'given_name' => 'John'
			   },
  'Tool' => {
			  'Version' => 'version',
			  'Name' => 'my tool'
			},
  'Username' => 'user',
  'ProjectAlias' => 'testp',
  'Output' => [
				{
				  'Type' => 'text',
				  'Size' => 928,
				  'Hash' => '2db93aa5ee6a9b90b30aebc60d167c55905178dd',
				  'flag' => 'No',
				  'OriginalName' => 'batch.txt'
				},
				{
				  'Type' => 'text',
				  'Size' => 928,
				  'Hash' => '92a0c2525d3aeda72c5c08d13a49c43d6b980652',
				  'flag' => 'Yes',
				  'OriginalName' => 'batch2.txt'
				}
			  ],
  'error' => 1,
  'Name' => 'test',
  'Category' => 'test',
};

=item * Input checksum cannot be varified

{
  'msg' => '92a0c2525d3aeda72c5c08d13a49c43d6b980652a: unknown file provided as Input.',
  'ProjectAlias' => 'tp1',
  'contact' => {
				 'email' => 'jianfeng.li@adelaide.edu.au',
				 'title' => 'Dr',
				 'family_name' => 'Li',
				 'given_name' => 'Jianfeng'
			   },
  'Tool' => {
			  'Version' => 'version',
			  'Name' => 'my tool'
			},
  'Username' => 'jianfeng',
  'Output' => [
				{
				  'Type' => 'text',
				  'Size' => 928,
				  'Hash' => '933a53be3bfebe748f27d907c930e29e851ab9e2',
				  'flag' => 'Yes',
				  'OriginalName' => 'out.txt'
				}
			  ],
  'error' => 1,
  'Input' => [
			   {
				 'Hash' => '92a0c2525d3aeda72c5c08d13a49c43d6b980652a',
				 'OriginalName' => 'Not found'
			   }
			 ],
  'Name' => 'test',
  'Category' => 'test'
};

=back

=item * register()

Uses the checked information to register new files submitted in Output and metadata. If successful, returns true otherwise false.

=item * copy_outfiles()

Puts files into repository.  If done successfully, returns true otherwise false.

This is not a necessary step of registeration so it is not called by C<register>. It is only needed when: 1. a repository exists;
2. has working area and stroage area; 3. two areas are different.

Depending on how the system is set up to interact with repository it can either move files into repository
or create a job request asking other software to do it when repository is managed by another software/account.
The switch is the B<requests> in [repository] section of configuration file.
If B<requests> (a path) is set, it calls create_job() to create a job under B<requests/reg> (hard coded request type) instead of moving directly.
A job request can have multiple rows. Each row has two columns which are delimited by space: a full path of file and repository_storage. 

Otherwise, first copy files listed as Output to Reopsiotry{Target}
and then if successful, remove them. File permission has be be correct to allow removal. 

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
