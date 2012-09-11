package GDACAP::DB::Person;

use strict;
use warnings;
use Try::Tiny;

use GDACAP::Table;
our @ISA = qw(GDACAP::Table);

my @fields = qw(id title given_name family_name username email phone);
our $brief_fields = join(',',@fields);

@fields = (@fields, qw(anzsrc_for_code anzsrc_for webpage has_validated_email is_authorized is_active serial));
my $query_fields = join(',',@fields);
our %permitted = map { $_ => 1 } @fields;

# for Web interface
our @creation = qw(title given_name family_name username passwd email phone anzsrc_for_code organisation_id);
our @creation_optional = qw(webpage);

# returns hash of titles
our %full_title = (
	dr   => 'Dr',
	mr   => 'Mr',
	ms   => 'Ms',
	mrs  => 'Mrs.',
	miss => 'Miss',
	prof => 'Prof',
);

use Digest::SHA (); 
	
sub new {
	my ($class) = @_;
	$class->SUPER::new();
	return bless ({}, $class);
}

# Methods associate with a single record
# returns 1: successful, undef: failed
sub create {
    my ( $self, $info ) = @_;
	my $salt_pinch = salt();
	my $hashed_pwd = hash_password($$info{passwd}, $salt_pinch);
	# organisation_id in @creation is mandatory but is for Table person_organisation, so it is not used directly
	my @fields = qw(title given_name family_name username email phone anzsrc_for_code);
	my $insert_list = join(',',@fields);
	# pick up from optional fields which are not empty
	my @ov = ();
	for (@creation_optional) {
		if ($$info{$_}) { push(@ov,$$info{$_}); $insert_list .= ','.$_; }
	}
	my @values = (@{$info}{@fields}, @ov, $salt_pinch, $hashed_pwd);
    my $sql = "INSERT INTO person ($insert_list, salt, hash) VALUES (". join(",", ("?")x(@values)) .') RETURNING id';
	my $id = 0;
	$dbh->begin_work;
	try {
		$id = $dbh->selectrow_array($sql,{}, @values);
		if ( $id ) {
			$dbh->do('INSERT INTO person_organisation (person_id, organisation_id) VALUES (?, ?)',{},$id,$$info{organisation_id}) or die $dbh->errstr;
		}
		$dbh->commit;
	} catch {
		print STDERR "$_\n";
		$id = 0;
		$dbh->rollback;
	};
	return $id;
}

sub update {
    my ( $self, $info ) = @_;
	my @fields = keys %$info;
	my @values = @{$info}{@fields};
	my @holders = map("$_ = ?", @fields);
	my $sql = 'UPDATE person SET '. join(',', @holders) .' WHERE id = ?';
	$dbh->do($sql,{}, @values, $$self{id}) or die $dbh->errstr;
	$self->by_id($$self{id});
}

# returns undef if not found
sub by_id {
	my ($self, $id) = @_;
	%$self = ();
	my $rcd = $self->row_hashref("SELECT $query_fields FROM person_info WHERE id = ?",$id);
	@{$self}{keys %$rcd} = values %$rcd; # if id has not been found, this line will not be executed, old value holds.
	$$self{title} = $full_title{$$self{title}} if exists($$self{title});
	return $rcd;
}

# returns a better full version tittle
sub pretty_title {
	my ($ititle) = @_;
	if (exists($full_title{$ititle}) && $ititle) {
		return $full_title{$ititle};
	} else {
		return $ititle;
	}
}

sub username2id {
	my ($self, $username) = @_;
	return $self->row_value('SELECT id FROM person WHERE username = ?', $username);
}

# two argument form is used for verifying if it has been used
# three argument form is used for resetting password of an active user when email has been given
sub email2id {
	my ($self, $email, $contact) = @_;
	if ($contact) {
		my $info = $self->row_hashref('SELECT id, title, family_name, given_name, username FROM person WHERE is_active = TRUE AND email = ?',$email);
		$$info{title} = $full_title{$$info{title}} if exists($$info{title});		
		return $info;
	} else {
		return $self->row_value('SELECT id FROM person WHERE email = ?', $email);
	}
}

