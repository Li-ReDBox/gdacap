package GDACAP::Web::Sample;

use strict;
use warnings;

use Apache2::Request;
use Try::Tiny;

require GDACAP::DB::Sample;

my ($action, $person_id);
my %known_action = map {$_ => 1} qw(show create edit); 

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
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
    my $id = $req->param("sample_id");
	unless ($id) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}
	my $sample = GDACAP::DB::Sample->new();
	my $meta = $sample->by_id($id);
	unless ($meta) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','Do not know what to show.');
		return;
	}

	my $role = GDACAP::DB::Personrole->new($person_id);
	my $right = $role->has_right($sample->project_id(),'sample');
	unless ($right) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	display_sample($r, $meta, $right);
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
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Sample::creation, [], $req, ['accessible'] );
	my $sample = $$validated_form{content};
	my $msg = '';
	if ($req->param("iname")) {
		$msg = $$validated_form{msg}; 
		if ($msg eq '1') {	
			# All filled in
			my $sample_rcd = GDACAP::DB::Sample->new();
			my $new_id = $sample_rcd->create($sample);
			if ($new_id) {
				display_sample($r, $sample_rcd->by_id($new_id), 'w');
				return;
			} else {
				$msg = "The creation of sample failed.";
			}
		}
	}
    my $tpl_setting = {
        template_name            => 'sample_create',
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Createsample',
        header       => 'Creat a sample',
        action       => $GDACAP::Web::location.'/sample/create',
		help_url     => $GDACAP::Web::location.'/command/help/?id=sample_create',            
		message      => $msg,
		project_id   => $project_id,
		sample       => $sample,
		tax_id_url   => $GDACAP::Web::location.'/command/tax_id/',      # retrieve tax_ids
		tax_info_url => $GDACAP::Web::location.'/command/tax_info/',    # get information about a specific taxonomy
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub edit {
    my ( $r, $person_id ) = @_;
	
	my $req = Apache2::Request->new($r);
	my $sample_id = $req->param("sample_id"); 
	my $sample_rcd = GDACAP::DB::Sample->new();
	$sample_rcd->by_id($sample_id);
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($$sample_rcd{project_id},'sample') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Sample::update, [], $req, ['accessible'] );
	my $info = $$validated_form{content};
	my $msg = $$validated_form{msg}; 
	if ($msg eq '1') {	
		try {
			$sample_rcd->update($info);
			$msg = "The sample has been updated.";
		} catch {
			$msg = $_;
		};
	}

    my $tpl_setting = {
        template_name            => 'sample_edit',
        project_navigation       => $$sample_rcd{project_id}, # must pass the project_id for project_navigation to work
    };
    my $content = {
        section_article_id   => 'Editsample',
        header       => 'Edit a sample',
        action       => $GDACAP::Web::location.'/sample/edit',
		help_url     => $GDACAP::Web::location.'/command/help/?id=sample_edit',            
		message      => $msg,
		sample       => $sample_rcd->values(),
		tax_id_url   => $GDACAP::Web::location.'/command/tax_id/',      # retrieve tax_ids
		tax_info_url => $GDACAP::Web::location.'/command/tax_info/',    # get information about a specific taxonomy
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# Internal functions
sub display_sample {
	my ($r, $meta, $right) = @_;
	my $write_permission = $right eq 'w' ? 1 : 0;			
	if ($write_permission) {
		$write_permission = 0 if ($$meta{accession});
	}

    my $tpl_setting = {
        template_name            => 'sample',
        project_navigation       => $$meta{project_id}, # must pass the project_id for project_navigation to work
    };
    my $content = {
        header               => 'Sample',
        section_article_id   => 'Sample',
        sample               => $meta,
        write_permission     => $write_permission,		
        edit_sample_link     => $GDACAP::Web::location."/sample/edit",
        help_url             => $GDACAP::Web::location.'/command/help/?id=sample',		
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