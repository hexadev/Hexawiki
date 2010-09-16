#
# Copyright (C) 2010 David Patterson
#
# Foswiki extension that adds tags for object tracking
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
package Foswiki::Plugins::ObjectPlugin::ObjectSet;

use strict;
use integer;
use Foswiki::Func;
require Foswiki::Plugins::ObjectPlugin;
use Foswiki::Plugins::ObjectPlugin::Object;

# PUBLIC constructor
sub new {
    my $class = shift;
    my $this = {};

    $this->{OBJECTS} = [];

    return bless( $this, $class );
}

# PUBLIC Add this object to the list of objects
sub add {
    my ( $this, $object ) = @_;

    push (@{$this->{OBJECTS}}, $object);
}

# PUBLIC STATIC load a block of text into an object set
sub load {
    my ( $web, $topic, $text, $purpose, $expandText, $withDeleted, $setClass, $objectClass, $reltopic ) = @_;
	$withDeleted ||= 0;
	$setClass ||= 'Foswiki::Plugins::ObjectPlugin::ObjectSet';
	$objectClass ||= 'Foswiki::Plugins::ObjectPlugin::Object';

	eval 'use '.$objectClass;
    my $objectSet = $setClass->new();
	
	unless (defined $text) {
		my $meta;
		($meta, $text) = Foswiki::Func::readTopic($web, $topic);
		Foswiki::Plugins::ObjectPlugin::checkAccess($purpose, $web, $topic, $text, $meta);  # can throw AccessControlException
		$objectSet->{meta} = $meta;
	}

    my @blocks = split( /(%OBJECT{.*?}%|%ENDOBJECT%)/, $text );
    my $i = 0;
    while ($i < scalar(@blocks)) {
        my $block = $blocks[$i++];
        if ($block =~ /^%OBJECT{(.*)}%$/) {
            my $attrs = $1;
            my $descr = $blocks[$i++]; # object text
            $i++; # skip %ENDOBJECT%
            my $object = $objectClass->new($web, $topic, $attrs, $descr);
			next unless $object;
			my $add = $withDeleted ? 1 : $object->{deleted} ? 0 : 1;
			if ($add && $reltopic) {
				$add = 0 unless ($object->{reltopic} && $object->{reltopic} eq $reltopic);
			}
			$objectSet->add($object) if $add;
        } elsif ($expandText && $block =~ m/%[A-Z]+({.*?})?%/) { 
			# only if there are macros that could produce new OBJECTs
			# and only likely-ish at this stage if this is via a REST call
			Foswiki::Plugins::ObjectPlugin::disableStandardProcessing();
			$block = Foswiki::Func::expandCommonVariables($block);
			if ($block) {
				my $newobjects = 
				  load($web, $topic, $block, $purpose, 0, $withDeleted, $setClass, $objectClass, $reltopic);
				# if (scalar(@{$newobjects->{OBJECTS}})) {
					$objectSet->concat($newobjects);
				# } else {
					# $objectSet->add($block);
				# }
			}
		} else {
			$objectSet->add($block);
		}
        $i++ while $i < scalar(@blocks) && !length($blocks[$i]);
    }
    
    return $objectSet;
}

# Find the object in the object set with the given uid,
# splitting the rest of the set into before the object,
# and after the object.
sub splitOnObject {
    my( $this, $uid ) = @_;

    my $found = undef;
    my $pre = ''; #new Foswiki::Plugins::ObjectPlugin::ObjectSet();
    my $post = ''; #new Foswiki::Plugins::ObjectPlugin::ObjectSet();

    foreach my $object (@{$this->{OBJECTS}}) {
		if( $found ) {
            $post .= ref($object) ? $object->stringify() : $object;
        } elsif (ref($object) && $object->{uid} eq $uid) {
            $found = $object;
        } else {
            $pre .= ref($object) ? $object->stringify() : $object;
        }
    }
    return ( $found, $pre, $post );
}

sub findSingleObject {
    my ( $this, $uid ) = @_;

	my $returnobject = undef;
    foreach my $object (@{$this->{OBJECTS}}) {
        if (ref($object)) {
            if ($object->{uid} eq $uid) {
				$returnobject = $object;
				last;
			}
        }
    }
	return $returnobject;
}

