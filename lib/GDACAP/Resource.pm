package GDACAP::Resource;

END { local($?); cleanup(); }

use strict;
use warnings;

use Carp;
require Config::Tiny;
require DBI;
require GDACAP::DBA;

my $INITIALISED = 0;
my $CONF_PATH = undef;
my $dbh;
my %repository = ();

sub cleanup {
    # Disconnect the connection to database
	if (defined($dbh)) {
		$dbh->rollback unless $dbh->{AutoCommit} ;
		$dbh->disconnect();
		undef $dbh;
	}

    undef $INITIALISED;
}

# Prepare the basic resources: GDACAP::DBA handler (PostgreSQL only). Optional, initialise a logger or skip preparing
sub prepare {
	my ($class, $conf, $init_logger, $skip) = @_;
	return if $INITIALISED;
	if ($conf) { $CONF_PATH = $conf; } else { $CONF_PATH = 'config.conf'; }

	# print "I will read $conf\n";
	# # Open the config
	# # When called by ModPerl, use absolute path
	return if ($skip && not $init_logger);
	my $config = Config::Tiny->read($conf);
	carp $Config::Tiny::errstr unless $config;

	if (! $skip) {
		# Read properties
		my $dbname = $config->{database}->{dbname} or carp "Cannot read dbname from $conf";
		my $host = $config->{database}->{host} or carp "Cannot read host from $conf";
		my $user = $config->{database}->{user} or carp "Cannot read username from $conf";
		my $passwd = $config->{database}->{passwd} or carp "Cannot read password from $conf";

		my @db = ($dbname, $host, $user, $passwd);
		$dbh = GDACAP::DBA->connect(@db)->{DBH};
	}

	init_logger($config) if $init_logger;
	$INITIALISED = 1;
	delete @$config{qw(database log)};
	return $config;
}

sub get_dbh {
	# if (defined($dbh) && ref($dbh) eq 'GDACAP::DBA') {
	# print STDERR __PACKAGE__,'ref($dbh)=',ref($dbh),"\n";
	# When Apache::DBI is used, ref($dbh)=Apache::DBI::db
	if (defined($dbh) && index(ref($dbh), 'DBI::db') != -1) {
		# print "return a handle and it is \n\t",ref($dbh),"\n";
		return $dbh;
	} else {
		print STDERR "Confpath=$CONF_PATH.\n";
		carp "Usage: Need to be initialised first by calling ".__PACKAGE__."->prepare()\n";
	}
}

# Resource.pm holds the value of repository once it has been read
sub get_repository {
	_read_repository() unless (exists($repository{source}) && exists($repository{target}));
	return \%repository;
}

sub _read_repository {
	my $repo = get_section('repository');
	if ($repo) {
		$repository{source} = $repo->{source};
		$repository{target} = $repo->{target};
	}
}

sub get_section {
	return unless $CONF_PATH;

	my $config = Config::Tiny->read($CONF_PATH);
	carp $Config::Tiny::errstr unless $config;

	my ($section) = @_;
	return $config->{$section} if exists($config->{$section});
}

sub init_logger {
	my $log;
	if (@_) {	# called from prepare with configuration file has been read
		my $config = ref($_[0]) eq 'GDACAP::Resource' ? $_[1] : $_[0]; # to support OO or none-OO
		$log = $config->{log};
	} else {
		carp "Cannot initialise logger because do not know the setting" unless $CONF_PATH;
		$log = get_section('log');
	}
	return unless $log;

	use Log::Log4perl;
	Log::Log4perl::init($log);
}

our %IMPORT_CALLED;
sub import {
    my($class) = shift;

    no strict qw(refs);

    my $caller_pkg = caller();

    return 1 if $IMPORT_CALLED{$caller_pkg}++;

    my(%tags) = map { $_ => 1 } @_;

    if(exists $tags{':all'}) {
        $tags{'get_dbh'} = 1;
        $tags{'get_repository'} = 1;
        $tags{'init_logger'} = 1;
        $tags{'get_section'} = 1;
    }

    if(exists $tags{get_dbh}) {
        # Export get_dbh into the calling module's
        *{"$caller_pkg\::get_dbh"} = *get_dbh;
        delete $tags{get_dbh};
    }
    if(exists $tags{get_repository}) {
        # Export get_repository into the calling module's
        *{"$caller_pkg\::get_repository"} = *get_repository;
        delete $tags{get_repository};
    }
    if(exists $tags{init_logger}) {
        # Export init_logger into the calling module's
        *{"$caller_pkg\::init_logger"} = *init_logger;
        delete $tags{init_logger};
    }
    if(exists $tags{get_section}) {
        # Export get_section into the calling module's
        *{"$caller_pkg\::get_section"} = *get_section;
        delete $tags{get_section};
    }
}

