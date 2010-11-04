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

package Foswiki::Plugins::ApprovalPlugin::Transition;

use strict;

use fields qw(action allowedUsers nextState notify signoff totalAllowed);

# stores all things about the transition between states

sub new {
    my ( $class, $action, $allowedUsers, $nextState, $notify, $signoff ) = @_;

    my $self = {};

    $self->{action}       = $action;
    $self->{allowedUsers} = $allowedUsers;
    $self->{nextState}    = $nextState;
    $self->{notify}       = $notify;
    $self->{signoff}      = $signoff;

    $self->{totalAllowed} = scalar( @{$allowedUsers} );

    return bless( $self, $class );
}

sub create {
    return bless( {}, shift );
}

sub action {
    my $self = shift;
    if (@_) { $self->{action} = shift }
    return $self->{action};
}

sub allowedUsers {
    my $self = shift;
    if (@_) { $self->{allowedUsers} = shift }
    return $self->{allowedUsers};
}

sub nextState {
    my $self = shift;
    if (@_) { $self->{nextState} = shift }
    return $self->{nextState};
}

sub notify {
    my $self = shift;
    if (@_) { $self->{notify} = shift }
    return $self->{notify};
}

sub signoff {
    my $self = shift;
    if (@_) { $self->{signoff} = shift }
    return $self->{signoff};
}

sub getTotalAllowed {
    my $self = shift;
    return $self->{totalAllowed};
}

1;
