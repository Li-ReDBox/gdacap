package GDACAP::Web::Page;

use strict;
use warnings;

use Apache2::RequestRec();    # for $r->content_type
use Data::Dumper;
use Template;

# require Exporter;
# our @ISA=qw(Exporter);
# our @EXPORT=qw(display);

use GDACAP::Web;
use GDACAP::DB::Person ();
use GDACAP::DB::Personrole ();

my $logger;

my $folders = $GDACAP::Web::folders;

sub show_msg {
	my ($r, $header, $msg) = @_;
	my $function_vars = { template_name => 'message', skip_menu => 1, };
	my $template_vars = { header => $header, section_article_id => 'show_msg', message=>$msg };
	display( $r, $function_vars, $template_vars );
}

sub display {
    my ( $r, $function_vars, $template_vars, $person_id ) = @_;
	$logger = $GDACAP::Web::logger;
	# $logger->debug(__PACKAGE__,'::display is called');
	# $logger->debug('$function_vars=',Dumper($function_vars));
	# $logger->debug('$template_vars=',Dumper($template_vars));
    $$template_vars{page_title} = 'Genomic Data Capturer'; # page title
	
	$$template_vars{help_url} = '' unless (exists($$template_vars{help_url})); 
	$$template_vars{logged_in} = {};
    # load menu and login items to hash, skip_menu: for displaying help without menu bar and logged_in_panel
    # if( ! exists($$function_vars{'skip_menu'})){
        # $$template_vars{menu}      = menu($person_id);
        # $$template_vars{logged_in} = logged_in_bar($person_id) if $person_id;
    # } else { $$template_vars{menu} = {}; }
    if( exists($$function_vars{'skip_menu'})){
        $$template_vars{menu} = {};
    } else { 
		$$template_vars{menu}      = menu($person_id);
        $$template_vars{logged_in} = logged_in_bar($person_id) if $person_id;
	}

    # load project navigation if it has been asked to be shown
    if( exists $$function_vars{'project_navigation'} ){    # OBS Needs $function_vars{'project_navigation'} to be the project_id (used when creating the form for the links)
		my $project_id = $$function_vars{'project_navigation'};
         $$template_vars{project_navigation_project_id} = $project_id; # to be able to use the links to point to other projects, a new $vars is used
        $$template_vars{project_navigation} = project_navigation_panel($project_id);
        # $logger->debug(Dumper($$template_vars{project_navigation}));
    } else { $$template_vars{project_navigation} = {}; }
	
	# If no special wrapper is going to be used use the default. Special can be empty string : no wrapper
    $$function_vars{'wrapper'} = 'wrapper.tt2' unless exists($$function_vars{'wrapper'}); # default wrapper 'wrapper.tt2'

    # process with template
	$r->content_type('text/html');
    if( exists $$function_vars{'return_output'} ){
		my $output = '';
        process( $function_vars, $template_vars, \&output );
		return $output;
    } else {
		# $logger->debug('Time to display');
        process( $function_vars, $template_vars );
    }
}

# Prepare menu items for user
# types: not or logged in with different roles
sub menu {
    my ( $person_id ) = @_;
    my %menu;
    if ( $person_id ) { # person loaded, ie user is logged, check if administrator or super administrator
		$menu{2} = { 'Tools' => $GDACAP::Web::location."/tool"	};
		$menu{3} = { 'Create project' => $GDACAP::Web::location."/project/create"	};
        my $role = GDACAP::DB::Personrole->new( $person_id);
        $menu{4} = { 'Projects' => $GDACAP::Web::location."/project/list" } if $role->has_role();
		if ( $role->is_sys_admin() ) {     # is administrator, show this page
				$menu{5} = { 'Person management'   => $GDACAP::Web::location."/person" };
		}
        if ( $role->is_super_admin() ) { # is super administrator, show these pages
            $menu{7} = { 'Edit administrators' => "edit_admins/"   };
            $menu{8} = { 'Organisations'       => "organisations/" };
        }
    } else { # not logged in
        $menu{1} = { 'Login' => $GDACAP::Web::location."/command/login" }; 
	}
    return \%menu;
}

sub logged_in_bar {
    my ( $person_id ) = @_;
	my $per = GDACAP::DB::Person->new(); 	$per->by_id($person_id);
    my %logged_in = (
        user          => $per->user(),
        logout_url      => $GDACAP::Web::location."/command/logout",
        edit_profile_url => $GDACAP::Web::location."/person/update",
    );
    return \%logged_in;
}

sub project_navigation_panel {
	my ($project_id) = @_;
	require GDACAP::DB::Project;
	my $prj = GDACAP::DB::Project->new();
	my $children = $prj->children($project_id);
    my %project_navigation = ( location => $GDACAP::Web::location,
							   samples => $$children{samples},
							   studies => $$children{studies},
							 );
    return \%project_navigation;
}

