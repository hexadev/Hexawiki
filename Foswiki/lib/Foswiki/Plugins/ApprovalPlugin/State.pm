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

package Foswiki::Plugins::ApprovalPlugin::State;

use strict;

use fields qw(currentState defaultState allowedEdit message reviewedBy signoff);

# stores all things about the state
# is defaultState needed?

sub new {
    my ( $class, $currentState, $defaultState, $allowedEdit, $message,
        $reviewedBy, $signoff )
      = @_;

    my $self = {};

    $self->{currentState} = $currentState;
    $self->{defaultState} = $defaultState;
    $self->{allowedEdit}  = $allowedEdit;
    $self->{message}      = $message;
    $self->{reviewedBy}   = $reviewedBy || '';
    $self->{signoff}      = $signoff || 0;

    return bless( $self, $class );
}

# empty constructor
sub create {
    my $class = shift;
    my $self  = {};

    $self->{currentState} = '';
    $self->{defaultState} = '';
    $self->{allowedEdit}  = '';
    $self->{message}      = '';
    $self->{reviewedBy}   = '';
    $self->{signoff}      = 0;

    return bless( $self, $class );
}

# resets some keys before they are re-written
sub resetObj {
    my $self = shift;

    $self->{defaultState} = '';
    $self->{allowedEdit}  = '';
    $self->{message}      = '';
    $self->{reviewedBy}   = '';
    $self->{signoff}      = 0;
}

sub currentState {
    my $self = shift;
    if (@_) { $self->{currentState} = shift }
    return $self->{currentState};
}

sub defaultState {
    my $self = shift;
    if (@_) { $self->{defaultState} = shift }
    return $self->{defaultState};
}

sub allowedEdit {
    my $self = shift;
    if (@_) { $self->{allowedEdit} = shift }
    return $self->{allowedEdit};
}

sub message {
    my $self = shift;
    if (@_) { $self->{message} = shift }
    return $self->{message};
}

sub reviewedBy {
    my $self = shift;
    if (@_) { $self->{reviewedBy} = shift }
    return $self->{reviewedBy};
}

sub reviewedByConcat {
    my $self = shift;
    if (@_) { $self->{reviewedBy} .= shift }
}

sub signoff {
    my $self = shift;
    if (@_) { $self->{signoff} = shift }
    return $self->{signoff};
}

sub anotherSignoffInState {
    my $self = shift;
    $self->{signoff}++;
}

1;
