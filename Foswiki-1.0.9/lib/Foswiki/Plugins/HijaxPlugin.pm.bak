# Copyright (C) 2010 David Patterson
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::HijaxPlugin;

# Always use strict to enforce variable scoping
use strict;
use JSON;

require Foswiki::Func;    # The plugins API
require Foswiki::Plugins; # For the API version
require Foswiki::Attrs;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $base $defaultsAdded );

$VERSION = '$Rev: 8534 (2010-08-18) $';
$RELEASE = '1.2';
$SHORTDESCRIPTION = 'AJAX integration';
$NO_PREFS_IN_TOPIC = 1;
$base = 999999;
$debug = 0; # toggle me

# Name of this Plugin, only used in this module
$pluginName = 'HijaxPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

	Foswiki::Func::registerTagHandler( 'RAND', \&_handleRandom);

    # $debug = $Foswiki::cfg{Plugins}{HijaxPlugin}{Debug} || 0;
	$defaultsAdded = 0;

    return 1;
}

sub commonTagsHandler {
	addDefaultsToPage();
}

sub addDefaultsToPage {
	return if $defaultsAdded;
	$defaultsAdded = 1;
	Foswiki::Func::addToZone('head','HIJAXPLUGIN_CSS', <<HERE,'JQUERYPLUGIN::THEME');
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/HijaxPlugin/hijax.css" type="text/css" media="all" />
HERE
	Foswiki::Plugins::JQueryPlugin::createPlugin("ui");
	Foswiki::Plugins::JQueryPlugin::createPlugin("hoverIntent");
	my $templates = Foswiki::Func::loadTemplate( 'HijaxPlugin' );
	my $configurableInit = Foswiki::Func::expandTemplate( 'hp_configurable_init' );
	Foswiki::Func::addToZone('body','HIJAXPLUGIN_JS', <<"HERE",'JQUERYPLUGIN::FOSWIKI,JQUERYPLUGIN::BGIFRAME,JQUERYPLUGIN::UI,JQUERYPLUGIN::HOVERINTENT');
$configurableInit
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/HijaxPlugin/json2.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/HijaxPlugin/hijax.js"></script>
HERE
}

sub _handleRandom {
    my( $session, $attrs, $topic, $web ) = @_;
	return int rand($base);
}

sub _noTemplateMessage {
	my $tmpl = shift;
	return "<div class='foswikiAlert'>Warning: a template named $tmpl has not been defined for this interface.</div>";
}

sub completePageHandler {
    #my($html, $httpHeaders) = @_;
    # modify $_[0] or $_[1] if you must change the HTML or headers

    Foswiki::Func::writeDebug( "- ${pluginName}::completePageHandler \n$_[0]" ) if $debug;
	my $query = Foswiki::Func::getCgiQuery();
	return unless $query->param('cover') && $query->param('cover') =~ /ajax/ && $_[0] =~ /%TEMPLATE:/;
		
	my @hijax = ();
	my @tmplp = ();
	if (Foswiki::Func::getContext()->{'login'}) {
		@tmplp = ('content','errorstep');
	} else {
		@hijax = $query->param('hijax') if defined $query->param('hijax');
		@tmplp = $query->param('tmplp') if defined $query->param('tmplp');
		$tmplp[0] = 'content' unless ($hijax[0] || $tmplp[0]); # if nothing else, we return the 'content' tmpl
		unless (grep (/content/,@tmplp)) {
			push (@tmplp,'content') if (Foswiki::Func::expandTemplate('context') =~ /oops/);
		}
	}
	foreach my $tmp (qw(head body context location)) {
		push (@tmplp,$tmp) unless grep (/$tmp/,@tmplp);
	}
	Foswiki::Func::writeDebug( join(",",@tmplp) ) if $debug;
	
	my $response = {}; # the hash we return as JSON
	my ($remainder, $text) = split(/%TEMPLATE:/,$_[0],2);
	
	if ($Foswiki::Plugins::VERSION < 2.1) {
		# need to get the addToZone content added before to_json is called otherwise it won't be json
		Foswiki::Func::writeDebug("HijaxPlugin specifically calling ZonePlugin::completePageHandler") if $debug;
		Foswiki::Plugins::ZonePlugin::completePageHandler($text,$_[1]);
	}

	my @templates = split(/%TEMPLATE:/,$text);
	foreach my $record (@templates) {
		Foswiki::Func::writeDebug( "$record" ) if $debug;
		my ($templateName, $templateText) = split(/%/,$record,2);
		if (grep(/$templateName/, @tmplp)) {
			Foswiki::Func::writeDebug( "$templateName, $templateText" ) if $debug;
			$templateText =~ s/^[\n\r\s]*//;
			$templateText =~ s/[\n\r\s]*$//;
			$response->{$templateName} = $templateText;
			Foswiki::Func::writeDebug( "$templateName, $response->{$templateName}" ) if $debug;
		}
	}
	foreach my $request (@tmplp) {
		$response->{$request} ||= _noTemplateMessage($request);
	}
	foreach my $request (@hijax) {
		if ($request =~ /,/) {
			my @hijaxlist = split(/,/,$request);
			foreach my $hijax (@hijaxlist) {
				render($hijax,$response);
			}
		} else {
			render($request,$response);
		}
	}
	# render('context',$response);
	
	$_[0] = to_json($response);
}

sub render {
	my ($request,$response) = @_;
	my $templatetext = Foswiki::Func::expandTemplate($request);
	if ($templatetext) {
		$templatetext = 
			Foswiki::Func::renderText(Foswiki::Func::expandCommonVariables($templatetext));
	} else {
		$templatetext = _noTemplateMessage($request);
	}
	$templatetext =~ s/<\/?noautolink>//ig;
	$templatetext =~ s/<\/?nop>//ig;
	$response->{$request} = $templatetext;
}

# SMELL: need to replace this whole hack with the use of get/setSessionValue() in initPlugin()
sub redirectCgiQueryHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $response, $url ) = @_;
	my $query = Foswiki::Func::getCgiQuery();
	if ($debug) {
		my $query_string = $query->query_string();
	    Foswiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( $query_string, $_[1] )" );
	}
    return 0 unless $query->param('cover') && $query->param('cover') =~ /ajax/;
	
	# login already has our params in its querystring
	# return 0 if $_[1] =~ /\/login\//;
    # the result of a successful login so leave the core to unpack all the params from the cache
	return 0 if $_[1] =~ /foswiki_(redirect_cache|origin)/ && $_[1] !~ /\/login\//; 
	
	my $append = ($_[1] =~ m/(\?.*)$/) ? ';' : '?';
	$_[1] .= $append.'cover='.$query->param('cover');
	$_[1] .= ';hijax='.join(';hijax=',$query->param('hijax')) if $query->param('hijax');
	$_[1] .= ';tmplp='.join(';tmplp=',$query->param('tmplp')) if $query->param('tmplp');
	if ($query->param('returntemplate') && $_[1] !~ /oops(accessdenied|alerts)/) { 
		$_[1] .= ';template='.$query->param('returntemplate');
	}
	if ($debug) {
		my $query_string = $query->query_string();
	    Foswiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( $query_string, $_[1] )" );
	}
	return 0;
}

1;
