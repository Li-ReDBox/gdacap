package GDACAP::Web::Person;

use strict;
use warnings;

require GDACAP::DB::Anzsrc4;
require GDACAP::Mail;

my ($action, $logger, $person_id);
my %known_action = map {$_ => 1} qw(list create edit update);

sub handler {
	my $r;
	($r, $action, $person_id) = @_;

	$logger = $GDACAP::Web::logger;

	$action = 'list' unless $action;
	if (exists($known_action{$action})) {
		# $logger->trace("Above action has been defined") if defined(&$action);
		no strict 'refs';
        &{$action}($r, $person_id);
    } else { 
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub list {
	my ($r) = @_;
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->is_sys_admin()) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	
	my $people = GDACAP::DB::Person->new();
    my $function_vars = { template_name => 'person_management' };
	my $template_vars = {
        header             => 'Person management',
        section_article_id => 'Personmanagement',
		create_new         => $GDACAP::Web::location.'/person/create/',
        administrators     => $role->administrative(),
        active             => $people->active(),
        pending            => $people->pending(),
        inactive           => $people->inactive(),
        edit_user_link     => $GDACAP::Web::location.'/person/edit',
    };
	GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
}

sub create {
    my ( $r ) = @_;
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->is_sys_admin()) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	require GDACAP::DB::Person;
    my $req = Apache2::Request->new($r);
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Person::creation, \@GDACAP::DB::Person::creation_optional, $req);
	my $msg = $$validated_form{msg}; 
	my %person = %{$$validated_form{content}};
	if ($msg eq '1') {	
		# All filled in
		my $person_rcd = GDACAP::DB::Person->new();
		# # check if username is vacant
		if ($person_rcd->username2id($person{username})) {
			$msg = "Error: username is already in use.";
		} elsif ($person_rcd->email2id($person{email}) ) {
			$msg = "Error: email is already in use.";
		} else {
			my $new_id = $person_rcd->create(\%person);
			if ($new_id) {
				$msg = "A new account has been created. If you want it is enabled, go to managing page to do it.";
			} else {
				$msg = "The registration failed. If the information you filled in are correct, please send them to the administrator.";
			}
		}
	}

	my $anzsrc = GDACAP::DB::Anzsrc4->new();
	require GDACAP::DB::Organisation;
	my $org = GDACAP::DB::Organisation->new();
	
	my $function_vars = { template_name => 'person_register' };
	my $template_vars = {
		header          => 'User registration',
		section_article_id => 'Selfregister',
		self_mode       => '',
		action          => $GDACAP::Web::location.'/person/create/',
		anzsrc_url      => $GDACAP::Web::location.'/command/anzsrc/',
		anzsrcs         => $anzsrc->get_all(),
		help_url        => $GDACAP::Web::location.'/commad/help/?id=self_register',            
		message         => $msg,
		organisations   => $org->name_list(),
		person          => \%person,
		titles          => \%GDACAP::DB::Person::full_title,
	};
	GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
}

sub edit {
    my ( $r ) = @_;
	my $method = $r->method();
	if ($method ne 'POST') {
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not make up request.');
		return;
	}
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->is_sys_admin()) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	undef $role;
	my $msg = '';
	my $req = Apache2::Request->new($r);
    my $account_id = $req->param("person_id");    
	
	my $person_rcd = GDACAP::DB::Person->new();
	$person_rcd->by_id($account_id);
	my $account_role = GDACAP::DB::Personrole->new($account_id);

    my $section = $req->param("section");      # person_info, affiliation or personrole
	if (defined($section)) { # information has been set
		my $command = $req->param("command");      # command could be either add, remove or person_info
		if ($section eq 'person_info') {
			$msg = edit_personal_info($person_rcd, $req, 1);
		} elsif ($section eq 'affiliation') {
			my $organisation_id = $req->param("organisation_id");
			if ($command eq 'add')  {
					$person_rcd->affiliate($organisation_id);
			} elsif ($command eq 'remove') {
					$person_rcd->leave($organisation_id);
			}
			$msg = 'Affiliation has been changed';
		} elsif ($section eq 'project_role') {
			my $project_id   = $req->param("project_id");
			my $role_type_id = $req->param("role_type_id");
			if ($command eq 'add') {
				$account_role->assign($project_id,$role_type_id);
			} elsif ('remove') {
				$account_role->remove($project_id, $role_type_id);
			}
			$msg = 'Role has been changed.';
		}
	}
	
    my $projects = $account_role->projects_not_in();
	$projects = {} unless $projects;
    my $personroles = $account_role->projects_role();
	$personroles = {} unless $personroles;
	
	
	my $anzsrc = GDACAP::DB::Anzsrc4->new();

	my $organisations = $person_rcd->organisations_can_join();
	$organisations = {} unless $organisations;

	my $function_vars = { template_name => 'person_edit' };
	my $template_vars = {
		header             => 'Edit personal account',
		section_article_id => 'user_edit',
        action             => $GDACAP::Web::location.'/person/edit',
		anzsrc_url         => $GDACAP::Web::location.'/command/anzsrc/',
		anzsrcs            => $anzsrc->get_all(),
		organisations      => $organisations,
        roletypes          => $account_role->types(),
		titles             => \%GDACAP::DB::Person::full_title,
        edit_user_link     => $GDACAP::Web::location.'/person/edit',
        goto_project_link  => $GDACAP::Web::location.'/project',
		help_url           => $GDACAP::Web::location.'/commad/help/?id=person_edit_admin',            
        person             => $person_rcd->values(),
        affiliations       => $person_rcd->organisations(),
        projects           => $projects,
        personroles        => $personroles,
		message            => $msg,
	};
	GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
}

