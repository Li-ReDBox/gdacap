package GDACAP::Web::Tool;
use strict;
use warnings;

use GDACAP::Web::Page;
use GDACAP::DB::Tool;

my ($action, $person_id, $logger);
my %known_action = map {$_ => 1} qw(list show);

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
	$logger = $GDACAP::Web::logger;
	Carp::carp('$person_id is not defined. Should have done it.') unless $person_id;
	$action = 'list' unless $action;
	if (exists($known_action{$action})) {
		no strict 'refs';
		&{$action}($r);
    } else { 
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub list {
	my ($r) = @_;
	my $tools = GDACAP::DB::Tool->new();
    my $function_vars = { template_name => 'tool', };
    my $template_vars = {
        header             => '',
        section_article_id => 'Tools',
		tools => $tools->all(),
    };
    GDACAP::Web::Page::display( $r, $function_vars, $template_vars, $person_id );
}

sub show {
	my ($r) = @_;
	GDACAP::Web::Page::show_msg($r, 'Tool', 'Tool::show was called.');
}

1;

__END__

=head1 NAME

GDACAP::Web::Tool - UI for Tools 

=head1 SYNOPSIS


=head1 DESCRIPTION

Users need to log in to access this page. $person_id is needed.

=head1 AUTHOR

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