# An alternative to load and splitOnObject that doesn't require parsing the whole text
# when looking for an object.
sub loadToFind {
    my ( $uid, $web, $topic, $text, $purpose, $withDeleted, $objectClass ) = @_;
	$withDeleted ||= 0;
	$objectClass ||= 'Foswiki::Plugins::ObjectPlugin::Object';
	eval 'use '.$objectClass;
	
	my $meta;
	unless (defined $text) {
		($meta, $text) = Foswiki::Func::readTopic($web, $topic);
		Foswiki::Plugins::ObjectPlugin::checkAccess($purpose, $web, $topic, $text, $meta);  # can throw AccessControlException
	}

	my $limit = $Foswiki::cfg{Plugins}{ObjectPlugin}{limit}; # could be 0
	unless (defined $limit) {
		$limit = 31;  # SMELL: magic number, no theory behind it, make configurable
	} elsif ($limit) {
		# even limit not allowed because of the OBJECT|ENDOBJECT pair and the use of split()
		$limit = $limit % 2 ? $limit : $limit + 1;  
	}

    my ($attrs, $descr);
    my $pre = '';
    my $post = '';
	
	while ($text) {
		($attrs, $descr, $pre, $post, $text) = parseForObject($text, $pre, $limit, $uid, $withDeleted);
    }
	my $found = $attrs ? $objectClass->new($web, $topic, $attrs, $descr, $meta) : undef;
    return ( $found, $pre, $post, $meta );
}

sub parseForObject {
	my ($text, $pre, $limit, $uid, $withDeleted) = @_;
	my $extra = '';
    my @blocks = split( /(%OBJECT{.*?}%|%ENDOBJECT%)/, $text, $limit );
    if ($limit && $blocks[-1] =~ /%OBJECT{.*?}%/) { # more than $limit number of objects
		$extra = pop(@blocks); # put the extra objects on side to be parsed later if need be
	}
    while (scalar(@blocks)) {
        my $block = shift(@blocks);
        if ($block =~ /^%OBJECT{(.*)}%$/) {
			Foswiki::Plugins::ObjectPlugin::writeDebug("attributes - $1");
            my %attrs = Foswiki::Func::extractParameters($1);
			Foswiki::Plugins::ObjectPlugin::writeDebug("attrs - $attrs{uid}");
			my $descr = shift(@blocks); # object text
			my $endobject = shift(@blocks); # %ENDOBJECT%
			if ($attrs{uid} eq $uid) {
				my $ats = $withDeleted ? $1 : $attrs{deleted} ? undef : $1;
				my $post .= join('',@blocks).$extra;
				return ( $ats, $descr, $pre, $post, undef );
			} else {
				$pre .= $block.$descr.$endobject;
			}
        } else {
            $pre .= $block;
        }
        shift(@blocks) while scalar(@blocks) && !length($blocks[0]);
    }
	return (undef, undef, $pre, '', $extra);
}

# PRIVATE place to put sort fields
my @_sortfields;

# PUBLIC sort by due date or, if given, by an ordered sequence
# of attributes by string value
sub sort {
    my ( $this, $order ) = @_;
    if ( defined( $order ) ) {
        $order =~ s/[^\w,]//g;
        @_sortfields = split( /,\s*/, $order );
        @{$this->{OBJECTS}} = sort {
            foreach my $sf ( @_sortfields ) {
                return -1 unless ref($a);
                return 1 unless ref($b);
                my ( $x, $y ) = ( $a->{$sf}, $b->{$sf} );
                if ( defined( $x ) && defined( $y )) {
                    my $c = ( $x cmp $y );
                    return $c if ( $c != 0 );
                    # COVERAGE OFF should never be needed
                } elsif ( defined( $x ) ) {
                    return -1;
                } elsif ( defined( $y ) ) {
                    return 1;
                }
                # COVERAGE ON
            }
            # default to sorting on due
            # my $x = $a->secsToGo();
            # my $y = $b->secsToGo();
            # return $x <=> $y;
        } @{$this->{OBJECTS}};
    # } else {
        # @{$this->{OBJECTS}} =
          # sort {
              # my $x = $a->secsToGo();
              # my $y = $b->secsToGo();
              # return $x <=> $y;
          # } @{$this->{OBJECTS}};
    }
}

