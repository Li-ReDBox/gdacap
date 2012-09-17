package GDACAP::REST::Process;

use strict;
use warnings;

use Apache2::RequestRec(); # for $r->content_type
use Apache2::RequestIO(); # for $r->print
use Apache2::Connection ();
use Apache2::Const -compile => qw(OK);
use Apache2::URI ();
use APR::URI ();
use APR::UUID ();
use JSON;
use File::Spec;
use Try::Tiny;
use feature "switch";

use GDACAP::Process;

use Log::Log4perl;

our ($logger, $repository, $secure, $sourcep, $targetp);
{
	use Apache2::ServerUtil ();
	my $s = Apache2::ServerUtil->server();
	my $config_file = $s->dir_config('GDACAPConfig') || '';
	die "GDACAP Config file isn't set in httpd configuration direcotry" unless $config_file;
	require GDACAP::Resource;
	my $config = GDACAP::Resource->prepare($config_file,1);
	$logger = Log::Log4perl::get_logger();
	$repository = GDACAP::Resource::get_repository();
	$sourcep = $$repository{source} or die "Cannot get Source folder path";
	$targetp = $$repository{target} or die "Cannot get Target folder path";

	my $section = $$config{'session'};
	$secure = $$section{has_https}; # whether to enforce HTTPS
#	$logger->debug("REST Process starts - HTTPS required = $secure");
}

sub handler {
	my ($r) = @_;
	my $req_method = $r->method();
	if ($req_method eq 'POST') {
		if ($secure) {
			$logger->debug("Has to be HTTPS for POST request");
			my $parsed = APR::URI->parse($r->pool, $r->construct_url());
#			$logger->debug('$parsed->scheme=',$parsed->scheme);
#			$logger->debug('$r->subprocess_env(\'https\')=',$r->subprocess_env('https'));
			# Two methods used below are doing the same thing to make sure HTTPS has been set
			unless ($parsed->scheme eq 'https' and	$r->subprocess_env('https')) {
				$r->status("400");
				return Apache2::Const::OK;
			} 
		}
		try {
			create_process($r);
		} catch {
			$logger->info("Failed to take action. $_\n");
			$r->status("400");
			$r->content_type("text/plain");
			$r->print($_);
		};
	} else {
		get_instruction($r);
	}
	return Apache2::Const::OK;
}

# Keep a log on what happened
sub save_json {
	my ($json, $tpath) = @_;
	my $fn = APR::UUID->new->format() . '.json';
	$fn = File::Spec->catfile($tpath,$fn);
	$logger->info("Saving JSON file: $fn");
	open(my $fh, '>', $fn) or $logger->logdie("Cannot log Process JSON: $! ");
	print $fh $json;
	close $fh;
}


# Now just giving instruction: mapping user name and target path
sub get_instruction {
	my ($r) = @_;
	# $r->status("200");
	# $r->content_type("text/plain");
	# $r->print("You tried to get information of process\n");
	# $r->print("here is where to save\n");
	# when no parameter is given, return instruction
	my %rt = (user=>'gdacaper',path=>$$repository{source});
	response($r, \%rt);
}

# If there is an error, it returns earlier
sub create_process {
	my ($r) = @_;
	my ($buf, $body);
	while ($r->read($buf, 64)) {
		$body .= $buf;
	}

	my $pr = GDACAP::Process->new();
	$pr->pool_paths($repository);
	my $success = try {
		# save json and request ip to a file, if anything wrong, allow manual process
		# It also registers where the request came from
		my $c = $r->connection;
		save_json("client_ip:".$c->remote_ip()."\n".$body,$targetp);
		$pr->load_from_json($body);
		return 1;
	} catch {
	   $logger->debug($_);
	   return 0;
	};
	return unless $success;

	my $rt = $pr->check();
	if ($$rt{error}) {
		$logger->info("Verification failed. More reason:\n", to_json($rt));
		response_error($r, "406", "Verification failed. More reason:" . to_json($rt));
	} else {
		if ($pr->register()) {
			$logger->info('Registration was successful');
			$$rt{Register} = 'Successful';
			response($r, $rt);
		} else {
			# print $fh_err response($$rt{msg}="Failed to register your process. More reason: $_");
			$logger->info(response($$rt{msg}="Failed to register your process. More reason: $_"));
			response_error($r,"406","Failed to register your process. More reason: $_\n");
		}
	}
	undef $pr;
}

sub response_error {
	my ($r, $err_code, $msg) = @_;
	$r->status($err_code);
	$r->content_type('text/plain');
	$r->print($msg);
}

sub response {
	my ($r, $rt_hash) = @_;
	$r->status("200");
	$r->content_type('application/json');
	$r->print(to_json($rt_hash));
}

1;

__END__

=head1 NAME

GDACAP::REST::Process - REST web service for registering a Process

=head1 DESCRIPTION

C<GDACAP::REST::Process> is a REST web service to provide an interface to C<GDACAP::Process>.
It logs major envents, saves uploaded JSON. It sends feedback of operation. Only CREATE (POST)
 and QUERY (GET) are implemented.

I<Note>: has_https = 1/0 in [session] section in config.conf 

It defines if current session is HTTPS or HTTP. If it is TRUE,CREATE action is only
allowed trhough HTTPS connection.This setting also affect whether secure cookie is created.

=head1 FUNCTIONS

=head2 handler(Apache2::RequestRec)

Service entry.

=head2 create_process

Register files included in request JSON with other information into database. All files
have to be existed in Repository/Target. Check is done by C<GDACAP::Process->check>.

=head2 get_instruction

Query about this service (GET). It returns scp user account and path where files will be saved.

=head2 response

When operation finishs correctly, returns status code 200 and a JSON of what was sent in.

=head2 response_error

When operation cannot be completed, returns error code and a plain text of error message.

=head2 save_json

Save current request JSON with client IP address in a file in Repository/Target defined in config.conf.
It is not a valid JSON as the first line is clinet IP: xxx.

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
