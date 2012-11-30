GDACAP - all Perl source code
resources - web related resources
tests - test codes

To install the package, put GDACAP to a location and define the path in startup.pl which when Apache starts will read to enable Apache to find it. If not sure how to set up the package with mod_perl, please reference to mod_perl document. Website resources can be copied or linked to the website document root (e.g. /var/www/html). All settings related to the package are saved in config.conf. After copied all files, make modification in config.conf accordingly to reflect your installation. 

Make changes in the website configuarion file e.g. httpd.conf. On RPM syste, simply create your_conf_name.conf and put lines like these:
PerlModule Apache::DBI
PerlRequire /where/your/startup.pl
<Location /the_name_you_will_call>
	SetHandler modperl
	PerlResponseHandler GDACAP::Root
	PerlSetVar ANDSConfig configfile
</Location>

Website resource:
[folders]/resources = /resources/gdacap # This is web site path. Used for web applcations.

If the package is not going to be used with Apache mod_perl, add the path to @INC. One example solution is to add GDACAP to @INC by using ENVIRONMENT variable PERLLIB or PERL5LIB: 	
    export PERLLIB=WHERE_GDACAP_IS

config.conf	
[database]
host=127.0.0.1
dbname=YOUR_DB_NAME
user=USER_NAME
passwd=PASSWORD

[folders]
template = /var/www/dc08_source/resources/templates
upload = /var/lib/gdacap/uploaded
resources = /resources/gdacap # This is web site path. Used for web applcations.
bin = /var/www/dc08_source/bin
submission = /var/lib/gdacap/submission

[repository]
source = SOMEWHERE_FILE_SOURCE
target = SOMEWHERE_TO_MOVE_TO

[session]
session = /var/lib/gdacap/sessions
has_https = 1
