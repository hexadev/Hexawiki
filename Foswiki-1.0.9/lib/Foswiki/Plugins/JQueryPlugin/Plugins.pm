# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

package Foswiki::Plugins::JQueryPlugin::Plugins;
use strict;
use warnings;

our @iconSearchPath;
our %iconCache;
our %plugins; # all singletons
our $debug;
our $currentTheme;

use Foswiki::Func;

BEGIN { 
  srand() if $] < 5.004 
}

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin

Container for jQuery and plugins

=cut

=begin TML

---++ init()

initialize plugin container

=cut

sub init () {

  $debug = $Foswiki::cfg{JQueryPlugin}{Debug} || 0;
  $currentTheme = undef;

  foreach my $pluginName (sort keys %{$Foswiki::cfg{JQueryPlugin}{Plugins}}) {
    registerPlugin($pluginName)
      if $Foswiki::cfg{JQueryPlugin}{Plugins}{$pluginName}{Enabled};
  }

  # load jquery
  my $jQuery = $Foswiki::cfg{JQueryPlugin}{JQueryVersion} || "jquery-1.3.2";
  $jQuery .= ".uncompressed" if $debug;
  my $footer = "<script src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$jQuery.js'></script>";

  # switch on noconflict mode
  $footer .= "\n<script src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery.noconflict.js'></script>"
    if $Foswiki::cfg{JQueryPlugin}{NoConflict};

  Foswiki::Func::addToZone('body', 'JQUERYPLUGIN', $footer);

  # initial plugins
  createPlugin('Foswiki'); # this one is needed anyway

  my $defaultPlugins = $Foswiki::cfg{JQueryPlugin}{DefaultPlugins};
  if ($defaultPlugins) {
    foreach my $pluginName (split(/\s*,\s*/, $defaultPlugins)) {
      createPlugin($pluginName);
    }
  }

}

=begin TML

---++ ObjectMethod createPlugin( $pluginName, ... ) -> $plugin 

Helper method to establish plugin dependencies. See =load()=.

=cut

sub createPlugin {
  my $plugin = load(@_);
  $plugin->init() if $plugin;
  return $plugin;
}

=begin TML

---++ ObjectMethd createTheme ($themeName)

Helper method to switch on the given theme (default =base=).

=cut

sub createTheme {
  my $themeName = shift;

  return $currentTheme if defined $currentTheme;

  $themeName ||= 'base';
  $currentTheme = $themeName;

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::THEME", <<"HERE", "JQUERYPLUGIN::FOSWIKI");
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/themes/$themeName/ui.all.css" type="text/css" media="all" />
HERE

  return $themeName;
}


=begin TML

---++ ObjectMethod registerPlugin( $pluginName, $class ) -> $descriptor

Helper method to register a plugin.

=cut

sub registerPlugin {
  my ($pluginName, $class) = @_;

  $class ||= 'Foswiki::Plugins::JQueryPlugin::'.uc($pluginName);

  return $plugins{lc($pluginName)} = {
    'class' => $class,
    'name' => $pluginName,
    'instance' => undef,
  };
}

=begin TML

finalizer

=cut

sub finish {

  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = $query->param('refresh') || '';

  if ($Foswiki::cfg{JQueryPlugin}{MemoryCache} && $refresh ne 'on') {
    foreach my $key (keys %plugins) {
      my $pluginDesc = $plugins{$key};
      $pluginDesc->{instance}->{isInit} = 0 if $pluginDesc->{instance};
    }
  } else {
    undef %plugins;
    undef @iconSearchPath;
    undef %iconCache;
  }
}

=begin TML

---++ ObjectMethod load ( $pluginName ) -> $plugin

Loads a plugin and runs its initializer. 

parameters
   * =$pluginName=: name of plugin

returns
   * =$plugin=: returns the plugin object or false if instantiating
     the plugin failed

=cut

sub load {
  my $pluginName = shift;

  my $normalizedName = lc($pluginName);
  my $pluginDesc = $plugins{$normalizedName};

  return undef unless $pluginDesc;

  unless (defined $pluginDesc->{instance}) {

    eval "use $pluginDesc->{class};";

    if ($@) {
      print STDERR "ERROR: can't load jQuery plugin $pluginName: $@\n";
      $pluginDesc->{instance} = 0;
    } else {
      $pluginDesc->{instance} = $pluginDesc->{class}->new();
    }
  }

  return $pluginDesc->{instance};
}


