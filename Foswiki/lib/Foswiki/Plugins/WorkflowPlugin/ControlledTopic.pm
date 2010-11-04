#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
# Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
# Copyright (C) 2008 Crawford Currie http://c-dot.co.uk
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
# This object represents a workflow definition. It stores the preferences
# defined in the workflow topic, together with the state and transition
# tables defined therein.
#
package Foswiki::Plugins::WorkflowPlugin::ControlledTopic;

use strict;

use Foswiki (); # for regexes
use Foswiki::Func ();

# Constructor
sub new {
    my ( $class, $workflow, $web, $topic, $meta, $text ) = @_;
    my $this = bless(
        {
            workflow => $workflow,
            web      => $web,
            topic    => $topic,
            meta     => $meta,
            text     => $text,
            state    => $meta->get('WORKFLOW'),
            history  => $meta->get('WORKFLOWHISTORY'),
        },
        $class
    );

    return $this;
}

# Return true if debug is enabled in the workflow
sub debugging {
    my $this = shift;
    return $this->{workflow}->{preferences}->{WORKFLOWDEBUG};
}

# Get the current state of the workflow in this topic
sub getState {
    my $this = shift;
    return $this->{state}->{name} || $this->{workflow}->getDefaultState();
}

# Get the available actions from the current state
sub getActions {
    my $this = shift;
    return $this->{workflow}->getActions($this);
}

# Set the current state in the topic
sub setState {
    my ( $this, $state, $version ) = @_;
    $this->{state}->{name} = $state;
    $this->{state}->{"LASTVERSION_$state"} = $version;
    $this->{state}->{"LASTTIME_$state"} =
      Foswiki::Func::formatTime( time(), undef, 'servertime' );
    $this->{meta}->put( "WORKFLOW", $this->{state} );
}

# Get the appropriate message for the current state
sub getStateMessage {
    my $this = shift;
    return $this->{workflow}->getMessage( $this->getState() );
}

# Get the history string for the topic
sub getHistoryText {
    my $this = shift;

    return '' unless $this->{history};
    return $this->{history}->{value} || '';
}

# Return true if a new state is available using this action
sub haveNextState {
    my ( $this, $action ) = @_;
    return $this->{workflow}->getNextState( $this, $action );
}

# Some day we may handle the can... functions indepedently. For now,
# they all check editability thus....
sub isModifyable {
    my $this = shift;

    return $this->{isEditable} if defined $this->{isEditable};

    # See if the workflow allows an edit
    unless (defined $this->{isEditable}) {
        $this->{isEditable} = (
            # Does the workflow permit editing?
            $this->{workflow}->allowEdit($this)
            # Does Foswiki permit editing?
            && Foswiki::Func::checkAccessPermission(
                'CHANGE', $Foswiki::Plugins::SESSION->{user},
                $this->{text}, $this->{topic}, $this->{web},
                $this->{meta})) ? 1 : 0;
    }
    return $this->{isEditable};
}

# Return tue if this topic is editable
sub canEdit {
    my $this = shift;
    return $this->isModifyable($this);
}

# Return true if this topic is attachable to
sub canAttach {
    my $this = shift;
    return $this->isModifyable( $this );
}

# Return tue if this topic is forkable
sub canFork {
    my $this = shift;
    return $this->isModifyable( $this );
}

# Expand miscellaneous preferences defined in the workflow and topic
sub expandWorkflowPreferences {
    my $this = shift;
    my $url  = shift;
    my $key;
    foreach $key ( keys %{ $this->{workflow}->{preferences} } ) {
        if ( $key =~ /^WORKFLOW/ ) {
            $_[0] =~ s/%$key%/$this->{workflow}->{preferences}->{$key}/g;
        }
    }

    # show last version tags and last time tags
    while ( my ( $key, $val ) = each %{ $this->{state} } ) {
        $val ||= '';
        if ( $key =~ m/^LASTVERSION_/ ) {
            my $foo = CGI::a( { href => "$url?rev=$val" }, "revision $val" );
            $_[0] =~ s/%WORKFLOW$key%/$foo/g;

            # WORKFLOWLASTREV_
            $key =~ s/VERSION/REV/;
            $_[0] =~ s/%WORKFLOW$key%/$val/g;
        }
        elsif ( $key =~ /^LASTTIME_/ ) {
            $_[0] =~ s/%WORKFLOW$key%/$val/g;
        }
    }

    # Clean down any states we have no info about
    $_[0] =~ s/%WORKFLOWLAST(TIME|VERSION)_\w+%//g unless $this->debugging();
}

