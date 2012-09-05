$include_path GDACAP::Web::Mail;

use strict;
use warnings;

use MIME::Lite::TT::HTML;

my $include_path = $$GDACAP::Web::folders{template};

my $mail_settings = GDACAP::Resource::get_section('mail');
my $sender = $$mail_settings{sender};
my $mail_server = $$mail_settings{sever};

sub change_email_notice {
    my ( $person, $old_email ) = @_;
	my %params = ( person => $person, old_email => $old_email);
    my $msg = MIME::Lite::TT::HTML->new(
        From     => $sender,
        To       => $old_email,
        Subject  => 'Information: email changed',
        Template => {
            text => 'mail_email_changed_plain.tt2',
            html => 'mail_email_changed_html.tt2',
        },
        TmplOptions => {INCLUDE_PATH => $include_path},
        TmplParams  => \%params,
    );
    $msg->send( 'smtp', $mail_server, Debug => 1 );
}

1;

__END__

=head1 NAME

GDACAP::Web::Mail - Mail service

=head1 DESCRIPTION

The module uses MIME::Lite::TT::HTML to support templates to generate emails to communicate users. 

=head1 Attributes

=head2 include_path

include_path is the folder where the template for the mails exists.

=head2 plain

plain is the default plain message template when creating the email.

=head2 C<html>

C<html> is the default HTML message template when creating the email.

=head2 from

from is the default sender to the email, default is noreply@adelaide.edu.au.

=head2 to

to is the default receiver of the email message, default is somebody@adelaide.edu.au, this should be overwritten in the subroutine.

=head2 subject

subject is the default subject of the email message, default is 'Change password?'.

=head2 mail_server

mail_server is the default mail server used to send the email, default is 'smtp.adelaide.edu.au'.

=head1 METHODS

=cut

=head2 send_confirm_email

send_confirm_email sends an email to the person asking her/him to confirm his email address.
 The person will get an email with a link to confirm his email with address: 
 http://HOSTNAME/ands/confirm_email/?email=EMAILADDRESS

=head3 Parameters

=over

=item 1

$person : the person to send the email to, an ANDS::Model::Person object

=item 2

$link : the link to the system in where the person can confirm her/his email

=back

=head2 send_forgot_password_email

send_forgot_password_email sends an email to the person for her/him to be able to reset her/his password(s). The email will contain a link(s) in where she/he can reset her/his password(s). If in the system an email has several accounts associated to it, a link for each account is sent.

=head3 Parameters

=over

=item 1

$person_ref : ANDS::Model::Person objects in an array reference.

=item 2

$link_ref : confirmation links in an array reference (links to the system in where the person can confirm her/his email).

=back

=head2 send_email_changed_email

send_email_changed_email is a subroutine that will send an email to a person if their email has changed. This to ensure that the user are aware of that she/he changed her/his email.

=head3 Parameters

=over

=item 1

$person : person that changed her/his email, an ANDS::Model::Person object.

=item 2

$old_email : the old email for the person.

=back

=head2 send_is_authorized_changed_email

send_is_authorized_changed_email sends an email telling the user that her/his authorization to the system has changed.

=head3 Parameters

=over

=item 1

$person : an ANDS::Model::Person object that contain the current person object.

=item 2

$old_person : an ANDS::Model::Person object that contain the old person object.

=back

=head2 send_person_validated_email

send_person_validated_email sends an email telling the administrator that a user has validated her/his email. This subroutine is called once for each administrator so all administrators know when a user has validated his email. This to inform the administrator that the user is waiting for access to the system.

=head3 Parameters

=over

=item 1

$person_administrator : an ANDS::Model::Person object that contains the administrator.

=item 2

$person_validated : an ANDS::Model::Person object that contains the person who validated.

=back

=head1 AUTHOR

©2011-2012 Andor Lundgren and The University of Adelaide

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut
