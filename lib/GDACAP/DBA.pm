package GDACAP::DBA;

use strict;
use warnings;
use Carp;

use DBI ();
use Try::Tiny;

sub connect {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self if $self->establish(@_) == 1;    
}

sub establish {
	my $self = shift;
	my @parms = @_;
	my $nparms = scalar(@parms);
	if ($nparms == 1) { return $self->open(@parms); }
	else { return $self->pg_connect(@parms); }
	return 0;
}

# This is SQLite3 connection
# DBI::SQLite creates file if did not find one
sub open {
	my $self = shift;
	my $db_file = shift;
	if (! -e $db_file) {
		croak("Cannot find $db_file - Please provide an existing SQLite file.");
		return 0;
	}
	
    my $dbargs = {
        AutoCommit => 0,
        PrintError => 1
    };

    $self->{DBH} = DBI->connect( "dbi:SQLite:dbname=$db_file", "", "", $dbargs ) or croak($DBI::errstr);
    return 1;
}

sub pg_connect {
	my $self = shift;
    my $dbargs = {
        AutoCommit => 1,
        PrintError => 1
    };
	my ($dbname, $host, $user_name, $pass_wd) = @_;
	$self->{DBH} = DBI->connect('dbi:Pg:dbname='.$dbname.';host='.$host,$user_name,$pass_wd,$dbargs) or croak($DBI::errstr);
	return 1;
}

sub dbh {
	my $self = shift;
	return $self->{DBH};
}

sub commit {
	my $self = shift;
	my $rv = $self->{DBH}->commit() or croak($DBI::errstr);
}

sub disconnect {
	my $self = shift;
	$self->{DBH}->disconnect();
}

# return the error message raised in the last call.
# always check the return status code and only call this function when code indicates error
# this is used in the situations where a wrongly executated statement do not die
sub err {
	my $self = shift;
	return $self->{error};
}

sub print_row {
	my ($self, $sth) = @_;
	try {
		while ( my (@some) = $sth->fetchrow_array()) {
			foreach(@some) { print $_, " "; }
			print "\n";
		}
		if ( $self->{DBH}->err() ) { croak($DBI::errstr); }
	} catch {
		print "foreach went wrong: detail is as: $_\n";
	};
}

# for consuming by other pacakges, not useful execept in debugging
sub pack_result {
	my ($self, $sth) = @_;
	return unless $sth->{Active};
	carp('At most, 100 rows returned.');
	return $sth->fetchall_arrayref(undef,100) if $sth;
}

# two arguments: void insert, three arguments: returns id (row has to have id field)
sub build_insert {
	my ($table, $fields) = @_;
	my $statement = sprintf("INSERT INTO %s (%s) VALUES (%s)", $table, join(",", @$fields), join(",", ("?")x@$fields));
	if (scalar(@_)>2) {
		$statement .= " RETURNING id";
	}
	return $statement;	
}

# INSERT statement is cached, no newly inserted id returned
sub insert_cached {
	my ($self, $table, $field_values) = @_;
    my @fields = keys %$field_values;
    my @values = @{$field_values}{@fields};
	my $statement = build_insert($table,\@fields);
    my $sth = $self->{DBH}->prepare_cached($statement) or croak($DBI::errstr."\n\t".$statement);
    my $rv = $sth->execute(@values) or croak($DBI::errstr);
	return 1;
}

# only simple all true Equality conditions are supported
sub query_cached {
	my ($self, $table, $field_list, $conditions) = @_;
    # sort to keep field order, and thus sql, stable for prepare_cached
    my @fields = sort keys %$conditions;
    my @values = @{$conditions}{@fields};
    my $qualifier = "";
    $qualifier = "where ".join(" and ", map { "$_=?" } @fields) if @fields;
	my $return_fields = join(',',@$field_list);
    my $sth = $self->{DBH}->prepare_cached("SELECT $return_fields FROM $table $qualifier") or croak($self->{DBH}->errstr,"\nThe statement is:\n\t",$DBI::lasth->{Statement},"\n");
    my $rv = $sth->execute(@values) or croak($sth->errstr);
	return $sth;	
}

# similar to DBI::do but mainly for preparing arbitrary SQL statement and returning DBI::StatementHandler
sub do{
	my ($self, $statement, $params) = @_;
	# print "The statement is\n$statement\n";
	my $sth = $self->{DBH}->prepare_cached($statement) or croak($self->{DBH}->errstr,"\nThe statement is:\n\t",$DBI::lasth->{Statement},"\n");
	my $rv = $sth->execute(@$params) or croak($sth->errstr);
	return $sth;	
}

# Used for executing a prepared statement handler with values
sub execute {
	my ($self, $sth, $values) = @_;
	my $rv = $sth->execute(@$values) or croak($self->{DBH}->errstr,"\nThe statement is:\n\t",$DBI::lasth->{Statement},"\n");
	return $sth;	
}

1;

__END__

=head1 NAME

GDACAP::DBA - Basic database operations

=head1 Synopsis

  # Create and connect:
  # For SQLite, only existing database is allowed
  my $dbh = DBA->connect('test_sqlite3.db'); 

  # Query function of a single table:
  # 1. without conditions
  my @q_fields = ('id','tool','description');
  my $sth = $dbh->query_cached('process',\@q_fields);
  $dbh->print_row($sth);

  # 2. with conditions
  #	Simple all true Equality conditions  
  $sth =  $dbh->query_cached('process',['id'], {id => 1, tool => 'tool 1'});
  $dbh->print_row($sth);
  
  # More complex query
  # Wheter build directly or based on executed existing non-conditional SQL
  my $mod_sta = $sth->{Statement}.' where id > ? and tool = ?';
  my $conditions = [5,'HiSeq 2000'];
  $sth = $dbh->do($mod_sta,$conditions);
  
  # complex query: direct sql statement
  $sth = $dbh->do('SELECT * FROM process where id > ? AND description = ?', [5,'HiSeq 2000']);
  $dbh->print_row($sth);

  # Insert function
  # field and vale pairs 
  my %file_record = (ori_name => 'fastq read 1', md5 => 'sdfsdfsdfsds',);
  $dbh->insert_cached('file',\%file_record); # return 1 when successfully executed

=head1 Description

c<DBA> is designed to provide a tool set for making operations of database simpler. If needed, call $ADB->dbh() to get the handler access database object directly. Otherwise, query, insert can be done once and repeatly. 