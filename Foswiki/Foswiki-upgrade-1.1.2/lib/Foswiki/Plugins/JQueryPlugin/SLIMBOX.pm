# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::SLIMBOX;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::SLIMBOX

This is the perl stub for the slimbox2 plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name         => 'Slimbox',
            version      => '2.04',
            author       => 'Christophe Beyls',
            homepage     => 'http://code.google.com/p/slimbox/',
            css          => ['slimbox2.css'],
            javascript   => [ 'slimbox2.js', 'slimbox2.init.js' ],
            dependencies => [ 'metadata', 'livequery' ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the page

=cut

sub init {
    my $this = shift;

    return unless $this->SUPER::init();

    # add translations to head
    my $counterText = $this->{session}->i18n->maketext("Image [_1] of [_2]", "{x}", "{y}");
    Foswiki::Func::addToZone("head", "JQUERYPLUGIN::SLIMBOX::COUNTERTEXT", '<meta name="foswiki.ImagePlugin.counterText" content="'.$counterText.'" />');
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2006-2010 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
