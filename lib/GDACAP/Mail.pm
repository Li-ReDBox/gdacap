package GDACAP::Mail;

use strict;
use warnings;

use MIME::Lite;
use Template;
require Carp;

our $WITH_MODPERL = 0; 
my ($template_path, $sender, $server);
my ($msg, $tt);

sub prepare {
	my $mail_settings;
	# try read $mail_settings from $GDACAP::Web::mail_settings, otherwise call GDACAP::Resource::get_section('mail')
	if (exists($INC{'GDACAP/Web.pm'})) {
		$mail_settings = $GDACAP::Web::mail_settings;
	} else {
		$mail_settings = GDACAP::Resource::get_section('mail');
	}
	$template_path = $$mail_settings{template};
	$sender = $$mail_settings{sender};
	$server = $$mail_settings{server};

    $tt = Template->new( INCLUDE_PATH => $template_path, Strict => 1);
    $msg = MIME::Lite->new( From => $sender, Type => 'TEXT' );
}

sub confirm_email_address {
	prepare();
    my ( $person, $confirm_handler  ) = @_;
	my %tmpl_parameters = (person => $person, confirm_handler => $confirm_handler);
	my $message;
    $tt->process( 'confirm_email_address.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", 'Genomics Data Capturer: Confirmation is needed');
	$msg->add("To", $$person{email});
	$msg->data($message);
    $msg->send( 'smtp', $server);
}

sub reset_password {
	prepare();
    my ( $person, $reset_handler  ) = @_;
	my %tmpl_parameters = (person => $person, reset_handler => $reset_handler);
	my $message;
    $tt->process( 'reset_password.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", 'Genomics Data Capturer: Reset password');
	$msg->add("To", $$person{email});
	$msg->data($message);
    $msg->send( 'smtp', $server);
}

# Reminders
sub request_authorisation {
    my ( $administrators, $applicant ) = @_;
	prepare();
	my $message;
	my %tmpl_parameters = (person => $applicant);
    $tt->process('authorisation_request.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", "Genomics Data Capturer: Approval of application request");
	$msg->add("To", $administrators);
	$msg->data($message);
	$msg->send( 'smtp', $server);
	#print $msg->as_string,"\n";
}

# Notifications - no action is needed
sub change_email {
	prepare();
    my ( $person, $old_email ) = @_;
	my %tmpl_parameters = (person => $person, old_email => $old_email);

	my $message;
    $tt->process( 'email_changed.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", 'Genomics Data Capturer: email address has been changed');
	$msg->add("To", $old_email);
	$msg->data($message);
    $msg->send( 'smtp', $server);
}

sub change_authorisation {
	prepare();
    my ( $person, $right ) = @_;
	my %tmpl_parameters = (person => $person, right => $right);

	my $message;
    $tt->process( 'authorisation_changed.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", 'Genomics Data Capturer: Access to the system');
	$msg->add("To", $$person{email});
	$msg->data($message);
    $msg->send( 'smtp', $server);
}

sub notice {
	prepare();
    my ( $person, $event_msg ) = @_;
	my %tmpl_parameters = (person => $person, event_msg => $event_msg);

	my $message;
    $tt->process( 'notice.tt2', \%tmpl_parameters, \$message ) or Carp::croak $tt->error;

	$msg->add("Subject", 'Genomics Data Capturer notification');
	$msg->add("To", $$person{email});
	$msg->data($message);
    $msg->send( 'smtp', $server);
}

1;

__END__

=head1 NAME

GDACAP::Mail - Composes and sends email to user with pre-defined templates

=head1 SYNOPSIS
 
 # Add these two lines only when used stand-alone - read mail settings by itself
 require GDACAP::Resource;
 GDACAP::Resource->prepare('../lib/GDACAP/config.conf',0,1);

 require GDACAP::Mail;
 my %person = (title => 'Dr', 
               given_name => 'John', family_name => 'Smith', 
               email =>'john@old.organisation');
 GDACAP::Mail::change_email(\%person,'john@new.organisation');
 
=head1 DESCRIPTION

The functions in this module use MIME::Lite to send pre-defined emails to communicate with users. The module mainly serves L<GDACAP::Web> but can be used in other settings. In such cases, the module needs to read Section [mail] of a configuration file managed by L<GDACAP::Resource>:

 [mail]
 template = ../resources/templates
 sender = noreply@your.organisation
 server = smtp.your.organisation

To prepare L<GDACAP::Resource> call C<GDACAP::Resource->prepare> before calling any functions in this module to get settings:

 require GDACAP::Resource;
 GDACAP::Resource->prepare('../lib/GDACAP/config.conf',0,1);
 
=head1 FUNCTIONS

=head2 change_email($person, $old_email_address)

Notifies a user the change of email address to ensure the user is aware of it. Used in L<GDACAP::Web::Person>.

$person is a hash reference in the structure of: 

 my %person = (title => 'Dr', given_name => 'John', family_name => 'Smith', email =>'mail@your.organisation');
 
$old_email_address is the previous email address, a scalar.

=head2 confirm_email_address($person, $confirmation_handler)

Sends a link to an applicant's nominated email address for confirming the address after information has been collected. Used in L<GDACaP::Web::Command>.

$person is a hash reference. See the description of C<change_email>.
 
$confirmation_handler is a scalar variable contains a handler link.

=head2 reset_password($person, $reset_handler)

Sends a link to a user to reset the password. Requested by a user. Used in L<GDACAP::Web::Command>

$person is a hash reference. See the description of C<change_email>.
 
$reset_handler is a scalar variable contains a handler link.

=head2 change_authorisation($person, $right)

Notifies a user about the change of accessing to the system. Called when an administrator changed the status - granted or banned. Used in L<GDACAP::Web::Person>.

$person is a hash reference. See the description of C<change_email>.
 
$right is a scalar variable can represents a boolean value.

=head2 request_authorisation($administrators, $applicant)

Notifies all administrators after an applicant has confirmed email address to ask someone to approve the application. Used in L<GDACAP::Web::Command>

$administrators is an array reference contains email addresses of administrators.

$applicant is a hash reference with keys and values of famil_name and given_name.

=head2 notice($person, $event_message)

Notifies a user when an event needs attention. 

$person is a hash reference. See the description of C<change_email>.
 
$event_message is a scalar variable of the message to the user.

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

=head1 SEE ALSO

L<GDACAP::Resource>, L<MIME::Lite>

=cut
