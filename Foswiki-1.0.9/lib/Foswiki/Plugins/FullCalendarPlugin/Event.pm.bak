# See bottom of file for copyright and license information

=begin pod

---+ package Foswiki::Plugins::FullCalendarPlugin::Event

Object that represents a single calendar event

=cut

package Foswiki::Plugins::FullCalendarPlugin::Event;
use Foswiki::Plugins::ObjectPlugin::Object;
@ISA = qw(Foswiki::Plugins::ObjectPlugin::Object);

use strict;
use integer;

require Time::ParseDate;

require Foswiki::Func;

use Date::Calc qw(:all);
# use Data::Dumper;

# sub new {
	# my $class = shift;
	# $class = ref($class) || $class;
	# my $this = $class->SUPER::new(@_);
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug(Dumper($this));
	# return $this;
# }

sub withinRange {
	my ($this, $start, $end) = @_;
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug(Dumper($this)." ".$start." ".$end);
	return 1 if (($this->{startDate} lt $end) && (($this->{rangeEnd} eq '') || ($this->{rangeEnd} ge $start)));
	return 0;
}

sub setFullCalendarAttrs {
	my $this = shift;
	$this->{id} = $this->{uid};
	$this->{category} ||= 'external';
	$this->{className} = $this->{category};
	$this->{editable} = 0 if $this->{category} eq 'external';
	$this->{allDay} += 0;
	$this->{title} ||= 'no title'; # one of the required fields in an FC Event Object
}

sub addTo {
	my ($this, $os, $clone) = @_;
	if ($this->{durationDays}) {
		$this->{start} =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/;
		my ($Y, $M, $D) = Add_Delta_Days($1, $2, $3, $this->{durationDays});
		$this->{end} = sprintf('%.4u-%.2u-%.2u',$Y,$M,$D);
	} else {
		$this->{end} = $this->{start};
	}
	$this->{start} .= "T$this->{startTime}";
	$this->{end} .= "T$this->{endTime}";

	if ($clone) {
		# can't get the JSON blessed object handling to work properly here, 
		# - when doing it for an array of objects - single objects seem to work though, hence TO_JSON in Object.pm -
		# so let's just do the unblessing here and now
		$os->add($this->forJSON());
	} else {
		$os->add($this);
	}
}

sub forJSON {
	my $this = shift;
	my $new = {};
	my $types = $this->{oDef}->{types};
	foreach my $key (keys %$this) {
		# return everything unless specifically told not to
		next if $types->{$key} =~ /noload/;
		$new->{$key} = $this->{$key} if defined $this->{$key};
	}
	return $new;
}

sub safeDateToDays {
	my ($Y, $M, $D) = @_;
	my $days = Days_in_Month($Y, $M);
	Foswiki::Plugins::FullCalendarPlugin::writeDebug("before: $Y $M $D $days");		
	$D = $D > $days ? $days : $D;
	Foswiki::Plugins::FullCalendarPlugin::writeDebug("after: $Y $M $D $days");		
	return Date_to_Days($Y, $M, $D);
}

sub ddDays {
	my ($Y, $M, $D) = @_;

	my $days = Days_in_Month($Y, $M);
	$D = $D > $days ? $days : $D;
	return (Date_to_Days($Y, $M, $D), $Y, $M, $D);
}

sub ndowDays {
	my ($this, $year, $month) = @_;
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("ndowDays - ".Dumper($this));
	
	my $dow = @{$this->{dow}}[0];
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("ndowDays dow $dow");
	my $n = $this->{nth};
	# $dow = $daysofweek{$dow};
	my ($Y, $M, $D);
	do {
		($Y, $M, $D) = Nth_Weekday_of_Month_Year($year, $month, $dow, $n--); 
	} until ($Y); # some months will not have a 5th Monday, for example, so give the last Monday in the month

	return (Date_to_Days($Y, $M, $D), $Y, $M, $D);
}

# not using Ldow anymore -> ndow with nth = 5
sub ldowDays {
	my ($this, $year, $month) = @_;

	my $dow = @{$this->{dow}}[0];
	my $n = 5;
	my ($Y, $M, $D);
	do {
		($Y, $M, $D) = Nth_Weekday_of_Month_Year($year, $month, $dow, $n--); 
	} until ($Y);

	return (Date_to_Days($Y, $M, $D), $Y, $M, $D);
}

