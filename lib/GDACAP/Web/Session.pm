package GDACAP::Web::Session;

use strict;
use warnings;

use Apache::Session::File;
use Apache2::Cookie;

my $cookie_name = 'groo'; # Not a meaningful name
my $expires = '+1h';
my $secure = 1;
my $session_dir;

sub login {
    my ( $r, $person_id ) = @_;
	my $new_session = create_session();           # create new session with person_id
	Carp::carp("Code should have died before. Otherwise it is a faulty design.") unless exists($new_session->{_session_id});
	$$new_session{person_id} = $person_id;  
	session_cookie($r, $new_session->{_session_id} );     # store new session in user cookie
}

# Check if the current apache request associates a valid session with person_id in it
sub logged_in {
    my ( $r ) = @_;
    my $cookie = session_cookie( $r );
    if ($cookie) {
        my $session_hash_ref = get_session( $cookie->value() );
		return undef unless $session_hash_ref;
        # examine if it has a person_id in it (should have it if it was created by this program)
        if ( exists $session_hash_ref->{person_id} ) {
            # session with person_id exists, extract person_id, remove old session, add new with person id and save that to user browser cookie;
            my $person_id = $session_hash_ref->{person_id};    # extract person_id
            tied(%$session_hash_ref)->delete;          # remove old session
			login($r, $person_id);
            return $person_id;
        } 
    }
    return undef;
}

# If user clicked logout, clear cookie and remove session
sub logout {
    my ( $r ) = @_;
    my $cookie = session_cookie( $r );
    if ($cookie) {
		my $session_hash_ref = get_session( $cookie->value() );
        tied(%$session_hash_ref)->delete if $session_hash_ref;          # remove old session
        # remove session id from our cookie
        session_cookie( $r, '-' );
    }
}

# Read from conf settings
sub read_settings {
	my $section = GDACAP::Resource::get_section('session');
	$session_dir = $$section{session};
	$secure = $$section{has_http_only};
}

# Get or set a session cookie with session_id as the value
sub session_cookie {
    my ( $r, $session_id ) = @_;
	unless ($session_id) {
		my $jar = Apache2::Cookie::Jar->new($r);
		return $jar->cookies($cookie_name);
	}
	my $c_out;
	if ($session_id eq '-') { # clean cookie value and expires now
		$c_out = Apache2::Cookie->new( $r, name => $cookie_name, path => $GDACAP::Web::location, secure => $secure, value => '',	expires => 0 );
	} elsif ($session_id) {
		$c_out = Apache2::Cookie->new( $r, name => $cookie_name, path => $GDACAP::Web::location, secure => $secure, value => $session_id, expires => $expires );
	}
	$c_out->bake($r);
}

# Utility function used internally 
# return existing session hash ref if found or undef
sub get_session {
    my ( $session_id ) = @_;
	Carp::carp("Session id was not given, check code.") unless $session_id;
	read_settings() unless $session_dir;
    my %session;
    eval {
        tie %session, 'Apache::Session::File', $session_id, { Directory => $session_dir, };
    };
	if ($@) {
		# Carp::cluck("Did not get session id=$session_id. Might not be serious. More: $@");
		return undef ; # Cannot get the given session: expired or invalid
	}	
    return \%session;
}

sub create_session {
    my %session;
	read_settings() unless $session_dir;
    eval { tie %session, 'Apache::Session::File', undef, { Directory => $session_dir }; };
	if ($@) {
		Carp::carp('Failed to create session. More reason: ' . $@ );
	}
    return \%session;
}

1;

__END__

=head1 NAME

GDACAP::Web::Session -- Login session management

=head1 DESCRIPTION

1. Retrieves our cookie 
	read_session($sname, $cookie)
2. Varifies sessoin
2.1. if good returns person_id
2.2. if not redirect
3. Create session with _session_id
4. Clean cookie value to empty when logout

Every request creates a new session no matter if the previous session is valid.

Session is save in a file and stores only the id of logged in person. The cookie only holds session id. It is a root cookie with name of groo and expires in half hour. The secure flag can also be set.

=head1 METHODS

=head2 login

First time connect to the server, sets cookie and session.

=head2 logged_in

Check if the current HTTP request is valid. If yes return the only session variable person_id and replace session and update cookie

=head2 logout 

Deletes the server session and clear cookie

=head1 AUTHORS

Andor Lundgren 

Jianfeng Li

=head1 COPYRIGHT

Copyright (C) 2012  The University of Adelaide

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