# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@googlemail.com
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
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::ApprovalPlugin::Approval;

require Foswiki::Plugins::ApprovalPlugin::State;
require Foswiki::Plugins::ApprovalPlugin::Transition;

use strict;

use fields
  qw(currentWeb currentTopic definitionWeb definitionTopic history state transition preference);

# stores all things about the approval (web, topic, history, etc)
# also has pointers for state and transition objects

sub new {
    my ( $class, $currentWeb, $currentTopic, $definitionWeb, $definitionTopic,
        $history, $state, $transition )
      = @_;

    my $self = {};

    $self->{currentWeb}      = $currentWeb;
    $self->{currentTopic}    = $currentTopic;
    $self->{definitionWeb}   = $definitionWeb;
    $self->{definitionTopic} = $definitionTopic;
    $self->{history}         = $history;
    $self->{state} = $state;    # Foswiki::Plugins::ApprovalPlugin::State Object
      #$self->{transition} = $transition; # Foswiki::Plugins::ApprovalPlugin::Transition Object

    return bless( $self, $class );
}

# empty constructor
sub create {
    my $class = shift;

    my $self = {};

    $self->{currentWeb};
    $self->{currentWeb};
    $self->{currentTopic};
    $self->{definitionWeb};
    $self->{definitionTopic};
    $self->{history};
    $self->{state}      = Foswiki::Plugins::ApprovalPlugin::State->create();
    $self->{transition} = {};
    $self->{preference} = {};

    return bless( $self, $class );
}

# resets some keys before they are re-written
sub resetObj {
    my $self = shift;

    #$self->{state} = Foswiki::Plugins::ApprovalPlugin::State->create();
    $self->{transition} = {};

    # Call others
    $self->{state}->resetObj();
}

sub currentWeb {
    my $self = shift;
    if (@_) { $self->{currentWeb} = shift }
    return $self->{currentWeb};
}

sub currentTopic {
    my $self = shift;
    if (@_) { $self->{currentTopic} = shift }
    return $self->{currentTopic};
}

sub definitionWeb {
    my $self = shift;
    if (@_) { $self->{definitionWeb} = shift }
    return $self->{definitionWeb};
}

sub definitionTopic {
    my $self = shift;
    if (@_) { $self->{definitionTopic} = shift }
    return $self->{definitionTopic};
}

sub history {
    my $self = shift;
    if (@_) { $self->{history} = shift }
    return $self->{history};
}

sub historyConcat {
    my $self = shift;
    if (@_) { $self->{history} .= shift }
}

sub state {
    my $self = shift;
    if (@_) { $self->{state} = shift }
    return $self->{state};
}

# return the transition objects in a hash by actions
sub transitions {

    #my $self = shift;
    my ( $self, $transition ) = @_;
    if ($transition) {
        $self->{transition} = $transition;
    }
    return $self->{transition};
}

# return the transition object for the action
sub transitionByAction {

    #my $self = shift;
    my ( $self, $action, $transition ) = @_;
    if ( $action && $transition ) {
        $self->{transition}->{$action} = $transition;
    }
    return $self->{transition}->{$action};
}

# set hash of preferences or return hash
sub preferences {
    my ( $self, $preferences ) = @_;
    if ($preferences) {
        $self->{preference} = $preferences;
    }
    return $self->{preference};
}

# get or set preference by key
sub preferenceByKey {

    #my $self = shift;
    my ( $self, $key, $preference ) = @_;
    if ( $key && $preference ) {
        $self->{preference}->{$key} = $preference;
    }
    return $self->{preference}->{$key};
}

1;