# $tpl_settings  - a hash ref controls template
# $content  - variables passed to the <Template::process> subroutine
sub process {
    my ( $tpl_settings, $content, $output ) = @_;

	my $folders = $GDACAP::Web::folders;
    my $path = $$folders{resources};

    # add paths to div css, JavaScript, jquery, the number is in what order it will be loaded in the page (loading order 1,2,3,4..)
    my $css = {
        1 => $path . "/css/projectCss.css",
#       2 => $path . "/css/ui-lightness/jquery-ui-1.8.16.custom.css",   # if other ui is wanted instead of smoothness
        3 => $path . "/css/smoothness/jquery-ui-1.8.18.custom.css",     # jquery css
        4 => $path . "/css/tablesorter/style.css",                      # tablesorter css
    };
	# Site js for handling UI, process objects, drag-n-rop, pipeline
    my $javascript = { 1 => $path . "/scripts/projectJavascript.js" };
    my $jquery = {
        1 => $path . "/scripts/jquery-1.7.1.min.js",
        2 => $path . "/scripts/jquery-ui-1.8.16.custom.min.js",         # used for autocomplete
        3 => $path . "/scripts/projectJquery.js",                       # have stuff that hides and shows the autocomplete fields
        4 => $path . "/scripts/jquery.tablesorter.min.js",              # used for adding sort to tables 
    };
    my $images = { 
		logo 		 => $path . "/images/bg-header-logo-ds.png", 
		help         => $path . "/images/help.png",
		info         => $path . "/images/info.png",
		del_no_focus => $path . "/images/del_no_focus.png",
		del_focus    => $path . "/images/del_focus.png",
	};
    
    $content->{'css'}        = $css;
    $content->{'javascript'} = $javascript;
    $content->{'jquery'}     = $jquery;
    $content->{'images'}     = $images;

    # Get template name $tpl_name 
	my $tpl_name = $$tpl_settings{'template_name'}.'.tt2';

	my $config = {
        INCLUDE_PATH => $$folders{template},    # or list ref
        INTERPOLATE  => 1,                               # expand "$var" in plain text
        POST_CHOMP   => 1,                               # cleanup whitespace
        EVAL_PERL    => 1,                               # evaluate Perl code blocks
        WRAPPER      => $$tpl_settings{'wrapper'},
		STRICT => 1,
    };

    my $template = Template->new($config);
    # if( $$tpl_settings{'return_output'} ){ 
	# # if function variable of return_output is passed, return the string instead of print to stdout
        # my $output;
        # $template->process( $tpl_name, $content, \$output ) || die $template->error();
        # return $output;
    # }
	if ($output) {
		$template->process( $tpl_name, $content, \$output ) || die $template->error();
	} else{ # normal case print to stdout
        $template->process( $tpl_name, $content ) || die $template->error();
    }
}

1;

__END__

=head1 NAME

GDACAP::Web::Page - Displays content using template 

=head1 DESCRIPTION

Every Template (C<.tt2> file) loaded in this project uses the ANDS::Moduel::Template module.
That module uses a wrapper (C<wrapper.tt2>) which contains a logged_in bar and a menu.
In this module the links used in the menu and logged_in bar is created here.

=head1 METHODS

=cut

=head2 menu

load_menu_items loads the menu items that is going to be shown for 
the user and stores it in the ANDS::Model::TemplateObjects menu attribute.
The menu contains objects that differs depending on what type of user 
you are so you have to call this subroutine with a person for which 
the menu is going to be create for. The menu it self is rendered in 
the a wrapper template which is decided if it is going to be used in 
the handle_template_loading subroutine in the ANDS::Module::Root.pm module.

=head3 Parameters

=over

=item 1

$p : an ANDS::Model::Person object

=back

=head2 load_logged_in

load_logged_in loads the logged in bars data and stores it in 
the ANDS::Model::TemplateObjects logged_in attribute.
The logged in bar is rendered in the a wrapper template which is 
decided if it is going to be used in the handle_template_loading 
subroutine in the ANDS::Module::Root.pm module.

=head3 Parameters

=over

=item 1

$p : an ANDS::Model::Person object

=back

=head2 load_project_navigation

load_project_navigation loads the data needed for the project navigation link
and stores it in the ANDS::Model::TemplateObjects project_navigation attribute.

The project navigation is a navigation field shown in the right bottom corner
of the window on the project related views (where you handle data that is related
to only one project).

For this to work the wrapper template need the project_id passed to it in the field
project_navigation_project_id. This to be able to create the links that are used.

=head2 display($tpl_settings, $content)

 Display or reutrn content with template (C<.tt2> ) 
 - variables controls the preparation of template
 - content

if $tpl_settings{'return_output'} is set it will return result as a string instead of display to client directly.
 
=head1 AUTHORS

Andor Lundgren 

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