# PUBLIC Concatenate another object set to this one
sub concat {
    my ( $this, $objects ) = @_;

    push @{$this->{OBJECTS}}, @{$objects->{OBJECTS}};
}

# PUBLIC Search the set of objects for objects that match the given
# attributes. Return an ObjectSet. If the search expression is empty,
# all objects match.
sub search {
    my ( $this, $attrs ) = @_;
    my $object;
    my $chosen = new Foswiki::Plugins::ObjectPlugin::ObjectSet();

    foreach $object ( @{$this->{OBJECTS}} ) {
        if ( ref($object) && $object->matches( $attrs ) ) {
            $chosen->add( $object );
        }
    }

    return $chosen;
}

sub stringify {
    my $this = shift;
    my $txt = '';
    foreach my $object ( @{$this->{OBJECTS}} ) {
        if (ref($object)) {
            $txt .= $object->stringify();
        } else {
            $txt .= $object;
        }
    }
    return $txt;
}

sub TO_JSON {
    my $this = shift;
    return $this->{OBJECTS};
}

sub renderForDisplay {
    my ($this, $format) = @_;
	$format ||= undef;
    my $text = '';
	my $objNr = 1;
	my $bgClass;
    foreach my $object ( @{$this->{OBJECTS}} ) {
        if (ref($object)) {
			# css striping if it's wanted
			$bgClass = $objNr++ % 2 ? 'bgOdd' : 'bgEven';
            $text .= $object->prepareForDisplay($format, $bgClass);
        } else {
            $text .= $object;
        }
		$text .= "\n";
    }
	Foswiki::Plugins::ObjectPlugin::addDefaultsToPage();

    $text = Foswiki::Func::expandCommonVariables($text);
    $text = Foswiki::Func::renderText($text);

    return $text;
}

# PUBLIC get a map of all people who have objects in this object set
sub getObjectees {
    my ( $this, $whos ) = @_;
    my $object;

    foreach $object ( @{$this->{OBJECTS}} ) {
        next unless ref($object);
        my @persons = split( /,\s*/, $object->{creator} );
        foreach my $person ( @persons ) {
            $whos->{$person} = 1;
        }
    }
}

# PUBLIC STATIC get all objects in topics in the given web that
# match the search expression
# $web - name of the web to search
# $attrs - attributes to match
# $internal - boolean true if topic permissions can be ignored
sub allObjectsInWeb {
    my ( $web, $attrs, $internal ) = @_;
    $internal = 0 unless defined ( $internal );
    my $objects = new Foswiki::Plugins::ObjectPlugin::ObjectSet();
	my @tops = Foswiki::Func::getTopicList( $web );
	my $topics = $attrs->{topic};

	@tops = grep( /^$topics$/, @tops ) if ( $topics );
    my $grep =
      Foswiki::Func::searchInWebContent( '%OBJECT{.*}%', $web,
                                       \@tops,
                                       { type => 'regex',
                                         files_without_match => 1,
                                         casesensitive => 1 } );

    foreach my $topic ( keys %$grep ) {
		my ($meta,$text) = Foswiki::Func::readTopic($web, $topic);
        next unless Foswiki::Func::checkAccessPermission(
            'VIEW', Foswiki::Func::getWikiName(), $text, $topic, $web, $meta);
        my $tobjs = Foswiki::Plugins::ObjectPlugin::ObjectSet::load(
            $web, $topic, $text, undef, 0 );
        $tobjs = $tobjs->search( $attrs );
        $objects->concat( $tobjs );
    }

    return $objects;
}

# PUBLIC STATIC get all objects in all webs that
# match the search in $attrs
sub allObjectsInWebs {
    my ( $theweb, $attrs, $internal ) = @_;
    $internal = 0 unless defined ( $internal );
    my $filter = $attrs->{web} || $theweb;
    my $choice = 'user';
    # Exclude webs flagged as NOSEARCHALL
    $choice .= ',public' if $filter ne $theweb;
    my @webs = grep { /^$filter$/ } Foswiki::Func::getListOfWebs( $choice );
    my $objects = new Foswiki::Plugins::ObjectPlugin::ObjectSet();

    foreach my $web ( @webs ) {
        my $subacts = allObjectsInWeb( $web, $attrs, $internal );
        $objects->concat( $subacts );
    }
    return $objects;
}

1;