# if the form employed in the state arrived after after applying $action
# is different to the form currently on the topic.
sub newForm {
    my ( $this, $action ) = @_;
    my $form = $this->{workflow}->getNextForm( $this, $action );
    my $oldForm = $this->{meta}->get('FORM');

    # If we want to have a form attached initially, we need to have
    # values in the topic, due to the form initialization
    # algorithm, or pass them here via URL parameters (take from
    # initialization topic)
    return ( $form && ( !$oldForm || $oldForm ne $form ) ) ? $form : undef;
}

# change the state of the topic. Does *not* save the updated topic, but
# does notify the change to listeners.
sub changeState {
    my ( $this, $action ) = @_;

    my $state = $this->{workflow}->getNextState( $this, $action );
    my $form = $this->{workflow}->getNextForm( $this, $action );
    my $notify = $this->{workflow}->getNotifyList( $this, $action );

    my ( $revdate, $revuser, $version ) = $this->{meta}->getRevisionInfo();
    if (ref($revdate) eq 'HASH') {
        my $info = $revdate;
        ( $revdate, $revuser, $version ) =
          ( $info->{date}, $info->{author}, $info->{version} );
    }

    $this->setState($state, $version);

    my $fmt = Foswiki::Func::getPreferencesValue("WORKFLOWHISTORYFORMAT")
      || '<br>$state -- $date';
    $fmt =~ s/\$wikiusername/Foswiki::Func::getWikiUserName()/geo;
    $fmt =~ s/\$state/$this->getState()/goe;
    $fmt =~ s/\$date/$this->{state}->{"LASTTIME_$state"}/geo;
    $fmt =~ s/\$rev/$this->{state}->{"LASTVERSION_$state"}/geo;
    if ( defined &Foswiki::Func::decodeFormatTokens ) {

        # Compatibility note: also expands $percnt etc.
        $fmt = Foswiki::Func::decodeFormatTokens($fmt);
    }
    else {
        my $mixedAlpha = $Foswiki::regex{mixedAlpha};
        $fmt =~ s/\$quot/\"/go;
        $fmt =~ s/\$n/\n/go;
        $fmt =~ s/\$n\(\)/\n/go;
        $fmt =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }

    $this->{history}->{value} .= $fmt;
    $this->{meta}->put( "WORKFLOWHISTORY", $this->{history} );
    if ($form) {
        $this->{meta}->put( "FORM", { name => $form } );
    }    # else leave the existing form in place

    if ($notify) {

        # Expand vars in the notify list. This supports picking up the
        # value of the notifees from the topic itself.
        $notify = $this->expandMacros($notify);

        # Dig up the bodies
        my @persons = split( /\s*,\s*/, $notify );
        my @emails;
        foreach my $who (@persons) {
            if ( $who =~ /^$Foswiki::regex{emailAddrRegex}$/ ) {
                push( @emails, $who );
            }
            else {
                $who =~ s/^.*\.//;    # web name?
                my @list = Foswiki::Func::wikinameToEmails($who);
                if ( scalar(@list) ) {
                    push( @emails, @list );
                }
                else {
                    Foswiki::Func::writeWarning( __PACKAGE__
                          . " cannot send mail to '$who'"
                          . " - cannot determine an email address" );
                }
            }
        }
        if ( scalar(@emails) ) {

            # Have a list of recipients
            my $text = Foswiki::Func::loadTemplate('mailworkflowtransition');
            Foswiki::Func::setPreferencesValue( 'EMAILTO',
                join( ', ', @emails ) );
            Foswiki::Func::setPreferencesValue( 'TARGET_STATE',
                $this->getState() );
            $text = $this->expandMacros($text);
            my $errors = Foswiki::Func::sendEmail( $text, 5 );
            if ($errors) {
                Foswiki::Func::writeWarning(
                    'Failed to send transition mails: ' . $errors );
            }
        }
    }

    return undef;
}

# Save the topic to the store
sub save {
    my $this = shift;

    Foswiki::Func::saveTopic(
        $this->{web}, $this->{topic}, $this->{meta},
        $this->{text}, { forcenewrevision => 1 }
       );
}

sub expandMacros {
    my ( $this, $text ) = @_;
    my $c = Foswiki::Func::getContext();

    # Workaround for Item1071
    my $memory = $c->{can_render_meta};
    $c->{can_render_meta} = $this->{meta};
    $text = Foswiki::Func::expandCommonVariables(
        $text, $this->{topic}, $this->{web}, $this->{meta} );
    $c->{can_render_meta} = $memory;
    return $text;
}

1;