=begin TML

---++ ObjectMethod expandVariables( $format, %params) -> $string

Helper function to expand standard escape sequences =$percnt=, =$nop=,
=$n= and =$dollar=. 

   * =$format=: format string to be expaneded
   * =%params=: optional hash array containing further key-value pairs to be
     expanded as well, that is all occurences of =$key= will 
     be replaced by its =value= as defined in %params
   * =$string=: returns the resulting text 

=cut


sub expandVariables {
  my ($format, %params) = @_;

  return '' unless $format;
  
  foreach my $key (keys %params) {
    my $val = $params{$key};
    $val = '' unless defined $val;
    $format =~ s/\$$key\b/$val/g;
  }
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$nop//g;
  $format =~ s/\$n/\n/go;
  $format =~ s/\$dollar/\$/go;

  return $format;
}


=begin TML

---++ ObjectMethod getIconUrlPath ( $iconName ) -> $pubUrlPath

Returns the path to the named icon searching along a given icon search path.
This path can be in =$Foswiki::cfg{JQueryPlugin}{IconSearchPath}= or will fall
back to =FamFamFamSilkIcons=, =FamFamFamSilkCompanion1Icons=,
=FamFamFamFlagIcons=, =FamFamFamMiniIcons=, =FamFamFamMintIcons= As you see
installing Foswiki:Extensions/FamFamFamContrib would be nice to have.

   = =$iconName=: name of icon; you will have to know the icon name by heart as listed in your
     favorite icon set, meaning there's no mapping between something like "semantic" and "physical" icons
   = =$pubUrlPath=: the path to the icon as it is attached somewhere in your wiki or the empty
     string if the icon was not found

=cut

sub getIconUrlPath {
  my ($iconName) = @_;

  return '' unless $iconName;

  unless (@iconSearchPath) {
    my $iconSearchPath = 
      $Foswiki::cfg{JQueryPlugin}{IconSearchPath}
      || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
    @iconSearchPath = split(/\s*,\s*/, $iconSearchPath);
  }

  $iconName =~ s/^.*\.(.*?)$/$1/; # strip file extension

  my $iconPath = $iconCache{$iconName};

  unless ($iconPath) {
    my $iconWeb = $Foswiki::cfg{SystemWebName};
    my $pubSystemDir = $Foswiki::cfg{PubDir}.'/'.$Foswiki::cfg{SystemWebName};

    foreach my $item (@iconSearchPath) {
      my ($web, $topic) = 
        Foswiki::Func::normalizeWebTopicName($Foswiki::cfg{SystemWebName}, $item);

      # SMELL: store violation assumes the we have got file-level access
      # better use store api
      my $iconDir = $Foswiki::cfg{PubDir}.'/'.$web.'/'.$topic.'/'.$iconName.'.png';
      if (-f $iconDir) {
        $iconPath = Foswiki::Func::getPubUrlPath().'/'.$web.'/'.$topic.'/'.$iconName.'.png';
        last; # first come first serve
      }
    }
   
    $iconPath ||= '';
    $iconCache{$iconName} = $iconPath;
  }

  return $iconPath;
}

=begin TML

---++ ClassMethod getPlugins () -> @plugins

returns a list of all known plugins

=cut

sub getPlugins {
  my ($include) = @_;

  my @plugins = ();
  foreach my $key (sort keys %plugins) {
    next if $key eq 'empty'; # skip this one
    next if $include && $key !~ /^($include)$/;
    my $pluginDesc = $plugins{$key};
    my $plugin = load($pluginDesc->{name});
    push @plugins, $plugin if $plugin;
  }

  return @plugins;
}

=begin TML

---++ ClassMethod getRandom () -> $integer

returns a random positive integer between 1 and 10000. 
this can be used to
generate html element IDs which are not
allowed to clash within the same html page,
even not when it got extended via ajax.

=cut

sub getRandom {
  return int(rand(10000)) +1;
}

1;
