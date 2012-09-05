package GDACAP::Web;

use warnings;
use strict;

use Apache2::RequestRec();    
use Apache2::Request ();
use Apache2::Const -compile => qw(OK REDIRECT NOT_FOUND);

use Try::Tiny;

require GDACAP::Web::Session;
require GDACAP::Web::Page;
require GDACAP::Web::Command;

our ($logger, $folders, $location, $mail_settings);
{ 
	use Apache2::ServerUtil ();
	my $s = Apache2::ServerUtil->server();
	my $config_file = $s->dir_config('GDACAPConfig') || '';
	die "GDACAP Config file isn't set in httpd configuration direcotry" unless $config_file;
	require GDACAP::Resource;
	my $config = GDACAP::Resource->prepare($config_file,1);
	$logger = Log::Log4perl::get_logger();
	# $folders = get_section('folders');
	$folders = $$config{'folders'};
	$mail_settings = $$config{'mail'};
}

# sub dump { use Data::Dumper; use Apache2::RequestIO (); my $r = shift; $r->content_type('text/plain'); $r->print(Dumper($r)); $logger->debug('it has been called'); }

# function call entries
my %implemented = (
    command    => ['GDACAP::Web::Command',    'GDACAP::Web::Command::handler'],
    project    => ['GDACAP::Web::Project',    'GDACAP::Web::Project::handler'],
    study      => ['GDACAP::Web::Study',      'GDACAP::Web::Study::handler'],
    sample     => ['GDACAP::Web::Sample',     'GDACAP::Web::Sample::handler'],
    experiment => ['GDACAP::Web::Experiment', 'GDACAP::Web::Experiment::handler'],
    run        => ['GDACAP::Web::Run',        'GDACAP::Web::Run::handler'],
    process    => ['GDACAP::Web::Process',    'GDACAP::Web::Process::handler'],
    tool       => ['GDACAP::Web::Tool',       'GDACAP::Web::Tool::handler'],
    person     => ['GDACAP::Web::Person',     'GDACAP::Web::Person::handler'],
    # dumper   => ['Data::Dumper', \&dump],
);
# Only logged in users can access
my %restricted = map { $_ => 1 } qw(project study sample experiment run process tool person organisation);

# check if proper command has been given
# in module, use $r->uri for interpreting commands:
# /location/project/edit
# split('/',$uri); shift;shift;
sub validate_command {
	my ($comm) = @_;
	my @parts = split('/',$comm);
	shift(@parts);
	$location = '/'.shift(@parts);
	my $pat = qr/^[a-zA-Z_]+$/;
	my $err = 0;	
	for (@parts) {
		if (not $_ =~ $pat) { $err = 1;	last; }
	}
	return $err ? undef : \@parts;
}

sub handler {
    my $r = shift;    
  
	my $com_parts = validate_command($r->uri);
	# $logger->debug("Command parts (uri) ",@$com_parts);
	if (scalar(@$com_parts)) { # has requests
		# $logger->debug('reconstructed command: ',join('/',@$com_parts));
		my ($asset, $action) = @$com_parts; # only takes the first two parts
		if (!exists($implemented{$asset})) {
			$r->status(Apache2::Const::NOT_FOUND);
			return Apache2::Const::OK;
		}
		if ($restricted{$asset}) { # restrict
			# $logger->debug("A login is needed for $asset");
			## retrieved $person_id has to be saved for later use.
			my $person_id = GDACAP::Web::Session::logged_in($r);
			if ( !$person_id ) {
				# $logger->debug("A login is needed for $asset, but did not yet, redirect to login page.");
				$r->headers_out->set( 'Location' => $location.'/command/login' );
				$r->status(Apache2::Const::REDIRECT);
			} else {
				act($r, $asset, $action, $person_id);
			}
		} else {				# # non-restricted do it 		
			act($r, $asset, $action);
		}
	} else {
		$logger->debug("From Web.pm passing non-asset related action to Command");
		GDACAP::Web::Command::handler($r,'login');
	}
    return Apache2::Const::OK;
}

sub act {
	my ($r, $asset, $action, $person_id) = @_;
	# print STDERR '$asset=', $asset, '$action=', $action,"\n";
	my ($mod, $func) = @{ $implemented{$asset} };
	eval "require $mod";
	if ($@) {
		$logger->debug("Cannot load $mod. $@");
	} else {
		no strict 'refs';
		# try {
			&{$func}($r, $action, $person_id);
		# } catch {
			# $logger->debug("Cannot call function $func: $_");
		# };
	}
}

# (\@mandatory, \@optional, $req, \@booleans);
# \@booleans is an optional argument. Booleans (checkboxes always have values)
sub validate_form {
	my @mandatory = @{$_[0]};
	my @optional = @{$_[1]};
	my $req = $_[2];
	my @booleans = ();
	@booleans = @{$_[3]} if exists($_[3]);
	
	my %form_content = map { $_ => '' } (@mandatory, @optional);
	my $var; my $count = 0; my $msg = '';
	for (@mandatory) {
		$var = $req->param($_);
		if (defined($var) && $var ne '') {$form_content{$_} = $var ;  $count += 1;	}
	}
	for (@booleans) {
		$var = $req->param($_);
		$form_content{$_} = $req->param($_) ? 1 : 0;
	}
	for (@optional) {
		$var = $req->param($_);
		$form_content{$_} = $var if $var;
	}
	if ($count == @mandatory) { $msg = '1'; } elsif ($count) {
		$msg = sprintf("Error: Only %d of %d required fields have been filled in.",$count,scalar(@mandatory));
	}
	return {msg=>$msg, content=>\%form_content};
}

1;

__END__

=head1 NAME

GDACAP::Web - HTTP response handerl for Genomics Data Capturer 

=head1 SYNOPSIS


=head1 DESCRIPTION

Most out layer functions

=head1 METHODS

=head2 validate_form
  
  {} = validate_form(\@mandatory_fields(), \@optional_fields, $Apache2::Request, \@booleans)

First three arguments are mandatory and the fourth is optional. It returns a hash reference with keys of content and msg. content is a hash reference contains all fields in a form including empty optional fields.

msg has three values: empty string means the form has not been filled; 1 means all mandatory fields have been filled; otherwise, a string tells how many mandatory fields have been filled.

@booleans is used to check the values of checkbox like web controls.

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