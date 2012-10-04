package GDACAP::Web::Run;

use strict;
use warnings;

use Apache2::Request;
use Try::Tiny;

require GDACAP::DB::Experiment;
require GDACAP::DB::Run;
require GDACAP::Web::Experiment;

my ($action, $person_id, $logger);
my %known_action = map {$_ => 1} qw(create edit); 

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
	$logger = $GDACAP::Web::logger;	
	$action = 'create' unless $action;
	if (exists($known_action{$action})) {
		no strict 'refs';
        &{$action}($r, $person_id);
    } else { 
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub create {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $experiment_id = $req->param("experiment_id"); 
	my $exp = GDACAP::DB::Experiment->new();
	$exp->by_id($experiment_id);
	my $project_id = $exp->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id,'experiment') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	
    my $msg = "";   
	my @selected_files  = $req->param('file_copy_id');
	if (@selected_files >= 1) {
		my $run = GDACAP::DB::Run->new();	
		my $status =0;
		$status = try {
			if ($run->create({experiment_id=>$experiment_id, run_date=>$req->param('run_date'), 
							  file_copy_ids=>\@selected_files, phred_offset=>$req->param('score_offset')})) {
				$logger->debug(@selected_files . " have been added with $req->param('score_offset').");
				return 1;
			} else {
				$msg = "New run has not been added.";
			}
		} catch {
			$logger->error($_);
			$msg = "Not all files have been successfully added. They might have been added before. $_";
		};
		if ($status) {
			$r->headers_out->set( 'Location' => $GDACAP::Web::location.'/experiment/show?experiment_id='.$experiment_id );
			$r->status(Apache2::Const::REDIRECT);
			return;
		}
	}

    my $tpl_setting = {
        template_name            => 'run_create',
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Editexperiment',
        header     => 'Add run files to an experiment',
        action     => $GDACAP::Web::location.'/run/create',
		help_url   => $GDACAP::Web::location.'/command/help/?id=run_create',
		message    => $msg,
		experiment => $exp->values(),
		runs       => $exp->runs(),
        files      => $exp->run_candidates(),
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub edit {
    my ( $r, $person_id ) = @_;

    my $req = Apache2::Request->new($r);
	my $run_id  = $req->param('run_id');

	my $run = GDACAP::DB::Run->new();
	$run->by_id($run_id);
    my $experiment_id = $$run{experiment_id}; 
	
    my $experiment = GDACAP::DB::Experiment->new();
	$experiment->by_id( $experiment_id);
	my $project_id = $experiment->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id,'experiment') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	
    my $msg = "";    
	my $score_offset = $req->param('score_offset');
	if ($score_offset) {
		$logger->debug("Editing run $run_id");
		my @file_copy_ids  = $req->param('file_copy_id');
		try {
			if ($run->update({run_date=>$req->param('run_date'), file_copy_ids=>\@file_copy_ids,phred_offset=>$req->param('score_offset')})) {
				$msg .= "Editing was successful.";
			} else {
				$msg .= "Run ($run_id) has not been updated successfully.";
			}
		} catch {
			$msg .= "Editing was not successful. $_";
		};
	}

    my $tpl_setting = {
        template_name       => 'run_edit',
        project_navigation  => $project_id, 
    };
    my $content = {
        section_article_id   => 'Editexperiment',
        header     => "Edit experiment's run",
        action     => $GDACAP::Web::location.'/run/edit',
		help_url   => $GDACAP::Web::location.'/command/help/?id=run_create',
		message    => $msg,
		experiment => $experiment->values(),
		run        => $run->values(),
        files      => $experiment->run_candidates(),
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

1;

__END__

=head1 NAME

GDACAP::Web::Command - Commands for none login use 

=head1 SYNOPSIS


=head1 DESCRIPTION

Most out layer functions

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