# password is hashed by sha256_hex( $password . $self->salt ) and saved in $self->hash();
# only active account will be checked
sub validate {
	my ($self, $username, $pwd) = @_;
	%$self = ();
	my $salt = $self->row_value("SELECT salt FROM person WHERE username = ?",$username);;
	return 0 unless $salt;

	# my $hashed_pwd = Digest::SHA::sha256_hex($pwd . $salt);
	my $hashed_pwd = hash_password($pwd , $salt);
	return $self->row_value("SELECT id FROM person WHERE is_active = TRUE AND username = ? AND hash = ?",($username, $hashed_pwd));
}

# creates a hash with "password + salt" with sha256
sub hash_password {
    my ( $pwd, $salt ) = @_;
    return Digest::SHA::sha256_hex($pwd . $salt) ;
}

sub salt {
    my $length = 32;
    return join "", ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ map { rand 64 } ( 1 .. $length ) ];
}

# attributes of a logged in Person
sub user {
	my ($self) = @_;
	return unless $$self{id};
	return $$self{title}  . " " . $$self{given_name} . " " . $$self{family_name};
}

sub yet_confirmed {
    my ( $self, $email ) = @_;
    return $self->row_value("SELECT id FROM person WHERE email = ? AND has_validated_email = 'false'", $email);
}

sub confirm_email {
    my ( $self, $id ) = @_;
	$dbh->do("UPDATE person SET has_validated_email = 'true' WHERE id = ?",{}, $id) or die $dbh->errstr;
	return $self->row_hashref('SELECT username, family_name, given_name FROM person WHERE id = ?',$id);
}

# Creates a 32 character long random string as an unique token to facilitate indentification of a password reset request.
# This is sent back to user by email and will be used to validate when the new password is set.
sub ini_reset_password {
    my ($self, $id) = @_;
    my $token = salt(); # Collision could happens as this salt method is too simple.
	$dbh->do('INSERT INTO resetpwd_token (token, person_id) VALUES (?,?)', {}, $token, $id) or die $dbh->errstr;
	return $token;
}

# retrieves token if it is less then 48hours old, uses postgres interval
sub resetpwdtoken2id {
    my ( $self, $token ) = @_;
    my $statement = "SELECT person_id FROM resetpwd_token WHERE token = ? AND used = 'f' AND now() - date_added < interval '48h'";
    return $self->row_value( $statement, $token );
}

sub reset_password {
	my ($self, $id, $new_pwd, $token) = @_;
	my $salt_pinch = salt();
	my $hashed_pwd = hash_password($new_pwd, $salt_pinch);
	$dbh->begin_work;
	try {
		$dbh->do('UPDATE person SET salt=?,hash=? WHERE id = ?',{}, $salt_pinch, $hashed_pwd, $id) or die $dbh->errstr;
		# Update token
		$dbh->do('UPDATE resetpwd_token SET used=true WHERE token = ?',{}, $token) or die $dbh->errstr;
		$dbh->commit;
	} catch {
		print STDERR "$_\n";
		$dbh->rollback;
	};
}

sub is_active {
	my ($self) = @_;
	return unless $$self{id};
	return $self->row_value('SELECT is_active FROM person WHERE id = ?', $$self{id});
}

sub is_authorized {
	my ($self) = @_;
	return unless $$self{id};
	return $self->row_value('SELECT is_authorized FROM person WHERE id = ?', $$self{id});
}

sub pretty_all_titles {
	my ($arr) = @_;
	if (@$arr > 0) {
		for (@$arr) { $$_{title} = pretty_title($$_{title}); }
	}
	return $arr;
}

# Affiliation section
sub organisations {
	my ($self) = @_;
	require GDACAP::DB::Organisation;
	return $self->array_hashref("SELECT $GDACAP::DB::Organisation::brief_fields FROM organisation,person_organisation WHERE id = organisation_id AND person_id = ?", $$self{id});
}