1;

__END__

=head1 NAME

GDACAP::Resource - The resource handler for GDACAP applications

=head1 SYNOPSIS

 use GDACAP::Reources ();
 # Read the actual variable values from a configuration file
 # By default, a configuration file is saved in current working directory and the name is 'config.conf'
 GDACAP::Resource->prepare();
 # But more likely, you need to give the full path of your configruation file
 GDACAP::Resource->prepare('../config.conf');
 # If a logger is needed, call C<prepare()> with the second argumenet as anything means true
 GDACAP::Resource->prepare('../config.conf',1);
 # If more then just initialisations,
 my $config = GDACAP::Resource->prepare('../config.conf');
 my $section = $$config{section_name};
 # If just need to read a section of a configuration file through C<get_section>, skip the preparation of database by setting the third argument to true.
 GDACAP::Resource->prepare('../config.conf',0,1);

 # After preparation, to get the database handler DBI::db of PostgreSQL
 use GDACAP::Resource qw(get_dbh);
 $dbh = get_dbh;
 print "Database handler type:",ref($dbh),"\n";

 # Another resource, to get the pathes of repository
 use GDACAP::Resource qw(get_repository);
 $repository = get_repository
 print "repository\n";
 print "source path = $$repository{source}, target path = $$repository{target}\n";

 # If you have not initialised logger
 GDACAP::Resource->init_logger();
# Import logger in
 use Log::Log4perl qw(get_logger);
 $logger = get_logger();
 $logger->info("Welecome");

 # Other settings are grouped in sections and can be read by get_section
 use GDACAP::Resource qw(get_section);
 $settings = get_section('misc');
 print $$settings{key};

=head1 DESCRIPTION

This is the central resource managing package for a GDACAP application whether with/out web UI. Applications can use this module to initialise database or logger handeler or retrieve pre-defined settings in sections. Database handler is initialised by default at preparation stage but can be skipped. Logger can be initialised at the preparation stage or later.  Initialisations are needed only once. Handlers and settings can be retrieved at any time and any where independently. The module is tightly bounded to a configuration file with a structure such as the example shown below:

	[database]
	dbname = process_demo
	host = 127.0.0.1
	user = your user name
	passwd = your password

	[repository]
	source = /tmp
	target = /tmp/container

	[log]
	log4perl.category = DEBUG, Screen
	log4perl.appender.Screen = Log::Log4perl::Appender::Screen
	log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
	log4perl.appender.Screen.layout.ConversionPattern=[%d] %l - %m%n

	[mics]
	root_path = /var/www/html

It is possible to create a section, e.g. B<mics> and define other settings then read them throught C<get_section('mics')> into a hash and access the values by the keys.

=head1 FUNCTIONS

=over 4

=item prepare($path_of_conf_file,$init_logger,$skip_db)

Read from a configuration file and by default connect to a PostgreSQL database using the settings defined in the file. It takes three optional arguments:
I<path_of_conf_file>, I<init_logger> and I<skip_db>. If I<path_of_conf_file> is undef, config.conf in the current directory will be tried. It does not
work with ModPerl which needs absoultue path to files. If the second aregument is anything means true, loggers defined in [log] section are initialised at the same time.
By default, database is connected. If want to skip connecting, set the third argument to 0.

It returns the content of the configuration file in a hash reference. It is useful when some settings are needed not only handlers are initialised.

=item get_dbh

=item get_repository

=item get_section

These are three functions can be used to retrieve resources: C<get_dbh>, C<get_repository> and C<get_section>. They can be imported individually or
by :all tag to import all. Note, the hash retrieved by C<get_section> is not cached - it reads from the configuration file every time it is called.

=item init_logger

Initialise the loggers defined in the loaded configuration file. It is useful when loggers are not needed when the first time resources are prepared.
It can be imported individually or by :all tag.

=back

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
