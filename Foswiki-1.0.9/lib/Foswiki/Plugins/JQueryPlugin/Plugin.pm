# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2010 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::Plugin;

use Foswiki::Plugins::JQueryPlugin::Plugins ();

use strict;
use warnings;

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::Plugin

abstract class for a jQuery plugin

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

   * =$class=: Plugin class
   * =$session= : Foswiki object, defaults to =$Foswiki::Plugins::SESSION=
   * =...=: additional properties to be added to the object. i.e. 
      * =name => 'pluginName'= (default unknown)
      * =author => 'pluginAuthor'= (default unknown)
      * =version => 'pluginVersion'= (default unknown)
      * =summary => 'pluginSummary'= (default undefined)
      * =documentation => 'pluginDocumentation'= (default JQuery&lt;Name>)
      * =homepage => 'pluginHomepage'= (default unknown)
      * =debug => 0 or 1= (default =$Foswiki::cfg{JQueryPlugin}{Debug}=)

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    debug => $Foswiki::cfg{JQueryPlugin}{Debug} || 0,
    name => $class,
    author => 'unknown',
    version => 'unknown',
    summary => undef,
    documentation => undef,
    homepage => 'unknown',
    puburl => '',
    css => [],
    javascript => [],
    dependencies => [],
    tags => '',
    @_
  }, $class);

  $this->{documentation} = $Foswiki::cfg{SystemWebName}.'.JQuery'.ucfirst($this->{name})
    unless defined $this->{documentation};

  unless ($this->{puburl}) {
    $this->{puburl} = 
      '%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/'.
      lc($this->{name});
  }


  return $this;
}

=begin TML

---++ ClassMethod init()

add jQuery plugin to web and make sure all its dependencies 
are fulfilled

=cut

sub init {
  my $this = shift;

  return 0 if $this->{isInit};
  $this->{isInit} = 1;

  my $header = '';
  my $footer = '';

  # load all css
  foreach my $css (@{$this->{css}}) {
    $header .= $this->renderCSS($css);
  }

  # load all javascript
  foreach my $js (@{$this->{javascript}}) {
    $footer .= $this->renderJS($js);
  }

  # gather dependencies
  my @dependencies = ('JQUERYPLUGIN::FOSWIKI'); # jquery.foswiki is in there by default
  foreach my $dep (@{$this->{dependencies}}) {
    if ($dep =~ /^JQUERYPLUGIN/) {
      push @dependencies, $dep;
    } else {
      Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin($dep);
      push @dependencies, 'JQUERYPLUGIN::'.uc($dep);
    }
  }

  Foswiki::Func::addToZone('head', "JQUERYPLUGIN::".uc($this->{name}), $header, join(', ', @dependencies))
    if $header;
  Foswiki::Func::addToZone('body', "JQUERYPLUGIN::".uc($this->{name}), $footer, join(', ', @dependencies))
    if $footer;

  return 1;
}

sub renderCSS {
  my ($this, $text) = @_;

  $text =~ s/\.css$/.uncompressed.css/ if $this->{debug};
  $text .= '?version='.$this->{version};
  $text = "<link rel='stylesheet' href='$this->{puburl}/$text' type='text/css' media='all' />\n";

  return $text;
}

sub renderJS {
  my ($this, $text) = @_;

  $text =~ s/\.js$/.uncompressed.js/ if $this->{debug};
  $text .= '?version='.$this->{version};
  $text = "<script src='$this->{puburl}/$text'></script>\n";

  return $text;
}

=begin TML

---++ ClassMethod getSummary()

returns the summary text for this plugin. this is either the =summary= property of the class or the
=summary= section of the plugin's documentation topic. 

=cut

sub getSummary {
  my $this= shift;

  my $summary = $this->{summary};
  
  unless (defined $summary) {
    $summary = 'n/a';
    if ($this->{'documentation'}) {
      $summary = Foswiki::Func::expandCommonVariables('%INCLUDE{"'.$this->{documentation}.'" section="summary" warn="off"}%');
    }

    $this->{summary} = $summary;
  }

  return $summary
}

1;
