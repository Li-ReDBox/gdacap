package GDACAP::Web::Command;

use strict;
use warnings;

use Apache2::Request;
use JSON;
use Try::Tiny;
require GDACAP::Mail;

my ($action, $logger);
my %known_action = map {$_ => 1} qw(login logout register anzsrc tax_id tax_info help confirm_email forgot_password reset_password);

sub handler {
	my $r;
	($r, $action) = @_;
	$logger = $GDACAP::Web::logger;
	if (exists($known_action{$action})) {
		# $logger->trace("Above action has been defined") if defined(&$action);
		no strict 'refs';
        &{$action}($r);
    } else {
		$logger->warn("Unknown action was given: $action.");
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub login {
    my ( $r ) = @_;
	# $logger->debug('login in Command was called');
	my $req = Apache2::Request->new($r);
    my $username = $req->param("username");
    my $password = $req->param("password");

    my $person_id = '';
    my $msg = '';

    if ( defined $username && defined $password && $username ne '' && $password ne '' ) {
        my $p_login = GDACAP::DB::Person->new();
		my $id = $p_login->validate($username, $password);
		# $logger->debug("Validated result: $id.");
        if ( $id ) {
            # a person with that username exist;
			my $prcd = $p_login->by_id($id);
			my $user = $p_login->user();
			# $logger->debug("User name: $user.");
            # is person active or deleted (deactivated)?
			# if ( $p_login->is_authorized() ) {
				# $logger->debug("User is authorized.");
                # person is active
                # is person authenticated as a valid user yet?
				# if ( $p_login->is_active() ) {
					# $logger->debug("User is active.");
                    # person is authorized
					$person_id = $id;
					try {
						# $logger->debug("Try to create a session person_id = $person_id");
						GDACAP::Web::Session::login($r, $person_id);
					} catch {
						$logger->debug("Session cannot be created. $_");
					};
					$msg = "Welcome back $user.";
                # } else {
					# # person is deactivated
					# $msg = "You have been deactivated $user.";
                # }
            # } else {
				# # person is not yet authorized
				# $msg = "You have not yet been authorised $user.";
            # }
        } else {
            # wrong username
            $msg = "Invalid username or password.";
        }
    }

    if ($person_id) {
    # load loggedin template
		my $function_vars = { template_name  => 'loggedin' };
		my $template_vars = {
			action => $GDACAP::Web::location.'/command/logout',
			section_article_id	=> 'Login',
			header   => 'Login',
			message  => $msg,
		};
		GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
    } else {
		show_login($r, $msg);
    }
}

sub logout {
    my ( $r ) = @_;
    # logout: clear server session, expires client cookie
	GDACAP::Web::Session::logout($r);
	show_login($r, '');
}

sub show_login {
	my ($r, $msg, $person_id) = @_;
    my $function_vars = { template_name => 'login' };
	my $template_vars = {
		section_article_id	=> 'Login',
		header   => 'Login',
		message  => $msg,
		action   => $GDACAP::Web::location.'/command/login',
		forgot_password_url => $GDACAP::Web::location.'/command/forgot_password',
		self_register_url => $GDACAP::Web::location.'/command/register',
		help_url => $GDACAP::Web::location.'/command/help/?id=login',
    };
    GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
}

sub register {
    my ( $r ) = @_;
	require GDACAP::DB::Person;
    my $req = Apache2::Request->new($r);
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Person::creation, \@GDACAP::DB::Person::creation_optional, $req);
	my $msg = $$validated_form{msg};
	# $person is raw data from web form.
	# $person_rcd is a GDACAP::DB::Person object, used here only for query.
	my $person = $$validated_form{content};
	if ($msg eq '1') {
		# All filled in
		my $person_rcd = GDACAP::DB::Person->new();
		# # check if username is vacant
		if ($person_rcd->username2id($$person{username})) {
			$msg = "Error: username is already in use.";
		} elsif ($person_rcd->email2id($$person{email}) ) {
			$msg = "Error: email is already in use.";
		} else {
			my $new_id = $person_rcd->create($person);
			if ($new_id) {
				$msg = "Your registration application has been lodged and an email has been sent to your email address. Please check your email and confirm your email address.";
				# send email to person to confirm email address
				my $link = 'http://'.$r->hostname().$GDACAP::Web::location.'/command/confirm_email/?email='.$$person{email};
				GDACAP::Mail::confirm_email_address( $person, $link );
			} else {
				$msg = "The registration failed. If the information you filled in are correct, please send them to the administrator.";
			}
		}
	}
	require GDACAP::DB::Anzsrc4;
	my $anzsrc = GDACAP::DB::Anzsrc4->new();
	require GDACAP::DB::Organisation;
	my $org = GDACAP::DB::Organisation->new();

	my $function_vars = { template_name => 'person_register', skip_menu => 1 };
	my $template_vars = {
		header          => 'User registration',
		section_article_id => 'Selfregister',
		self_mode       => 'true',
		action          => $GDACAP::Web::location.'/command/register/',
		anzsrc_url      => $GDACAP::Web::location.'/command/get_anzsrc/',
		anzsrcs         => $anzsrc->get_all(),
		help_url        => $GDACAP::Web::location.'/command/help/?id=self_register',
		message         => $msg,
		organisations   => $org->name_list(),
		person          => $person,
		titles          => \%GDACAP::DB::Person::full_title,
	};
	GDACAP::Web::Page::display($r, $function_vars, $template_vars, 0);
}

sub confirm_email {
    my ( $r ) = @_;
    my $req = Apache2::Request->new($r);
    my $email  = $req->param("email");
    my ( $msg, $error, $email_validated );
    if ( $email ) {
		my $person_rcd = GDACAP::DB::Person->new();
		my $id = $person_rcd->yet_confirmed($email);
		$logger->debug("confirm_email returned id = $id, email = ",$email);
		if ( $id ) {
			my $user = $person_rcd->confirm_email($id);
			$person_rcd->by_id($id);
			$msg = "The email address has been validated. A system administrator will process your application and get you soon.";
			# send email to all administrators (not super administrators) that one has validated
			my $role = GDACAP::DB::Personrole->new();
			my $administrators = $role->administrative('email');
			my @emails = ();
			foreach (@$administrators) { push(@emails, $$_{email}); }
			GDACAP::Mail::request_authorisation( join(',', @emails), $user );
		} else {
				$msg = "The request is invalid."; # cannot find record: either done or does not exist
		}
		GDACAP::Web::Page::show_msg($r, 'Confirmation of email address', $msg);
    } else {
        GDACAP::Web::Page::show_msg($r, 'Bad request', 'Service cannot be provided.');
    }
}

# When user forgot password - just copied
sub forgot_password {
    my ( $r ) = @_;

	my $function_vars = { template_name => 'message' }; # default template
	my $template_vars = {
		section_article_id => 'message',
		header  => 'Forgot password',
		message => 'We will send you a link to allow you to reset your password.',
	};

    my $req = Apache2::Request->new($r);
    my $email = $req->param("email");
    if ( $email ) {
		my $person_rcd = GDACAP::DB::Person->new();
		# check if eamil is valid
		my $person = $person_rcd->email2id($email,1);
		if (%$person) {
			my $token = $person_rcd->ini_reset_password($$person{id});
			$$person{email} = $email;
			GDACAP::Mail::reset_password($person, 'http://'.$r->hostname().$GDACAP::Web::location.'/command/reset_password/?token='.$token);
            $$template_vars{message} = "Instruction for resetting your password has been sent to $email.";
			$logger->info("$$person{username} (id = $$person{id}) required to reset password");
		} else {
			$$template_vars{message} = "The request cannot be processed. Is $email correct? Is your account active? If you believe there was something wrong, please contact Administrator.";
		}
    } else {    # If mail been sent, just show a message
		$$function_vars{template_name} = 'forgot_password';
		$$template_vars{section_article_id} = 'forgot_password',
		$$template_vars{action} = $GDACAP::Web::location.'/command/forgot_password',
    }
	GDACAP::Web::Page::display($r, $function_vars, $template_vars);
}

# The interface for user to change password after they have forgotten -- just copied
sub reset_password {
    my ( $r ) = @_;

    my $req = Apache2::Request->new($r);
    my $token = $req->param("token"); #token from link
	unless ($token) {
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
		return;
	}

	my $function_vars = { template_name => 'message' };
	my $template_vars = {
		section_article_id => 'message',
		header => 'Reset password',
	};
	my $person_rcd = GDACAP::DB::Person->new();
	# check if token is still valid
	my $person_id = $person_rcd->resetpwdtoken2id( $token );
	if ($person_id) {
		my $new_password = $req->param('new_password');
		if ($new_password) {
			$person_rcd->reset_password($person_id, $new_password, $token);
			$$template_vars{message} = 'Password has been reset successfully.';
			$logger->info("Person(id = $person_id) has reset password successfully.");
		} else {
			$$function_vars{template_name} = 'reset_password';
			$$template_vars{section_article_id} = 'reset_password';
			$$template_vars{action} = $GDACAP::Web::location.'/command/reset_password/';
			$$template_vars{token}  = $token;
		}
	} else {
		$$template_vars{message} = 'Invalid token provided. You might have to apply a new one - a token is valid for 48 hours.';
	}
	GDACAP::Web::Page::display($r, $function_vars, $template_vars);
}

sub help {
    my ( $r ) = @_;

    my $req = Apache2::Request->new($r);
    my $id  = $req->param("id");
    $id = 'index' unless $id;
    my $function_vars = { template_name => 'help',  skip_menu => 1 };
	my $template_vars = {
		section_article_id	=> 'Help',
		header => 'Help',
		helpId => $id,
		path   => $GDACAP::Web::location.'/images/help/',
    };
    GDACAP::Web::Page::display($r, $function_vars, $template_vars);
}

# GET only services
sub anzsrc {
    my ( $r ) = @_;
    my $req = Apache2::Request->new($r);
    my $cond = $req->param("search_all");
    my $max_rows = $req->param("max_rows");

	require GDACAP::DB::Anzsrc4;
    my $anzsrc4 = GDACAP::DB::Anzsrc4->new();
    my $rt = $anzsrc4->by_code_or_name( $cond, $max_rows );
    # # encode a hash or array method with JSON
    $r->content_type('application/json');
    print encode_json({"anzsrcs" => $rt});
}

sub tax_id {
    my ( $r ) = @_;
    my $req = Apache2::Request->new($r);
    my $cond = $req->param("search_all");
    my $max_rows   = $req->param("max_rows");

	require GDACAP::DB::NCBITax;
    my $anzsrc4 = GDACAP::DB::NCBITax->new();
    my $rt = $anzsrc4->by_id_or_name( $cond, $max_rows );
    $r->content_type('application/json');
    print encode_json({"taxnames" => $rt});
}

sub tax_info {
    my ( $r ) = @_;
    my $req = Apache2::Request->new($r);
    my $tax_id = $req->param("tax_id");

	require GDACAP::DB::NCBITax;
    my $anzsrc4 = GDACAP::DB::NCBITax->new();
    my $rt = $anzsrc4->by_id( $tax_id );
    $r->content_type('application/json');
    print encode_json({"taxnames" => $rt});
}

1;

__END__

=head1 NAME

GDACAP::Web::Command - Commands for none login use

=head1 SYNOPSIS


=head1 DESCRIPTION

Most out layer functions

=head1 METHODS

=head2 Methods for Resetting password

To reset user's password, user has to fill in registered email address. Only after it has been varified,
an email will be sent with a link to lead user to reset password. User has to act within 48 hours of request.
With correct information, new salt and hashed password are saved.

=over 4

=item * forgot_password(Apache2::Request)

Displays a page to allow an active user to fill in the registered email address to receive a link for resetting password. Inactive (banned) user cannot reset password.

=item * reset_password(Apache2::Request)

Processes a reset password request. It only proceeds when a valid token presents. Otherwise, it complains. 

=back

=head2 anzsrc(Apache2::Request)

Returns a JSON object which contains all ANZSRCS-FOR code and name pairs that match a given search term on the ANZSRCS name and code

The search term is posted in the variable search_all and used to query name and code in the database table through the module C<GDACAP::DB::Anzsrcs4>.

Request parameters controls results by these terms:
  search_all  - the search term
  max_rows    - max number of results returned in the JSON

=head2 tax_id(Apache2::Request)

Returns a JSON object contains information of matched tax_id or name part for user to select a tax_id.

Request parameters controls results by these terms:
  search_all  - the search term
  max_rows    - max number of results returned in the JSON

=head2 tax_info(Apache2::Request)

Returns a JSON object contains information of a tax_id for user to verify

Request parameters controls results by these terms:
  tax_id  - the search term

=head1 AUTHORS

Andor Lundgren

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