sub exceptionInMonth {
	my ($this, $Y, $M) = @_;
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("exceptionInMonth - $this->{exceptions}");

	if ($this->{exceptions}) {
		my @exceptions = split(/\s*,\s*/,$this->{exceptions});
		foreach my $exception (@exceptions) {
			$exception =~ s/:\d+$//;
			return 1 if ($exception ge sprintf('%.4u-%.2u-%.2u',$Y, $M, 1) && 
				$exception le sprintf('%.4u-%.2u-%.2u',$Y, $M, 31));
		}
	}
	return 0;
}

sub yearInSync {
	my ($this, $Y, $M) = @_;
	my $every = $this->{every} + 0;
	if ($every > 1) {
		my $date = $this->{parsedDate};
		my ($Dy,$Dm,$Dd) = N_Delta_YMD($date->{Y},$date->{M},1,$Y,$M,1);
		return 0 if $Dm; # fraction of a year so won't match a yearly repeater
		return 1 if !$Dy; # no year or month deltas so it's the month in which the event was created, match
		return 0 if $Dy < $every; # it's a full year but only part way through the repeat cycle
		return 1 if ($Dy % $every) == 0; # if no remainder, then a yearly match
		return 0; # no match
	}
	return 1;
}

sub monthInSync {
	my ($this, $Y, $M) = @_;
	my $every = $this->{every} + 0;
	if ($every > 1) {
		my $date = $this->{parsedDate};
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: $date->{Y},$date->{M},1,$Y,$M,1");
		my ($Dy,$Dm,$Dd) = N_Delta_YMD($date->{Y},$date->{M},1,$Y,$M,1);
		if ($date->{M} == 2 && $Dd >= 28) {
			$Dm += 1 if $Dd == Days_in_Month($date->{Y},$date->{M});
		}
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: $Dy $Dm $Dd");
		$Dy = $Dy ? $Dy * 12 : 0;
		$Dm += $Dy;
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: return 0 if $Dd < 0 || $Dm < 0");
		return 0 if $Dd < 0 || $Dm < 0; # it's the month before the first date of the event so no match
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: return 1 if !$Dm");
		return 1 if !$Dm; # no year or month deltas so it's the month in which the event was created, match
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: return 0 if $Dm < $every");
		return 0 if $Dm < $every;
	# Foswiki::Plugins::FullCalendarPlugin::writeDebug("monthInSync: return 1 if ($Dm % $every) == 0");
		return 1 if ($Dm % $every) == 0;
		return 0; # no match
	}
	return 1;
}

sub addIfInView {
	my ($this, $os, $clone, $start, $end, $Y, $M) = @_;
	
	return if $this->exceptionInMonth($Y, $M);
	
	my $date = $this->{parsedDate};
	my $D = $date->{D};
	my $days = 0;
	my $repeater = $this->{repeater};
	
	if ($repeater eq 'YMdd') { 
		### Yearly: dd of month MMM
		return unless $date->{M} == $M;
		return unless $this->yearInSync($Y,$M);
		($days, $Y, $M, $D) = ddDays($Y,$date->{M},$D);
		
	} elsif ($repeater eq 'Mdd') { 
		### Monthly: dd of every month
		return unless $this->monthInSync($Y,$M);
		($days, $Y, $M, $D) = ddDays($Y,$M,$D);
		
	} elsif ($repeater eq 'YMndow') {
        ### Yearly: nth DoW of month MMM 
		return unless $date->{M} == $M;
		return unless $this->yearInSync($Y,$M);
		($days, $Y, $M, $D) = $this->ndowDays($Y,$date->{M});
		
	} elsif ($repeater eq 'Mndow') {
        ### Monthly: nth DoW of every month
		return unless $this->monthInSync($Y,$M);
		($days, $Y, $M, $D) = $this->ndowDays($Y,$M);
		
	} elsif ($repeater eq 'YMLdow') {
        ### Yearly: Last DoW of month MMM 
		return unless $date->{M} == $M;
		return unless $this->yearInSync($Y,$M);
		($days, $Y, $M, $D) = $this->ldowDays($Y,$date->{M});

	} elsif ($repeater eq 'MLdow') {
        ### Monthly: Last DoW of every month
		return unless $this->monthInSync($Y,$M);
		($days, $Y, $M, $D) = $this->ldowDays($Y,$M);
	}
	
	Foswiki::Plugins::FullCalendarPlugin::writeDebug("addIfInView: $this->{repeater} $start->{days} <= $days < $end->{days}");
	if (($days >= ($start->{days} - $this->{durationDays})) && ($days < $end->{days})) {
		Foswiki::Plugins::FullCalendarPlugin::writeDebug("InView: $Y $M $D");
		$this->{start} = sprintf('%.4u-%.2u-%.2u',$Y, $M, $D);
		$this->addTo($os, $clone);
	}
	Foswiki::Plugins::FullCalendarPlugin::writeDebug("$this->{repeater} done");
}

