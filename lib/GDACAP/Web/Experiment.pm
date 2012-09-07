package GDACAP::Web::Experiment;

use strict;
use warnings;

use Apache2::Request;
use Try::Tiny;

require GDACAP::DB::Study;
require GDACAP::DB::Experiment;
require GDACAP::DB::Sample;

my ($action, $person_id, $logger);
my %known_action = map {$_ => 1} qw(show create edit); 

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
	$logger = $GDACAP::Web::logger;	
	$action = 'show' unless $action;
	if (exists($known_action{$action})) {
		no strict 'refs';
        &{$action}($r, $person_id);
    } else { 
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub show {
    my ( $r, $person_id ) = @_;
	
    my $req = Apache2::Request->new($r);
    my $id = $req->param("experiment_id"); 
	unless ($id) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}
	my $exp = GDACAP::DB::Experiment->new();
	my $meta = $exp->by_id($id);
	unless ($meta) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}

	my $role = GDACAP::DB::Personrole->new($person_id);
	my $right = $role->has_right($exp->project_id(),'experiment');
	unless ($right) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	display_experiment($r, $exp, $right);
}

sub create {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $study_id = $req->param("study_id"); 
	my $study = GDACAP::DB::Study->new();
	$study->by_id($study_id);
	my $project = GDACAP::DB::Project->new();
	$project->by_id($$study{project_id});	
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($$study{project_id},'study') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Experiment::creation, \@GDACAP::DB::Experiment::creation_optional, $req);
	my $info = $$validated_form{content};
	my $msg = '';
	my $exp_rcd = GDACAP::DB::Experiment->new();
	if ($req->param("iname")) {
		$msg = $$validated_form{msg}; 
		if ($msg eq '1') {	
			# All filled in
			my $new_id = $exp_rcd->create($info);
			if ($new_id) {
				$exp_rcd->by_id($new_id);
				display_experiment($r, $exp_rcd, 'w');
				return;
			} else {
				$msg = "The creation of experiment failed.";
			}
		}
	}
	
    my $tpl_setting = {
        template_name            => 'experiment_create',
        project_navigation       => $$study{project_id}, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Createexperiment',
        header     => 'Creat an experiment',
        action     => $GDACAP::Web::location.'/experiment/create',
		help_url   => $GDACAP::Web::location.'/help/?id=experiment_create',
		message    => $msg,
		experiment => $info,
		study_id   => $study_id,
		samples    => $project->samples(),
		platforms  => $exp_rcd->platforms(),
		layout_changble => 1,
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub edit {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $experiment_id = $req->param("experiment_id"); 
	my $exp = GDACAP::DB::Experiment->new();
	$exp->by_id($experiment_id);
	my $project_id = $exp->project_id();
	my $project = GDACAP::DB::Project->new();
	$project->by_id($project_id);	
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id,'experiment') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Experiment::edit, \@GDACAP::DB::Experiment::creation_optional, $req,['in_rda']);
	my $msg = $$validated_form{msg}; 
	if ($msg eq '1') {	
		# All filled in
		try {
			my $experiment = $$validated_form{content};
			$exp->update($experiment);
			$msg = "The experiment has been updated.";
		} catch {
			$msg = $_;
		};
	}

    my $tpl_setting = {
        template_name            => 'experiment_edit',
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Editexperiment',
        header     => 'Edit an experiment',
        action     => $GDACAP::Web::location.'/experiment/edit',
		help_url   => $GDACAP::Web::location.'/help/?id=experiment_edit',
		message    => $msg,
		experiment => $exp->values(),
		rda_ready  => $project->has_Manager(),
		samples         => $project->samples(),
		platforms       => $exp->platforms(),
		layout_changble => $exp->layout_changeable(),		
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# Internal functions
sub display_experiment {
    my ($r, $exp, $right) = @_;
    my $write_permission = $right eq 'w' ? 1 : 0;
    my $project_id = $exp->project_id();
    if ($write_permission) {
	$write_permission = 0 if ($$exp{accession});
    }
    my $tpl_setting = {
        template_name      => 'experiment',
        project_navigation => $project_id, # must pass the project_id for project_navigation to work
    };
    my $content = {
        header               => 'Experiment',
        section_article_id   => 'Experiment',
        write_permission     => $write_permission,
        experiment           => $exp->values(),
        runs                 => $exp->runs(),
	layout_changble      => $exp->layout_changeable(),
        edit_experiment_link => $GDACAP::Web::location."/experiment/edit",
	run_edit_action      => $GDACAP::Web::location."/run/edit",
	add_experiment_run   => $GDACAP::Web::location."/run/create",
	submit2ebi           => $GDACAP::Web::location."/experiment/submit",
        help_url             => $GDACAP::Web::location.'/command/help/?id=experiment',		
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

1;

__END__

=head1 NAME

GDACAP::Web::Experiment - Create, Display or Edit an Experiment 

=head1 SYNOPSIS


=head1 DESCRIPTION

Once an Experiment has been published to EBI, nothing can be edited.

=head1 AUTHORS

Andor Lundgren 

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