# User updates profile
sub update {
    my ( $r ) = @_;
	
	my $req = Apache2::Request->new($r);
    my $command   = $req->param("command");      # command could be either add_personorganisation, remove_personorganisation
	
	my $person_rcd = GDACAP::DB::Person->new();
	$person_rcd->by_id($person_id);

	my $anzsrc = GDACAP::DB::Anzsrc4->new();

	my $organisations = $person_rcd->organisations_can_join();
	$organisations = {} unless $organisations;
	my $msg = edit_personal_info($person_rcd, $req);
	my $function_vars = { template_name => 'person_update' };
	my $template_vars = {
		header             => 'Edit profile',
		section_article_id => 'person_update',
        action             => $GDACAP::Web::location.'/person/update',
		anzsrc_url         => $GDACAP::Web::location.'/command/anzsrc/',
		anzsrcs            => $anzsrc->get_all(),
		organisations      => $organisations,
		titles             => \%GDACAP::DB::Person::full_title,
		help_url           => $GDACAP::Web::location.'/commad/help/?id=person_update',            
        person             => $person_rcd->values(),
        affiliations       => $person_rcd->organisations(),
		message            => $msg,
	};
	GDACAP::Web::Page::display($r, $function_vars, $template_vars, $person_id);
}

# used by either a user or sysadmin.
# sysadmin can access states fields of a user
sub edit_personal_info{
	my ($person_rcd, $req, $sysadmin) = @_;
	my @mandatory = qw(title given_name family_name email phone anzsrc_for_code);
	my @booleans = qw(has_validated_email is_authorized is_active) if $sysadmin;
	my @optional = qw(webpage);
	my $validated_form = GDACAP::Web::validate_form(\@mandatory, \@optional, $req, \@booleans);
	my $msg = $$validated_form{msg};
		
	my $person = $$validated_form{content};
	use Data::Dumper;
	$logger->debug("update userinfor with these informaion:\n",Dumper($person));
	my $old_email = $$person_rcd{email};
	my $is_authorized = $$person_rcd{is_authorized};
	if ($msg eq '1') {	
		# All filled in
		if ($person_rcd->email2id($$person{email}) && $$person{email} ne $person_rcd->email()) {
			$msg = "Error: email is already in use.";
		} else {
			my $rv = $person_rcd->update($person);
			if ($rv) {
				$msg = "Update was successful.";
				# if email has changed an email should be sent to that person about the email change.
				if ( $old_email ne $$person{email} ) {
					# send an email to changed persons email about the email change
					GDACAP::Mail::change_email( {title => $$person_rcd{title}, 
					            given_name => $$person_rcd{given_name}, family_name => $$person_rcd{family_name}, 
								email => $$person_rcd{email}}, $old_email );
					$msg .= " An email has been sent to " . $person_rcd->user() . " to the new email address.";
				}
				if ( $is_authorized != $$person{is_authorized} ) {
					GDACAP::Mail::change_authorisation( {title => $$person_rcd{title}, 
							given_name => $$person_rcd{given_name}, family_name => $$person_rcd{family_name}, 
							email => $$person_rcd{email}}, $$person{is_authorized} );
					$msg .= " An email has been sent to the user to inform the authorisation change.";
				}
			} else {
				$msg = "Update was failed.";
			}
		}
	}
	return $msg;	
}

1;

__END__

=head1 NAME

GDACAP::Web::Person - Person management 

=head1 SYNOPSIS


=head1 DESCRIPTION

This can be accessed by a logged in person or system administrators. Person status like active etc. is managed here.

=head1 METHODS

=head2 create Create an account by a system administrator

=head2 edit Edit personal information, managing person status and project roles by a system administrator

=head2 update Update personal information by a logged in person

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
