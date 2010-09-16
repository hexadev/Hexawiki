#
# Copyright (C) 2010 David Patterson
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
package Foswiki::Plugins::FullCalendarPlugin;

use strict;
use Assert;
use Error qw( :try );
# use Data::Dumper;
use Date::Calc qw( Date_to_Days Add_Delta_Days );

require Foswiki::Func;
require Foswiki::Plugins;
require Foswiki::Plugins::ObjectPlugin;
require Foswiki::Plugins::ObjectPlugin::ObjectSet;
require Foswiki::Plugins::ObjectPlugin::Object;
require Foswiki::Plugins::FullCalendarPlugin::EventSet;
require Foswiki::Plugins::FullCalendarPlugin::Event;
require Foswiki::Time;
require Foswiki::OopsException;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug );
$debug = 0; # toggle me
$VERSION = '$Rev: 8457 (2010-08-11) $';
$RELEASE = '1.0';
$SHORTDESCRIPTION = 'Web 2.0 calendar app';

my %months = ( '01'=>'Jan', '02'=>'Feb', '03'=>'Mar', '04'=>'Apr', '05'=>'May', '06'=>'Jun', 
                    '07'=>'Jul', '08'=>'Aug', '09'=>'Sep', '10'=>'Oct', '11'=>'Nov', '12'=>'Dec' );

sub initPlugin {

    # COVERAGE OFF standard plugin code

    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ObjectPlugin and Plugins.pm $Foswiki::Plugins::VERSION. 1.026 required.' );
    }
    # COVERAGE ON

	Foswiki::Func::registerRESTHandler( 'edit', \&_editEventRESTHandler );
	Foswiki::Func::registerRESTHandler( 'events', \&_eventsRESTHandler );
	Foswiki::Func::registerRESTHandler( 'form', \&_eventFormRESTHandler );
	Foswiki::Func::registerTagHandler( 'FULLCALENDAR', \&_handleFullCalendar, 'context-free');
    # $debug = $Foswiki::cfg{Plugins}{ObjectPlugin}{Debug} || 1;
    return 1;
};

