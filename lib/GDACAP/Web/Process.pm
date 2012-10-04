package GDACAP::Web::Process;

use strict;
use warnings;

use Try::Tiny;

require GDACAP::DB::Process;
require GDACAP::DB::File;

my ($action, $person_id, $logger);
my %known_action = map {$_ => 1} qw(list show extend create search visualise save);

sub handler {
	my $r;
	($r, $action, $person_id) = @_;
	$logger = $GDACAP::Web::logger;
	$action = 'list' unless $action;
	if (exists($known_action{$action})) {
		no strict 'refs';
        &{$action}($r, $person_id);
    } else {
		GDACAP::Web::Page::show_msg($r, 'Bad request', 'Please do not play.');
	}
}

sub list {
	my ($r, $person_id) = @_;

    my $req = Apache2::Request->new($r);
    my $project_id = $req->param("project_id");
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $project = GDACAP::DB::Project->new();

    my $tpl_setting = {
        project_navigation       => $project_id, # must pass the project_id for project_navigation to work
        template_name            => 'processes',
    };
	my $template_vars = {
		section_article_id => 'Process',
		header           => 'Processes only generated files - roots',
		help_url         => $GDACAP::Web::location.'/command/help/?id=processes',
		processes => $project->root_processes($project_id),
		link => $GDACAP::Web::location.'/process/show_outfile',
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub show {
	my ($r, $person_id) = @_;

	my $req = Apache2::Request->new($r);
	my $project_id = $req->param('project_id');
	if ($project_id) { show_processes($r, $person_id, $project_id);
	} else {
		my $process_id = $req->param('id');
		show_process($r, $person_id, $process_id);
	}
}

sub show_processes {
	my ($r, $person_id, $project_id) = @_;

	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $project = GDACAP::DB::Project->new();
	my $tpl_setting = {
		project_navigation => $project_id, # must pass the project_id for project_navigation to work
		template_name      => 'processes',
	};
	my $template_vars = {
		section_article_id => 'Process',
		header       => 'Processes',
		processes    => $project->processes($project_id),
		process_link => $GDACAP::Web::location.'/process',
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub show_process {
	my ($r, $person_id, $process_id) = @_;

	my $process = GDACAP::DB::Process->new();
	$process->by_id($process_id);
	my $project_id = $process->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $tpl_setting = {
		project_navigation       => $project_id, # must pass the project_id for project_navigation to work
		template_name            => 'process',
	};
	my $template_vars = {
		section_article_id => 'Process',
		header      => 'Processes',
		help_url    => $GDACAP::Web::location.'/command/help/?id=process_show',
		process     => $process->values(),
		in_files    => $process->files('in'),
		out_files   => $process->files('out'),
		extend_link => $GDACAP::Web::location.'/process/extend',
		viz_link    => $GDACAP::Web::location.'/process/visualise',
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub create {
	my ($r, $person_id) = @_;

	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id");
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project') eq 'w') {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $project = GDACAP::DB::Project->new();
	$project->by_id($project_id);

	my $processes = [{'id'=>1, 'iname' => 'Dummy process', 'command_id' => 1}];

	my $commands = [{'id' => 1, 'iname' => 'tool1', 'software_id' => 1}, {'id' => 2, 'iname' => 'tool1', 'software_id' => 2}];

	my $msg = '';
	my $tpl_setting = {
		project_navigation       => $project_id, # must pass the project_id for project_navigation to work
		template_name            => 'process_create',
	};
	my $template_vars = {
		section_article_id => 'Process',
		header           => 'Crate a process - an step of an analysis pipeline',
		message          => $msg,
		help_url         => $GDACAP::Web::location.'/command/help/?id=analyse',
		project          => $project->values(),
		person_id        => $person_id,
		commands                          => $commands,
		files                             => $project->files,
		processes                         => $processes,
		create_process_url                => $GDACAP::Web::location."/create_process_from_commands/",
		get_bash_command_url              => $GDACAP::Web::location."/get_bash_command/",
		get_command_url                   => $GDACAP::Web::location."/get_command/",
		get_graphviz_url                  => $GDACAP::Web::location."/get_graph/",
		get_graphviz_with_process_id_url  => $GDACAP::Web::location."/get_graph_with_process_id/",
		get_process_with_dependencies_url => $GDACAP::Web::location."/get_process_with_dependencies/",
		goto_create_pipeline_link         => $GDACAP::Web::location."/pipeline_create",
		info_url                          => { analyse_files => $GDACAP::Web::location."/command/help/?id=analyse_files", } ,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

# FIXME: not functional and has no UI
sub search {
	my ($r, $person_id) = @_;

	my $req = Apache2::Request->new($r);
	my $project_id = $req->param("project_id");
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	my $tpl_setting = {
		project_navigation       => $project_id, # must pass the project_id for project_navigation to work
		template_name            => 'process_search',
	};
	my $template_vars = {
		section_article_id => 'Process',
		header           => 'Search a process',
		help_url         => $GDACAP::Web::location.'/command/help/?id=process_search',
		project_id => $project_id,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

# Use file_copy_id as a linker to extend current process to others
sub extend {
	my ($r, $person_id) = @_;

	my $req = Apache2::Request->new($r);
	my $file_copy_id = $req->param('file_copy_id');
	my $file = GDACAP::DB::File->new();
	$file->by_id($file_copy_id);
	my $project_id = $file->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}

	my $process = GDACAP::DB::Process->new();
	my $processes = $process->took($file_copy_id);
	$processes = [] unless $processes;
	my $tpl_setting = {
		template_name => 'processes_takes',
		project_navigation => $project_id, # must pass the project_id for project_navigation to work
	};
	my $template_vars = {
		section_article_id => 'Process',
		header             => 'Process',
		help_url           => $GDACAP::Web::location.'/command/help/?id=processes',
		file_copy          => $$file{original_name},
		from_processes     => $process->processed($file_copy_id),
		processes 		   => $processes,
		process_link       => $GDACAP::Web::location.'/process',
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub visualise {
	my ($r, $person_id) = @_;

	my $req = Apache2::Request->new($r);
	my $file_copy_id = $req->param('file_copy_id');
	my $file = GDACAP::DB::File->new();
	$file->by_id($file_copy_id);
	my $project_id = $file->project_id();
	my $role = GDACAP::DB::Personrole->new($person_id);
	unless ($role->has_right($project_id, 'project')) {
		GDACAP::Web::Page::show_msg($r, 'Accesse is denied','No information is available to you.');
		return;
	}
	undef $file;
	my $process = GDACAP::DB::Process->new();
	my $direction = $req->param('direction');
	my $trace;
	try {
		if ($direction eq 'up') {
			$trace = $process->all_ancestors($file_copy_id);
		} elsif ($direction eq 'both') {
			$trace = $process->full_tree($file_copy_id);
		} else {
			$trace = $process->all_descendants($file_copy_id);
		}
	} catch {
		$logger->debug("Error msg is: $_");
	};
	use GraphViz;
	my $g = GraphViz->new(name=>'Pipelin', edge => {fontsize => 8});
	$file = GDACAP::DB::File->new();
	my $file_type;
	foreach (@$trace) {
		$file_type = $file->type($$_{in_copy_id});
		$g->add_node($$_{in_copy_id}, label=>$file_type, URL=>$GDACAP::Web::location.'/project/show_file/?file_copy_id='.$$_{in_copy_id});
		$file_type = $file->type($$_{out_copy_id});
		$g->add_node($$_{out_copy_id}, label=>$file_type, URL=>$GDACAP::Web::location.'/project/show_file/?file_copy_id='.$$_{out_copy_id});
		$g->add_edge($$_{in_copy_id}=>$$_{out_copy_id}, label=>sprintf("%s\n%s\n%s",$$_{name},$$_{category},$$_{tool}));
	}
	my $tpl_setting = {
		template_name => 'process_diagram',
		project_navigation => $project_id, # must pass the project_id for project_navigation to work
	};
	my $template_vars = {
		section_article_id => 'ProcessDiagram',
		header => 'The trace of files - pipeline',
		action => $GDACAP::Web::location.'/process/save',
		svg    => $g->as_svg,
	};
	GDACAP::Web::Page::display($r, $tpl_setting, $template_vars, $person_id);
}

sub save {
	my ($r) = @_;
	my $req = Apache2::Request->new($r);
	my $svg_xml = $req->param("svg_xml");
	$r->err_headers_out->add('Content-Disposition' => 'attachment; filename=pipeline.svg');
	$r->content_type('image/svg+xml');
	print $svg_xml;
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
