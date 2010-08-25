# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2010 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::DBCachePlugin;

#use Monitor;
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin');
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin::Core');
#Monitor::MonitorMethod('Foswiki::Contrib::DBCachePlugin::WebDB');

use strict;
use vars qw(
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $baseWeb $baseTopic $isInitialized
  $addDependency
);

$VERSION = '$Rev: 8342 (2010-07-28) $';
$RELEASE = '3.50';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Lightweighted frontend to the DBCacheContrib';

###############################################################################
# plugin initializer
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  #  if ($Foswiki::Plugins::VERSION < 1.1) {
  #    return 0;
  #  }

  Foswiki::Func::registerTagHandler('DBQUERY', \&DBQUERY);
  Foswiki::Func::registerTagHandler('DBCALL', \&DBCALL);
  Foswiki::Func::registerTagHandler('DBSTATS', \&DBSTATS);
  Foswiki::Func::registerTagHandler('DBDUMP', \&DBDUMP);    # for debugging
  Foswiki::Func::registerTagHandler('DBRECURSE', \&DBRECURSE);
  Foswiki::Func::registerTagHandler('ATTACHMENTS', \&ATTACHMENTS);
  Foswiki::Func::registerTagHandler('TOPICTITLE', \&TOPICTITLE);
  Foswiki::Func::registerTagHandler('GETTOPICTITLE', \&TOPICTITLE);

  Foswiki::Func::registerRESTHandler('UpdateCache', \&restUpdateCache);
  Foswiki::Func::registerRESTHandler('dbdump', \&restDBDUMP);

  # SMELL: remove this when Foswiki::Cache got into the core
  my $cache = $Foswiki::Plugins::SESSION->{cache}
    || $Foswiki::Plugins::SESSION->{cache};
  if (defined $cache) {
    $addDependency = \&addDependencyHandler;
  } else {
    $addDependency = \&nullHandler;
  }

  $isInitialized = 0;

  return 1;
}

###############################################################################
sub initCore {
  return if $isInitialized;
  $isInitialized = 1;

  eval 'use Foswiki::Plugins::DBCachePlugin::Core;';
  die $@ if $@;

  Foswiki::Plugins::DBCachePlugin::Core::init($baseWeb, $baseTopic);
}

###############################################################################
# REST handler to allow offline cache updates
sub restUpdateCache {
  my $session = shift;
  my $web = $session->{webName};

  my $db = getDB($web);
  $db->load(1) if $db;
}

###############################################################################
# REST handler to debug a topic in cache
sub restDBDUMP {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::restDBDUMP(@_);
}

###############################################################################
# after save handlers
sub afterSaveHandler {
  #my ($text, $topic, $web, $meta) = @_;
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($_[2], $_[1]);
}

###############################################################################
# deprecated: use afterUploadSaveHandler instead
sub afterAttachmentSaveHandler {
  #my ($attrHashRef, $topic, $web) = @_;
  return if $Foswiki::Plugins::VERSION >= 2.1 || 
    $Foswiki::cfg{DBCachePlugin}{UseUploadHandler}; # set this to true if you backported the afterUploadHandler

  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($_[2], $_[1]);
}

###############################################################################
# Foswiki::Plugins::VERSION >= 2.1
sub afterUploadHandler {
  my ($attrHashRef, $meta) = @_;
  my $web = $meta->web;
  my $topic = $meta->topic;
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($web, $topic);
}

###############################################################################
# Foswiki::Plugins::VERSION >= 2.1
sub afterRenameHandler {
  my ($web, $topic, undef, $newWeb, $newTopic) = @_;

  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::afterSaveHandler($web, $topic, $newWeb, $newTopic);
}

###############################################################################
sub renderWikiWordHandler {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::renderWikiWordHandler(@_);
}

###############################################################################
# tags
sub DBQUERY {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleDBQUERY(@_);
}

sub DBCALL {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleDBCALL(@_);
}

sub DBSTATS {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleDBSTATS(@_);
}

sub DBDUMP {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleDBDUMP(@_);
}

sub ATTACHMENTS {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleATTACHMENTS(@_);
}

sub DBRECURSE {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleDBRECURSE(@_);
}

sub TOPICTITLE {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::handleTOPICTITLE(@_);
}

###############################################################################
# perl api
sub getDB {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::getDB(@_);
}

sub getTopicTitle {
  initCore();
  return Foswiki::Plugins::DBCachePlugin::Core::getTopicTitle(@_);
}

###############################################################################
# SMELL: remove this when Foswiki::Cache got into the core
sub nullHandler { }

sub addDependencyHandler {
  my $cache = $Foswiki::Plugins::SESSION->{cache}
    || $Foswiki::Plugins::SESSION->{cache};
  return $cache->addDependency(@_) if $cache;
}

###############################################################################
1;
