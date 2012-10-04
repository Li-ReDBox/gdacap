package GDACAP::DB::Run;

use strict;
use warnings;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

use Try::Tiny;

my @fields = qw(id experiment_id run_date accession);
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

my $file_fields = 'file_copy_id,raw_file_name,type'; # about run_file

our @creation = qw(experiment_id run_date file_copy_id);
our @creation_optional = qw(phred_offset); 

sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM run WHERE id = ?",$id);

	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.

	$self->_load_run_files();
	# As only FASTQ files have attribute, so it makes sence to distinguish
	# At the moment, only FASTQ is supported, so get attributes automatically
	# if ($self->{DATA}->{type} eq 'FASTQ') {
		$self->_read_attribute();
	# }

	return $self->values();
}

# one or two run files of a run_core
sub _load_run_files {
	my ($self) = @_;
	$self->{FILES} = $self->array_hashref("SELECT $file_fields FROM run WHERE id = ?",$$self{id});
}

sub get_attribute {
	my ($self, $atype, $id) = @_;
	$id = $id ? $id : $self->id;
	return unless $id;
	
	return unless $atype;
	if (!exists($self->{$atype})) {
		$self->_read_attribute($atype,$id);
	}
	return $self->{$atype};
}

# attributes of a run_core
sub _read_attribute {
	my ($self, $atype) = @_;

	if ($atype) { 
		my $attr = $self->row_value("SELECT avalue FROM attribute WHERE table_name = 'run_core' AND item_id = ? AND atype = ?",($$self{id},$atype));
		$self->{atype} = $attr unless $attr;
	} else {
		my $attrs = $self->array_hashref("SELECT atype, avalue FROM attribute WHERE table_name = 'run_core' AND item_id = ?",$$self{id});
		foreach (@$attrs) { $self->{$$_{atype}} = $$_{avalue}; }	
	}	
}	

# # Get all processes start from curretly loaded run
# # The reason for only starting loaded as it needs file_copy_id not run.id
# sub get_processes {
	# my $self = shift;
	# return unless $self->id;
	# my $st_name = 'get_processes';
	# my $sth = $self->statement_handler($st_name);
	# if (!$sth) {
		# my $statement = 'SELECT process_id,in_copy_id,out_copy_id FROM seek_process_children(?)';
		# $sth = $self->statement_handler($st_name,$statement);
	# }
	# my $rv = $self->dbh->selectall_hashref($sth,'process_id',{},$self->file_copy_id) or die $self->dbh->errstr;
	# # return $self->dbh->selectall_hashref($sth,'id',{},$id);
	# return $rv;
# }

# $phred_offset only required if run files are FASTQ files
# $exp_id, $run_date, $file_copy_ids, $phred_offset
sub create {
	my ($self, $info) = @_;
	
	my $sql_run_core = 'INSERT INTO run_core (experiment_id, run_date) VALUES (?, ?) RETURNING id';
	my $sql_run_file = 'INSERT INTO run_file (run_id, file_copy_id) VALUES (?, ?)';
	require GDACAP::DB::File;
	my $id = 0;
	$dbh->begin_work;
	try {
		$id = $dbh->selectrow_array($sql_run_core,{},$$info{experiment_id}, $$info{run_date});
		if ( $id ) {
			my $finfo = GDACAP::DB::File->new();
			my $ftype;
			my $boffset_yet = 1;
			foreach (@{$$info{file_copy_ids}}) {
				if ($boffset_yet) { # only need to be done once
					$ftype = $finfo->type($_);
					if (index($ftype, 'FASTQ')>=0) { 
						die "Phred score offset is not available" unless $$info{phred_offset}; 
						$dbh->do("INSERT INTO attribute (table_name, item_id, atype, avalue) VALUES ('run_core', ? , 'phred_offset', ?)", {}, $id, $$info{phred_offset}) or die  $dbh->errstr;
						$boffset_yet = 0;
					}
				}
				$dbh->do($sql_run_file,{}, $id, $_) or die  $dbh->errstr;
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

# $id, $run_date, $file_copy_ids, $phred_offset
sub update {
	my ($self, $info) = @_;
	$dbh->do('UPDATE run_core SET run_date = ? WHERE id = ?',{},$$info{run_date}, $$self{id}) or die $dbh->errstr;
	# Clean all before update
	$dbh->do('DELETE FROM run_file WHERE run_id = ?',{},$$self{id});
	my $sth = $dbh->prepare('INSERT INTO run_file (run_id, file_copy_id) VALUES (?, ?)');
	foreach (@{$$info{file_copy_ids}}) {
		$sth->execute($$self{id}, $_) or die $sth->errstr;
	}
	if ($$info{phred_offset}) {
		my $old =  $self->get_attribute('phred_offset');
		if ($old) {
			$dbh->do("UPDATE attribute SET avalue = ?  WHERE table_name = 'run_core' AND item_id = ? AND atype = 'phred_offset'",{},$$info{phred_offset}, $$self{id}) or die $dbh->errstr;
		} else {
			$dbh->do("INSERT INTO attribute (table_name, item_id, atype, avalue) VALUES ('run_core', ? , 'phred_offset', ?)", {}, $$self{id}, $$info{phred_offset}) or die  $dbh->errstr;
		}
	}
	$self->by_id($$self{id});
}

1;
__END__
=head1 NAME

GDACAP::DB::Run - Run files in NCBI model

=head1 SYNOPSIS

  # Generally, it is used as following:
	my $run = GDACAP::DB::Run->new();
 
  # Create a Run
	print $run->create($exp)id,$file_copy_id,'name of a run');
  # Or update	
	print "Update status: ",$run->update($exp_id,'testname'),"\n";
	print Dumper($run->get());
	
  # retreive file_copy_id of a run file
	print Dumper($run->by_id($id));

=head1 DESCRIPTION

Each B<Experiment> has 1 to many B<Run>s. Each B<Run> has maximal two files if they are paired reads. This is only the case of FASTQ. It also needs Phred score offset if they are in FASTQ format.

=head1 Run DATA structure

Compounded data of a B<Run> is saved in a hash named as DATA. Structurally:

	{
		id => run_id,
		experiment_id => id of experiment,
		run_date => data of the experiment run,
		FILES => [
				  {
					file_copy_id => id of file copy,
					raw_file_name => the human readable name,
					type => file type
				   }
				]
		phred_offset => attribue Phred score offset when run file type is FASTQ, optionaly,
		'attribute name' => value of the attribute, optionaly,
	}
	
=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.


=head1 AUTHOR

Jianfeng Li


=cut