sub expand {
	my ($this, $os, $start, $end, $clone) = @_;
	my $repeater = $this->{repeater};
	my $code = $this->{code};
	
	if ($repeater eq '') {
		Foswiki::Plugins::FullCalendarPlugin::writeDebug("adding non-repeating object");
		$this->{start} = $this->{startDate};
		$this->addTo($os, $clone);
		return;
	} 
	
	$this->{parsedDate} = 
		Foswiki::Plugins::FullCalendarPlugin::parseISOdate($this->{startDate}) 
			unless defined $this->{parsedDate};
	my $date = $this->{parsedDate};
	if ($this->{rangeEnd}) {
		$this->{parsedRange} = 
			Foswiki::Plugins::FullCalendarPlugin::parseISOdate($this->{rangeEnd}) 
				unless defined $this->{parsedRange};
		$end = $this->{parsedRange}->{days} > $end->{days} ? $end : $this->{parsedRange};
	}
	my ($Y, $M, $D);
	
	Foswiki::Plugins::FullCalendarPlugin::writeDebug("$repeater $start->{date} $end->{date} $this->{exceptions}");

	# Weekly and Periodic (Daily) repeaters
	if ($repeater eq 'Wdow') {
        ### Weekly: every DoW
		
		my $exceptions = $this->{exceptions};
		my $dow = join(',',@{$this->{dow}});
		# @dow = map { $daysofweek{$_} } @dow;
		my $durationDays = $this->{durationDays} + 0;

		my $period;
		# my $startDays;
		my $every = $this->{every} + 0;
		my $jump = $every * 7; # every n weeks into days
		if ($date->{days} >= $start->{days}) {
			($Y, $M, $D) = ($date->{Y},$date->{M},$date->{D});
			$period = $end->{days} - $date->{days};
			# $startDays = $date->{days};
		} else {
			($Y, $M, $D) = ($start->{Y},$start->{M},$start->{D});
			$period = $end->{days} - $start->{days};
			my $startDays = $start->{days};
			# stretch out the start of the view period to catch any nearby events which span over days
			if ($durationDays && (($startDays - $date->{days}) > $durationDays)) { 
				($Y, $M, $D) = Add_Delta_Days($Y, $M, $D,0-$durationDays);
				$period += $durationDays;
				$startDays = Date_to_Days($Y, $M, $D);
			}
			# Foswiki::Plugins::FullCalendarPlugin::writeDebug("$repeater $Y, $M, $D");
			if ($every > 1) { # && ($startDays - $date->{days}) > 7) {
				my $dd = Day_of_Week($date->{Y},$date->{M},$date->{D}); # Mon = 1 .. Sun = 7
				my $monday = $date->{days} - --$dd; # monday of the week in which the event starts
				my $diff = $startDays - $monday; # >= 0 days
				# Foswiki::Plugins::FullCalendarPlugin::writeDebug("$repeater dd $dd monday $monday startDays $startDays diff $diff");
				my $mod = $diff;
				if ($diff > 7) {
					# e.g. if 15 > 14 then mod <= 7 is in a valid week
					# e.g. if 22 > 14 then mod !<= 7 is not in a valid week
					# but if 13 > 14 then mod <= 7 but not in a valid week
					# $mod = $diff > $jump ? $diff % $jump : 0 - $jump - $diff;
					if ($diff > $jump) {
						$mod = $diff % $jump;
					} else {
						$mod = 0 - ($jump - $diff);
					}
				} # else mod = diff
				# Foswiki::Plugins::FullCalendarPlugin::writeDebug("$repeater mod $mod diff $diff jump $jump");
				if (abs($mod) <= 7) {
					($Y, $M, $D) = Add_Delta_Days($Y,$M,$D,0-$mod);
					$period += $mod;
				} else {
					$mod = $jump - $mod;
					($Y, $M, $D) = Add_Delta_Days($Y,$M,$D,$mod);
					$period -= $mod;
				}
			}
		}
		# $period ||= 1;
		
		my $dow1 = Day_of_Week($Y, $M, $D);
		Foswiki::Plugins::FullCalendarPlugin::writeDebug("$repeater $Y $M $D period $period startdow $dow1 dow $dow");
		for (my $day = 0; $day < $period; ) {
			my $i = $day;
			for (; $dow1 <= 7; $dow1++) {
				last if $i == $period;
	            if ( $dow =~ /$dow1/ ) {
		            my ($y, $m, $d) = Add_Delta_Days($Y,$M,$D,$i);
					my $date = sprintf('%.4u-%.2u-%.2u',$y,$m,$d);
					Foswiki::Plugins::FullCalendarPlugin::writeDebug("exceptions $exceptions date $date startdate $start->{date}");
					if ($exceptions =~ /$date/ || $date lt $start->{date}) {
						$i++;
						next;
					}
					# Foswiki::Plugins::FullCalendarPlugin::writeDebug("Wdow $Y $M $D $date $day $dow1 $dow[0]");
					# Without the following check we may be sending some events which are out of view (when diff < 7, see above) but this is
					# only in a very small minority of cases and the jquery fullcalendar plugin handles this anyway.
					# next if $date lt $start->{date};
					$this->{start} = $date;
					$this->addTo($os, $clone);
				}
				$i++;
			}
			$day = $i + $jump - 7; # done like this because dow1 does not always start on 1 (=Mon)
			$dow1 = 1;
		}
		return;

	} elsif ($repeater eq 'D') {
        ### Daily: every n days
		
		my $exceptions = $this->{exceptions};
		my $n = $this->{every};

		my $period;
		my $rem = 0;
		if ($date->{days} >= $start->{days}) { # first occurence of event is within view window
			$period = $end->{days} - $date->{days};
			($Y, $M, $D) = ($date->{Y},$date->{M},$date->{D});
		} else {
			$period = $end->{days} - $start->{days};
			my $diff = $start->{days} - $date->{days};
			# Foswiki::Plugins::FullCalendarPlugin::writeDebug("diff $diff n $n rem $rem");
			if ($diff > $n) {
				$rem = $diff % $n;
			} else {
				$rem = $n - $diff;
			}
			# slide the start of the view period to match any nearby events which span over days
			if ($rem > $this->{durationDays}) { 
				$rem = 0 - ($n - $rem);
			}
			($Y, $M, $D) = Add_Delta_Days($start->{Y},$start->{M},$start->{D},0-$rem);
			$period += $rem;
			# Foswiki::Plugins::FullCalendarPlugin::writeDebug("diff $diff n $n rem $rem");
		}
		for (my $day = 0; $day < $period; $day+=$n) {
			# Foswiki::Plugins::FullCalendarPlugin::writeDebug("day $day period $period n $n");
            my ($y, $m, $d) = Add_Delta_Days($Y,$M,$D,$day);
			# Foswiki::Plugins::FullCalendarPlugin::writeDebug("$y $m $d");
			my $deltaDate = sprintf('%.4u-%.2u-%.2u',$y,$m,$d);
			next if $exceptions =~ /$deltaDate/;
			$this->{start} = $deltaDate;
			$this->addTo($os, $clone);
		}
		return;
	}

	# Yearly and Monthly repeaters
	my @ympair = @{$start->{ympair}};
	$start = $date if $date->{days} > $start->{days};
	foreach my $pair (@ympair) {
		($Y, $M) = split(',',$pair);
		next if $Y < $start->{Y} || $M < $start->{M};
		$this->addIfInView($os, $clone, $start, $end, $Y, $M);
	}
	
}

1;
__DATA__
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
