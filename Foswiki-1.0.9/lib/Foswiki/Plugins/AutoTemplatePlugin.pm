# Plugin for Foswiki
#
# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
# All Rights Reserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# This piece of software is licensed under the GPLv2.

package Foswiki::Plugins::AutoTemplatePlugin;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION
  $debug $isEditAction
  $pluginName $NO_PREFS_IN_TOPIC 
);

$VERSION = '$Rev: 6286 (2010-02-12) $';
$RELEASE = '1.1';
$SHORTDESCRIPTION = 'Automatically sets VIEW_TEMPLATE and EDIT_TEMPLATE';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoTemplatePlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get configuration
    my $modeList = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Mode} || "rules, exist";
    my $override = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Override} || 0;
    $debug = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Debug} || 0;

    # is this an edit action?
    $isEditAction   = Foswiki::Func::getContext()->{edit};
    my $templateVar = $isEditAction?'EDIT_TEMPLATE':'VIEW_TEMPLATE';

    # back off if there is a view template already and we are not in override mode
    my $currentTemplate = Foswiki::Func::getPreferencesValue($templateVar);
    return 1 if $currentTemplate && !$override;

    # check if this is a new topic and - if so - try to derive the templateName from
    # the WebTopicEditTemplate
    # SMELL: templatetopic and formtemplate from url params come into play here as well
    if (!Foswiki::Func::topicExists($web, $topic)) {
      if (Foswiki::Func::topicExists($web, 'WebTopicEditTemplate')) {
        $topic = 'WebTopicEditTemplate';
      } else {
        return 1;
      }
    }

    # get it
    my $templateName = "";
    foreach my $mode (split(/\s*,\s*/, $modeList)) {
      if ( $mode eq "section" ) {
        $templateName = _getTemplateFromSectionInclude( $web, $topic );
      } elsif ( $mode eq "exist" ) {
        $templateName = _getTemplateFromTemplateExistence( $web, $topic );
      } elsif ( $mode eq "rules" ) {
        $templateName = _getTemplateFromRules( $web, $topic );
      }
      last if $templateName;
    }

    # only set the view template if there is anything to set
    return 1 unless $templateName;

    # in edit mode, try to read the template to check if it exists
    if ($isEditAction && !Foswiki::Func::readTemplate($templateName)) {
      Foswiki::Func::writeDebug("- ${pluginName}: edit tempalte not found") if $debug;
      return 1;
    }

    # do it
    if ($debug) {
      if ( $currentTemplate ) {
        if ( $override ) {
          Foswiki::Func::writeDebug("- ${pluginName}: $templateVar already set, overriding with: $templateName");
        } else {
          Foswiki::Func::writeDebug("- ${pluginName}: $templateVar not changed/set.");
        }
      } else {
        Foswiki::Func::writeDebug("- ${pluginName}: $templateVar set to: $templateName");
      }
    }
    if ($Foswiki::Plugins::VERSION >= 2.1 ) {
      Foswiki::Func::setPreferencesValue($templateVar, $templateName);
    } else {
      $Foswiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION', { $templateVar => $templateName } );
    }

    # Plugin correctly initialized
    return 1;
}

sub _getFormName {
    my ($web, $topic) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my $form;
    $form = $meta->get("FORM") if $meta;
    $form = $form->{"name"} if $form;

    return $form;
}

sub _getTemplateFromSectionInclude {
    my ($web, $topic) = @_;

    my $formName = _getFormName($web, $topic);
    return unless $formName;

    Foswiki::Func::writeDebug("- ${pluginName}: called _getTemplateFromSectionInclude($formName, $topic, $web)") if $debug;

    my ($formweb, $formtopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

    # SMELL: This can be done much faster, if the formdefinition topic is read directly
    my $sectionName = $isEditAction?'edittemplate':'viewtemplate';
    my $templateName = "%INCLUDE{ \"$formweb.$formtopic\" section=\"$sectionName\"}%";
    $templateName = Foswiki::Func::expandCommonVariables( $templateName, $topic, $web );

    return $templateName;
}

# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate if it exists otherwise nothing
sub _getTemplateFromTemplateExistence {
    my ($web, $topic) = @_;

    my $formName = _getFormName($web, $topic);
    return unless $formName;

    Foswiki::Func::writeDebug("- ${pluginName}: called _getTemplateFromTemplateExistence($formName, $topic, $web)") if $debug;
    my ($templateWeb, $templateTopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

    $templateWeb =~ s/\//\./go;
    my $templateName = $templateWeb.'.'.$templateTopic;
    $templateName =~ s/Form$//;
    $templateName .= $isEditAction?'Edit':'View';

    return $templateName;
}

sub _getTemplateFromRules {
    my ($web, $topic) = @_;

    my $rules = $isEditAction?
      $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{EditTemplateRules}:
      $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{ViewTemplateRules};

    return unless $rules;

    # check full qualified topic name first
    foreach my $pattern (keys %$rules) {
      return $rules->{$pattern} if "$web.$topic" =~ /^($pattern)$/;
    }
    # check topic name only
    foreach my $pattern (keys %$rules) {
      return $rules->{$pattern} if $topic =~ /^($pattern)$/;
    }

    return;
}

1;