sub _handleFullCalendar {
    my( $session, $attrs, $topic, $web ) = @_;

	my $calendartopic = $attrs->{_DEFAULT} || $attrs->{calendartopic} || 'WebCalendar';
	$calendartopic =~ s/\s*//;
	my ($cw, $ct) = Foswiki::Func::normalizeWebTopicName($web, $calendartopic);
	$calendartopic = "$cw.$ct";
	my $reltopic = $attrs->{reltopic} || $topic;
	my ($rw, $rt) = Foswiki::Func::normalizeWebTopicName($web, $reltopic);
	$reltopic = "$rw.$rt" eq $calendartopic ? '' : "$rw.$rt";
	my $viewall = $attrs->{viewall} || '';
	my $templates = Foswiki::Func::loadTemplate( 'FullCalendarEvent' );
	my $fcpCSS = Foswiki::Func::expandTemplate( 'fcpCSS' );
	my $fcpJS = Foswiki::Func::expandTemplate( 'fcpJS' );
	my $rand = int rand(999999);
	my $calendar = <<"HERE";
<noautolink>
%ADDTOZONE{"head" requires="JQUERYPLUGIN::THEME" text="$fcpCSS"}%
<div id="calendar$rand" class="fcp_calendar"></div>
%ADDTOZONE{"body" requires="HIJAXPLUGIN_JS" text="$fcpJS
<script type='text/javascript'>
jQuery(function(){
	foswiki.FullCalendar.init('#calendar$rand','$calendartopic','$reltopic','$viewall');
});
</script>"}%
</noautolink>
HERE
	return $calendar;
}

sub parseISOdate {
	my $date = shift;
    if ($date =~ /(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[-+]\d\d(?::\d\d)?)?/ ) {
        my $dateObj = {
			Y => $1, 
			M => $2||1,
			D => $3||1, 
			h => $4||0, 
			m => $5||0, 
			s => $6||0, 
			tz => $7||'',
			fulldate => $date
		};
		$dateObj->{date} = "$dateObj->{Y}-$dateObj->{M}-$dateObj->{D}";
		$dateObj->{days} = Date_to_Days($dateObj->{Y}, $dateObj->{M}, $dateObj->{D});
		return $dateObj;
	}
	return undef;
}

sub getMatchingActions {
	my ($start, $end, $web) = @_;
	
	require Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
	require Foswiki::Plugins::ActionTrackerPlugin::Action;
	my $due = '<'.sprintf('%.4u/%.2u/%.2u',$end->{Y},$end->{M},$end->{D});
	my $attrs = {
		web => $web,
		topic => 'WebActions',
		due => $due,
		state => "open"
	};
	# writeDebug(Dumper($attrs));
	my $actions = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb( $web, $attrs, 0 );
	# writeDebug(Dumper($actions));
	my $os = [];
	foreach my $action (@{$actions->{ACTIONS}}) {
		my $object = {};
		$object->{id} = $action->{uid};
		$object->{className} = 'action';
		$object->{allDay} = 1;
		$object->{start} = $action->{due};
		$object->{title} = "$action->{who}";
		$object->{editable} = 0;
		foreach my $key (keys %$action) {
			$object->{$key} = $action->{$key};
		}
		push(@{$os},$object);
	}
	# writeDebug(Dumper($os));
	return $os;
}

sub _eventsRESTHandler {
    my( $session ) = @_;
	return Foswiki::Plugins::ObjectPlugin::objectResponse($session,\&_dateRangeSearch);
}

sub _editEventRESTHandler {
    my $session = shift;
	return Foswiki::Plugins::ObjectPlugin::objectResponse($session,\&_eventEdit);
}

sub _eventFormRESTHandler {
    my $session = shift;
	my $templates = Foswiki::Func::loadTemplate( 'FullCalendarEvent' );
	my $form = Foswiki::Func::expandTemplate( 'eventForm' );
    return Foswiki::Func::renderText(Foswiki::Func::expandCommonVariables($form));
}

sub _findSingleEvent {
    my ( $web, $topic, $uid ) = @_;

    my $es = Foswiki::Plugins::FullCalendarPlugin::EventSet::load($web, $topic);

    foreach my $event (@{$es->{OBJECTS}}) {
        if (ref($event)) {
            if ($event->{uid} eq $uid) {
				return $event;
			}
        }
    }
	return {}; # no match
}

sub _dateRangeSearch {
	my ($web, $topic, $query) = @_;

	my $start = $query->param('start');
	my $end = $query->param('end');
	my $reltopic = $query->param('reltopic') || '';
	my $calendartopic = $query->param('calendartopic');
	($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $calendartopic);
	# writeDebug("$start $end");
	$start = Foswiki::Time::formatTime($start, 'iso');
	$end = Foswiki::Time::formatTime($end, 'iso');
	writeDebug("$start $end $topic");
	my $es = Foswiki::Plugins::FullCalendarPlugin::EventSet::dateRangeSearch( $web, $topic, $start, $end, $reltopic );
	# writeDebug(Dumper(@{$es->{OBJECTS}}));
	my $startObj = parseISOdate($start);
	my $endObj = parseISOdate($end);
	if (scalar @{$es->{OBJECTS}}) {
		# store an array of year,month pairs that we want events for in the startObj
		# the chronological order of the pairs is important
		if ($startObj->{D} == 1) {
			my ($prevY, $prevM, $prevD) = Add_Delta_Days($startObj->{Y},$startObj->{M},1,-1);
			push(@{$startObj->{ympair}},"$prevY,$prevM");
		}
		# writeDebug(Dumper($startObj));
		push(@{$startObj->{ympair}},"$startObj->{Y},$startObj->{M}");
		# writeDebug(Dumper($startObj));
		if (($endObj->{days} - $startObj->{days}) > 8 && $startObj->{D} > 1) { 
			# we're looking at a month view with multiple months in view, let's add the middle/main month to the ympair array
			my $month = $startObj->{M} + 1;
			my $year;
			if ($month == 13) {
				$year = $startObj->{Y} + 1;
				$month = 1;
			} else {
				$year = $startObj->{Y};
			}
			push(@{$startObj->{ympair}},"$year,$month");
		}
		# writeDebug(Dumper($startObj));
		if ($startObj->{M} != $endObj->{M} && $endObj->{D} != 1) {
			push(@{$startObj->{ympair}},"$endObj->{Y},$endObj->{M}");
		}
		# writeDebug(Dumper($startObj));
		$es = $es->expandEvents($startObj,$endObj,$query->param('asobject'));
	}
	# the next two lines are commented out because they should be configurable via configure
	# my $actions = getMatchingActions($startObj,$endObj,$web);
	# push(@{$es->{OBJECTS}},@{$actions});
	# writeDebug('expanded objects with actions - '.Dumper($es->{OBJECTS}));
	# if (scalar @{$es->{OBJECTS}}) {
		return $es;
	# } else {
		# throw Foswiki::OopsException('fullcalendar',
									# def => 'noeventsfound',
									# web => $web,
									# topic => $topic,
									# params => [ $start, $end, "$web.$topic" ] );
	# }
}

sub _eventEdit {
	my ($web, $topic, $query) = @_;
	my $uid = $query->param('uid');
	my ($event, $pre, $post, $meta) = Foswiki::Plugins::ObjectPlugin::ObjectSet::loadToFind(
		$uid, $web, $topic, undef, 'VIEW', 0, 'Foswiki::Plugins::FullCalendarPlugin::Event' );
	# my $event = _findSingleEvent($web, $topic, $uid);
	if (defined $event) {
		# expand the found event to match the date on which it was selected in the calendar
		# - like a mini dateRangeSearch
		my $start = $query->param('start');
		my $end = $query->param('end');
		# writeDebug("$start $end");
		$start = Foswiki::Time::formatTime($start, 'iso');
		$end = Foswiki::Time::formatTime($end, 'iso');
		my $startObj = parseISOdate($start);
		my $endObj = parseISOdate($end);
		push(@{$startObj->{ympair}},"$startObj->{Y},$startObj->{M}");
		$event->setFullCalendarAttrs();
		my $eventSet = new Foswiki::Plugins::FullCalendarPlugin::EventSet();
		$event->expand($eventSet, $startObj, $endObj, $query->param('asobject'));
		if (scalar @{$eventSet->{OBJECTS}}) {
			return $eventSet->{OBJECTS}[0];
		} else {
			throw Foswiki::OopsException('fullcalendar',
										def => 'noeventdatematch',
										web => $web,
										topic => $topic,
										params => [ $uid, "$startObj->{D} $months{$startObj->{M}} $startObj->{Y}" ] );
		}
	} else {
		throw Foswiki::OopsException('object',
									def => 'noobjectuid',
									web => $web,
									topic => $topic,
									params => [ $uid, "$web.$topic" ] );
	}
}

sub writeDebug {
	Foswiki::Func::writeDebug("FullCalendarPlugin - $_[0]") if $debug;
}

1;
