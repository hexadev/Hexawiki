#
# Copyright (C) David Patterson 2010 - All rights reserved
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#

# Perl object that represents a set of objects (possibly interleaved
# with blocks of topic text)
package Foswiki::Plugins::FullCalendarPlugin::EventSet;
use Foswiki::Plugins::ObjectPlugin::ObjectSet;
@ISA = qw(Foswiki::Plugins::ObjectPlugin::ObjectSet);

use strict;
use integer;
# use Data::Dumper;
use Foswiki::Func;
require Foswiki::Plugins::ObjectPlugin;

# sub new {
	# my $class = shift;
	# my $this = $class->SUPER::new(@_);
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug(Dumper($this));
	# return $this;
# }

sub load {
	my ($web, $topic, $reltopic) = @_;
	my $setClass = 'Foswiki::Plugins::FullCalendarPlugin::EventSet';
	my $objectClass = 'Foswiki::Plugins::FullCalendarPlugin::Event';
	return Foswiki::Plugins::ObjectPlugin::ObjectSet::load(
		$web, $topic, undef, 'VIEW', 1, 0, $setClass, $objectClass, $reltopic );
}
		
sub dateRangeSearch {
    my ( $web, $topic, $start, $end, $reltopic ) = @_;

    my $chosen = new Foswiki::Plugins::FullCalendarPlugin::EventSet();
	
	my $es = load($web, $topic, $reltopic);
	# Foswiki::Func::writeDebug(Dumper($es));
    foreach my $event ( @{$es->{OBJECTS}} ) {
	# Foswiki::Func::writeDebug(ref($event));
        if ( ref($event) && $event->withinRange( $start, $end ) ) {
			$chosen->add( $event );
        }
    }

    return $chosen;
}

sub expandEvents {
	my ($this, $start, $end, $clone) = @_;
	my $expandedEvents = new Foswiki::Plugins::FullCalendarPlugin::EventSet();
	foreach my $event (@{$this->{OBJECTS}}) {
		$event->setFullCalendarAttrs();
		$event->expand($expandedEvents, $start, $end, $clone);
	}
	return $expandedEvents;
}

1;
