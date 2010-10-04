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

package Foswiki::Plugins::JQueryPlugin::NIFTY;
use Foswiki::Func ();
use strict;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::NIFTY

This is the perl stub for the jquery.nifty plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'Nifty',
    version => '2.0',
    author => 'Paul Bakaus, Alessandro Fulciniti',
    homepage => 'http://...',
    css => ['jquery.nifty.css', 'jquery.rounded.css'],
    javascript => ['jquery.nifty.js', 'jquery.rounded.js'],
  ), $class);

  $this->{summary} = <<'HERE';
%RED%DEPRECATED%ENDCOLOR%

Nifty for jQuery is a modified and optimized version of Nifty Corners Cube.
The new one has been programmed by Paul Bakaus (paul.bakaus@gmail.com).

Nifty Corners Cube - rounded corners with CSS and Javascript
Copyright 2006 Alessandro Fulciniti (a.fulciniti@html.it)
HERE

  Foswiki::Func::writeWarning("the jquery.nifty plugin is deprecated. please use jquery.corner");

  return $this;
}

1;