sub organisations_can_join {
	my ($self) = @_;
	require GDACAP::DB::Organisation;
	return $self->array_hashref("SELECT $GDACAP::DB::Organisation::brief_fields FROM organisation,person_organisation WHERE id != organisation_id AND person_id = ?", ,$$self{id});
}

sub affiliate {
	my ($self, $organisation_id) = @_;
	require GDACAP::DB::Organisation;
	$dbh->do("INSERT INTO person_organisation VALUES (?,?)", {} ,$$self{id}, $organisation_id) or die $dbh->errstr;
}

sub leave {
	my ($self, $organisation_id) = @_;
	$dbh->do("DELETE FROM person_organisation WHERE person_id = ? AND organisation_id = ?", {}, $$self{id}, $organisation_id) or die $dbh->errstr;
}
# End of affiliation section

# Collection of records
sub active {	
	my $self = shift;
	return pretty_all_titles($self->array_hashref("SELECT $brief_fields FROM person WHERE is_active = 'true' AND is_authorized = 'true' AND id NOT IN (SELECT person_id FROM administrator)"));
}

sub inactive {	
	my $self = shift;
	return pretty_all_titles($self->array_hashref("SELECT $brief_fields FROM person WHERE is_active = 'false'"));
}

# pending (is_authroized=false) 
sub pending {
	my $self = shift;
	return pretty_all_titles($self->array_hashref("SELECT $brief_fields FROM person WHERE is_authorized = 'false'"));
}

1;

__END__


=head1 NAME

GDACAP::Person - Access to the records define Person(s)

=head1 SYNOPSIS

  # Generally, it is used as following:
  use GDACAP::DB::Person;
  my $p = GDACAP::DB::Person->new();
  
  @normal = @{ $p->normal() }; 
  @inactive = @{ $p->inactive() }; 
  @pending = @{ $p->pending() }; 

=head1 DESCRIPTION

C<GDACAP::Person> provides an interface of query to B<Person>. Read-only. Persons are in three categories: B<normal>, B<pending> and B<inactive>.

The return valus always are expected to be a collection in hash format -- list even there might be just one record. They can return empty list. It needs DBI not GDACAP::DBA. Also this is a query worker modules, no data is associated with it. DBI is prepared by GDACAP::Resource with code like this:

  use GDACAP::Resource ();
  GDACAP::Resource->prepare('../lib/GDACAP/config.conf');

=head1 titles

Currently the below titles are supported:
 # returns hash of titles
 our %full_title = (
	dr   => 'Dr',
	mr   => 'Mr',
	ms   => 'Ms',
	mrs  => 'Mrs.',
	miss => 'Miss',
	prof => 'Prof',
 );

The keys of hash are used in database and the values are used for presentation. In the database, title can have maximal of four letters.

=head1 METHODS

Default field set returned to caller is: id title given_name family_name username email phone anzsrc_for_code webpage

=over 4

=item * by_id Loads personal information according to person.id

=item * username2id Returns person.id with the given username

=item * validate Validates username and password. Only active account will be checked

=item * email2id Returns person.id with the given email address
When the second argument is set to be ture, title, username and names are returned too.

=item * user Returns a string constructed with title first and family names

=item * generate_hash Generates a hash with "password + salt" with sha256

=item * salt Generates a random string 32 letters long for encrypting password

=back

=head2 Methods for Resetting password

Table resetpwd_token holds tokens to link a reset password request with a user. The token is simply a 32 character long
random string used as a identifier for this password resetting action. A token is valid for 48 hours since
the issue. These functions are used in C<GDACAP::Web::Command>.

=over 4

=item * ini_reset_password Generates a toke valid for the next 48 hours, returns the token.

=item * resetpwdtoken2id Validates token. If the token exists and has not expired, returns person_id.

=item * reset_password Generates a salt and hash the password, then save them. Sets C<used> field of the token to true in the table.
 
=back
  
=head1 AUTHOR

Jianfeng Li

=head1 COPYRIGHT

GDACAP package and its modules are copyrighted under the GPL, Version 3.0.

=cut
