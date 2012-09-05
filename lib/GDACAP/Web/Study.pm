package GDACAP::Web::Study;

use strict;
use warnings;

use Apache2::Request;
use Try::Tiny;

require GDACAP::DB::Study;
require GDACAP::DB::Experiment;
require GDACAP::DB::Phase;

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
    my $id = $req->param("study_id"); 
	unless ($id) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}
	my $study = GDACAP::DB::Study->new();
	my $meta = $study->by_id($id);
	unless ($meta) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}
	
	my $role = GDACAP::DB::Personrole->new($person_id);
	my $right = $role->has_right($study->project_id,'study');
	unless ($right) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	display_study($r, $study, $right);
}

sub create {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id"); 
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id,'project') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Study::creation, \@GDACAP::DB::Study::creation_optional, $req);
	my $info = $$validated_form{content};
	my $msg = '';
	my $study_rcd = GDACAP::DB::Study->new();
	if ($req->param("iname")) {
		$msg = $$validated_form{msg}; 
		if ($msg eq '1') {	
			# All filled in
			my $new_id = $study_rcd->create($info);
			if ($new_id) {
				$study_rcd->by_id($new_id);
				display_study($r, $study_rcd, 'w');
				return;
			} else {
				$msg = "The creation of study failed.";
			}
		}
	}
	
    my $tpl_setting = {
        template_name            => 'study_create',
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Createsample',
        header       => 'Creat a study',
        action       => $GDACAP::Web::location.'/study/create',
		help_url     => $GDACAP::Web::location.'/command/help/?id=study_create',            
		message      => $msg,
		project_id   => $project_id,
		study        => $info,
		studytypes   => $study_rcd->types(),
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub edit {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $study_id = $req->param("study_id"); 
	my $study_rcd = GDACAP::DB::Study->new();
	$study_rcd->by_id($study_id);
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($$study_rcd{project_id},'study') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Study::update, \@GDACAP::DB::Study::update_optional, $req);
	my $info = $$validated_form{content};
	my $msg = $$validated_form{msg}; 
	if ($msg eq '1') {	
		try {
			$study_rcd->update($info);
			$msg = "The study has been updated.";
		} catch {
			$msg = $_;
		};
	}
	my $phase = GDACAP::DB::Phase->new();

    my $tpl_setting = {
        template_name      => 'study_edit',
        project_navigation => $$study_rcd{project_id}, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Editstudy',
        header      => 'Edit a study',
        action      => $GDACAP::Web::location.'/study/edit',
		help_url    => $GDACAP::Web::location.'/command/help/?id=study_edit',            
		message     => $msg,
		study       => $study_rcd->values(),
        studytypes  => $study_rcd->types(),
        phases      => $phase->phases(),
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# Internal functions
sub display_study {
	my ($r, $study, $right) = @_;
	my $write_permission = $right eq 'w' ? 1 : 0;			
	if ($write_permission) {
		$write_permission = 0 if ($$study{accession});
	}

    my $tpl_setting = {
        template_name        => 'study',
        project_navigation   => $$study{project_id}, # must pass the project_id for project_navigation to work
    };
    my $content = {
        header               => 'Study',
        section_article_id   => 'Study',
        write_permission     => $write_permission,				
        study                => $study->values(),
        experiments          => $study->experiments(),
        edit_study_link      => $GDACAP::Web::location."/study/edit",
        experiment_action    => $GDACAP::Web::location."/experiment/show",
		add_experiment_link  => $GDACAP::Web::location."/experiment/create",
        help_url             => $GDACAP::Web::location.'/command/help/?id=study_show',		
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