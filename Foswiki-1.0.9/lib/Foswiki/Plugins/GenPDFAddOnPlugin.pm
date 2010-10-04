# See bottom of file for default license and copyright information

=begin TML

---+ package GenPDFAddOnPlugin

Foswiki plugins 'listen' to events happening in the core by registering an
interest in those events. They do this by declaring 'plugin handlers'. These
are simply functions with a particular name that, if they exist in your
plugin, will be called by the core.

This is an empty Foswiki plugin. It is a fully defined plugin, but is
disabled by default in a Foswiki installation. Use it as a template
for your own plugins.

To interact with Foswiki use ONLY the official APIs
documented in %SYSTEMWEB%.DevelopingPlugins. <strong>Do not reference any
packages, functions or variables elsewhere in Foswiki</strong>, as these are
subject to change without prior warning, and your plugin may suddenly stop
working.

Error messages can be output using the =Foswiki::Func= =writeWarning= and
=writeDebug= functions. You can also =print STDERR=; the output will appear
in the webserver error log. Most handlers can also throw exceptions (e.g.
[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::OopsException][Foswiki::OopsException]])

For increased performance, all handler functions except =initPlugin= are
commented out below. *To enable a handler* remove the leading =#= from
each line of the function. For efficiency and clarity, you should
only uncomment handlers you actually use.

__NOTE:__ When developing a plugin it is important to remember that

Foswiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %SYSTEMWEB%.InstalledPlugins for error messages.

__NOTE:__ Foswiki:Development.StepByStepRenderingOrder helps you decide which
rendering handler to use. When writing handlers, keep in mind that these may
be invoked

on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the =afterCommonTagsHandler= is run.
After that point in the rendering loop we have lost the information that
the text had been included from another topic.

=cut

# change the package name!!!
package Foswiki::Plugins::GenPDFAddOnPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
# This should always be $Rev: 7410 (2010-05-14) $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev: 7410 (2010-05-14) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '1.2';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'<nop>GenPDFAddOnPlugin helper plugin for GenPDFAddOn renders the %<nop>GENPDF% tag';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries set in =LocalSite.cfg=, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{GenPDFAddOnPlugin}{ExampleSetting} = 1;
    # Optional: See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

 # Always provide a default in case the setting is not defined in
 # LocalSite.cfg. See %SYSTEMWEB%.Plugins for help in adding your plugin
 # configuration to the =configure= interface.
 # my $setting = $Foswiki::cfg{Plugins}{GenPDFAddOnPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'GENPDF', \&_GENPDF );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
sub _GENPDF {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

 #    # $session  - a reference to the Foswiki session object (if you don't know
 #    #             what this is, just ignore it)
 #    # $params=  - a reference to a Foswiki::Attrs object containing
 #    #             parameters.
 #    #             This can be used as a simple hash that maps parameter names
 #    #             to values, with _DEFAULT being the name for the default
 #    #             (unnamed) parameter.
 #    # $theTopic - name of the topic in the query
 #    # $theWeb   - name of the web in the query
 #    # Return: the result of processing the macro. This will replace the
 #    # macro call in the final text.
 #
 #    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
 #    # $params->{_DEFAULT} will be 'hamburger'
 #    # $params->{sideorder} will be 'onions'

    my $context = Foswiki::Func::getContext();
    return
      unless $context->{
              'view'};    # Don't render the tag in preview or other operations.

    #   If a topic name is provided, use it instead of the current topic
    #
    if ( $params->{_DEFAULT} ) {
        ( $theWeb, $theTopic ) =
          Foswiki::Func::normalizeWebTopicName( '', $params->{_DEFAULT} );
    }

    #   Link text - if provided,
    my $p1 = '';
    my $p2 = '';
    if ( $params->{link} ) {
        $p1 = '[[';
        $p2 = "][$params->{link}]]";
    }

 #   Extract the query string to pass along any parmeters to the rendered topic.

    my $qs = Foswiki::Func::expandCommonVariables('%QUERYSTRING%');
    $qs = ( $qs eq '' ) ? $qs : '?' . $qs;

    #   Expand the URL
    my $tag2 = Foswiki::Func::expandCommonVariables(
        '%SCRIPTURL{"genpdf"}%/' . $theWeb . '/' . $theTopic . "$qs" );

    return "$p1$tag2$p2";
}

1;
__END__
This copyright information applies to the GenPDFAddOnPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# GenPDFAddOnPlugin is Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This license applies to GenPDFAddOnPlugin *and also to any derivatives*
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
