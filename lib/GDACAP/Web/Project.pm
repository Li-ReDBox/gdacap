package GDACAP::Web::Project;

use strict;
use warnings;

use Apache2::Request;
use Try::Tiny;

require GDACAP::DB::Project;
require GDACAP::DB::Anzsrc4;
require GDACAP::DB::Phase;
require GDACAP::DB::File;
require GDACAP::Web::Page;
require GDACAP::Repository;

my ($action, $person_id, $logger);
my %known_action = map {$_ => 1} qw(list show create edit manage show_files show_file manage_files dec export); 

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
	$logger = $GDACAP::Web::logger;
	$action = 'list' unless $action;
	if (exists($known_action{$action})) {
		# $logger->trace("Above action has been defined") if defined(&$action);
		no strict 'refs';
        &{$action}($r, $person_id);
    } else { 
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

# list all project of a person
sub list {
	my ($r, $person_id) = @_;
	my $projects = GDACAP::DB::Personrole->new($person_id)->projects();

    my $tpl_setting = { template_name => 'projects', };
    my $content = {
        header                 => 'Projects',
        section_article_id     => 'Projects',
		projects               => $projects,
        edit_project_link      => $GDACAP::Web::location."/project/edit",
        goto_project_link      => $GDACAP::Web::location."/project/show",
    };
	GDACAP::Web::Page::display( $r, $tpl_setting, $content, $person_id );
}

sub show {
    my ( $r, $person_id ) = @_;
	
    my $req = Apache2::Request->new($r);
    my $project_id = $req->param("project_id"); 
	unless ($project_id) {
		GDACAP::Web::Page::show_msg($r, 'Bad request','No project id is given.');
		return;
	}
	my $role = GDACAP::DB::Personrole->new($person_id);
	my $right = $role->has_right($project_id,'project');
	unless ($right) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	display_project($r, $project_id, $right);
}

sub create {
    my ( $r, $person_id ) = @_;
	
    my $req = Apache2::Request->new($r);

	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Project::creation, \@GDACAP::DB::Project::creation_optional, $req);
	my $msg = $$validated_form{msg}; 
	my $project = $$validated_form{content};
	if ($msg eq '1') {	
		# All filled in
		my $project_rcd = GDACAP::DB::Project->new();
		my $new_id = $project_rcd->create($person_id, $project);
		if ($new_id) {
			display_project($r, $new_id, 'w');
			return;
		} else {
			$msg = "The creation of project failed.";
		}
	}

    $$project{start_date} = today() unless $$project{start_date};
    $$project{end_date} = today() if $$project{end_date} eq '';
	my $anzsrc = GDACAP::DB::Anzsrc4->new();
	
	my $tpl_setting = { template_name => 'project_create' };
	my $content = {
		section_article_id => 'Createproject',
		header     => 'Create project',
		action     => $GDACAP::Web::location.'/project/create/',
		help_url   => $GDACAP::Web::location.'/command/help/?id=project_create',            
		anzsrc_url => $GDACAP::Web::location.'/command/anzsrc/',       # for the jquery function to have the correct URI we post it to the page
		anzsrcs    => $anzsrc->get_all(),
		project    => $project,
		expoints   => expoints(),
		message    => $msg,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub edit {
    my ( $r, $person_id ) = @_;
	my $method = $r->method();
	if ($method ne 'POST') {
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not make up request.');
		return;
	}
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id"); 

	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $project = GDACAP::DB::Project->new();
	$project->by_id($project_id);
	my $validated_form = GDACAP::Web::validate_form(\@GDACAP::DB::Project::creation, \@GDACAP::DB::Project::creation_optional, $req);
	my $msg = $$validated_form{msg}; 
	if ($msg eq '1') {	
		# All filled in
		my $info = $$validated_form{content};
		try {
			$project->update($info);
			$msg = "The project has been updated.";
		} catch {
			$msg = $_;
		};
	}
	
	my $anzsrc = GDACAP::DB::Anzsrc4->new();
	my $phase = GDACAP::DB::Phase->new();
    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'project_edit',
    };
	my $template_vars = {
		section_article_id => 'Editproject',
		header           => 'Edit project',
        action           => $GDACAP::Web::location.'/project/edit',
		help_url         => $GDACAP::Web::location.'/command/help/?id=project_edit',            
        project          => $project->values(),
        phasestatuses    => $phase->phases(),
		anzsrcs          => $anzsrc->get_all(),
        anzsrc_url       => $GDACAP::Web::location.'/command/anzsrc',
        expoints         => expoints(),
        message          => $msg,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub manage {
    my ( $r, $person_id ) = @_;
	my $method = $r->method();
	if ($method ne 'POST') {
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not make up request.');
		return;
	}
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id"); 

	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $msg = '';
	my $account_id = $req->param("person_id");
	if (defined($account_id)) { # information has been set
		my $role_type_id = $req->param("role_type_id");
		if ($role_type_id) {
			my $command = $req->param("command");
			my $account_role = GDACAP::DB::Personrole->new($account_id);
			if ($command eq 'add') {
				$account_role->assign($project_id,$role_type_id);
			} elsif ($command eq 'remove') {
				$account_role->remove($project_id, $role_type_id);
			}
			$msg = 'Role has been changed.';
		}
	}
	my $project = GDACAP::DB::Project->new();
	$project->by_id($project_id);
	
    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'project_manage',
    };
	my $template_vars = {
		section_article_id => 'Manageproject',
		header      => 'Manage roles of a project',
        action      => $GDACAP::Web::location.'/project/manage',
		help_url    => $GDACAP::Web::location.'/command/help/?id=project_manage',            
        project_id  => $project_id,
        roletypes   => $role->types(),
        persons     => $project->non_members(),
        personroles => $project->members(),
        message     => $msg,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub manage_files {
    my ( $r, $person_id ) = @_;
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id");
	my $action = $req->param("action");
	
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {	
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	if ($action eq 'Decomission') {
		dec($r, $person_id);
	} else {
		export($r, $person_id);
	}
}

sub show_files {
    my ( $r, $person_id ) = @_;
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id"); 

	my $role = GDACAP::DB::Personrole->new($person_id);
	my $right = $role->has_right($project_id, 'project');
	unless ($right) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $project = GDACAP::DB::Project->new();
	my $tpl_setting = {
		project_navigation       => $project_id, # must pass the project_id for project_navigation to work
		template_name            => 'project_files',
	};
	my $action = '';
	if ($right eq 'w') {
		$action = $GDACAP::Web::location."/project/manage_files";
	}
	my $content = {
		section_article_id => 'Project',
		header             => 'Files of project',
		fileinfo           => $project->files($project_id),
		process_link       => $GDACAP::Web::location."/process", 
		action		       => $action, 
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub show_file {
    my ( $r, $person_id ) = @_;
	my $req = Apache2::Request->new($r);
	my $file_copy_id = $req->param("file_copy_id"); 

	my $file = GDACAP::DB::File->new();
	$file->by_id($file_copy_id);
	my $project_id = $file->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'project_files',
    };
    my $content = {
        section_article_id => 'Project',
        header             => 'File information',
        fileinfo           => [$file->values()],
        action 			   => '',  # only to mak TT happy
		process_link       => $GDACAP::Web::location."/process", 
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# decommission files
sub dec {
    my ( $r, $person_id ) = @_;
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id");
	my @hashes = $req->param("hashes"); 

	my $msg = 'Only relevant files for decomissioning shown here.';
	if (@hashes >= 1) {
		my $repository = GDACAP::Resource::get_repository();
		require GDACAP::Repository;
		my $repo = GDACAP::Repository->new($$repository{target});
		if ($repo) {
			my $status = $repo->decommission(\@hashes);
			if ($status == 1) {
				$msg = 'Requested files have been decommissioned.';
			} elsif ($status == 2) {
				$msg = 'Requested files have been scheduled for decommissioning.';
			} else {
				$msg = 'Request failed. Please inform administrators.';
			}
		} else {
			$msg = 'Repository cannot be read. Design or setting fault.';
		}
	}
	
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {	
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $project = GDACAP::DB::Project->new();
    my $tpl_setting = {
        project_navigation => $project_id, # must pass the project_id for project_navigation to work
        template_name      => 'project_files_repo',
    };
    my $content = {
        section_article_id => 'Project',
        header     => 'File decomission',
        project_id => $project_id,
        fileinfo   => $project->files_can_dec($project_id),
        action     => $GDACAP::Web::location.'/project/dec',
        message    => $msg,
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# Export files to user's place
sub export {
    my ( $r, $person_id ) = @_;
	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id"); 

	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {	
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $msg = 'Only relevant files for exporting shown here.';
	my $project = GDACAP::DB::Project->new();
	my $expoint = $project->can_export($project_id);
	unless ($expoint) {
		$msg = "System has not been set up for retrieving files. Edit project setting first.";
		GDACAP::Web::Page::show_msg($r, 'Error',$msg);
		return;
	}	

	my @hashes = $req->param("hashes"); 
	if (@hashes >= 1) {
		my $files = GDACAP::DB::File->new();
		my (@hash_names, $f_info);
		for (@hashes) {
			$f_info = $files->extend_hash($project_id, $_);
			push(@hash_names, {hash=>$_, original_name=>$$f_info{original_name}});
		}
		my $repository = GDACAP::Resource::get_repository();
		require GDACAP::Repository;
		my $repo = GDACAP::Repository->new($$repository{target});
		if ($repo) {
			my $status = $repo->export(\@hash_names, $expoint, $req->param("sub_dir"));
			if ($status == 1) {
				$msg = 'Requested files have been exported';
			} elsif ($status == 2) {
				$msg = 'Requested files have been scheduled for exporting.';
			} else {
				$msg = 'Request failed. Please inform administrators.';
			}
		} else {
			$msg = 'Repository cannot be read. Design or setting fault.';
		}
	}
	
    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'project_files_repo',
    };
    my $content = {
        section_article_id => 'Project',
        header     => 'File exproting',
        fileinfo   => $project->files_can_expo($project_id),
        action     => $GDACAP::Web::location.'/project/export',
        message    => $msg,
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

# end of interface functions

# internal functions
sub display_project {
	my ($r, $project_id, $right) = @_;
    my $project = GDACAP::DB::Project->new();
	my $meta = $project->by_id($project_id);
	my $warning = $project->has_Manager() ? "" : "Remember, appoint a Manager before publishing to RDA."; #Only shown when there is no Manager and user is a project administrator

    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'project',
    };
    my $content = {
        header                    => 'Project',
        section_article_id        => 'Project',
        project                   => $meta,
		members 				  => $project->members(),
        samples                   => $project->samples(),
        studies                   => $project->studies(),
        processes                 => $project->root_processes(),
        fileinfo                  => $project->files(),
        write_permission          => $right eq 'w' ? 1 : 0,
        admin_msg				  => $warning,
        edit_project_link         => $GDACAP::Web::location."/project/edit",
        show_more_file            => $GDACAP::Web::location."/project/show_files",
        project_manage_url        => $GDACAP::Web::location."/project/manage",
        decomission_files         => $GDACAP::Web::location."/project/dec",
        export_files              => $GDACAP::Web::location."/project/export",
        goto_sample_link          => $GDACAP::Web::location."/sample",
        add_sample_link           => $GDACAP::Web::location.'/sample/create',
        goto_study_link           => $GDACAP::Web::location."/study",
        add_study_link            => $GDACAP::Web::location.'/study/create',
		process_link              => $GDACAP::Web::location."/process", 
        help_url                  => $GDACAP::Web::location.'/command/help/?id=project',		
    };
    GDACAP::Web::Page::display($r, $tpl_setting, $content, $person_id);
}

sub today {
	use POSIX qw(strftime);
	return strftime "%Y-%m-%d", localtime;
}

# internal function to prepare expoints for project administrators to choose for a project
# used by create() and edit()
sub expoints {
	my @points = ();
	if (%$GDACAP::Web::expoints) {
		my @map;
		for(keys %$GDACAP::Web::expoints) {
			@map = split(',', $$GDACAP::Web::expoints{$_});
			push(@points, [$_, $map[0]]);
		}
	}
	return \@points;
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
