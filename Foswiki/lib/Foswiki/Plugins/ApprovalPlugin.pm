# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 1009 Andrew Jones, andrewjones86@googlemail.com
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the Fosiwki root.

package Foswiki::Plugins::ApprovalPlugin;

## These are required conditionally (i.e. when the plugin needs to do something)
#use Foswiki::Plugins::ApprovalPlugin::Approval;
#use Foswiki::Plugins::ApprovalPlugin::State;
#use Foswiki::Plugins::ApprovalPlugin::Transition;

use strict;

use vars qw( $VERSION
  $RELEASE
  $SHORTDESCRIPTION
  $debug
  $pluginName
  $NO_PREFS_IN_TOPIC
  $CalledByMyself
  $globControlled
  $globObj_approval);

our $VERSION = '$Rev: 3923 (2009-05-16) $';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION =
'Defines a set of states for one more or topics, with each state requiring approval by one or more users.';
our $NO_PREFS_IN_TOPIC = 1;

our $pluginName = 'ApprovalPlugin';

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # handles the 'APPROVAL' tag
    Foswiki::Func::registerTagHandler( 'APPROVAL', \&_handleTag );

    my $prefApproval = Foswiki::Func::getPreferencesValue("APPROVALDEFINITION")
      || 0;
    if ($prefApproval) {
        _Debug("$web.$topic is under approval control");
        $globControlled = 1;
    }
    else {

        # not under approval control
        $globControlled = 0;
        return 1;
    }

    my ( $defWeb, $defTopic ) =
      Foswiki::Func::normalizeWebTopicName( $web, $prefApproval );

    unless ( Foswiki::Func::topicExists( $defWeb, $defTopic ) ) {
        _Warn("$defWeb.$defTopic does not exist. Called by $web.$topic");
        return 1;
    }

    # Now we have something to do, we require our modules
    _doRequire();

    # Set up objects
    $globObj_approval = Foswiki::Plugins::ApprovalPlugin::Approval->create();
    $globObj_approval->currentWeb($web);
    $globObj_approval->currentTopic($topic);
    $globObj_approval->definitionWeb($defWeb);
    $globObj_approval->definitionTopic($defTopic);

    # parse the approval definition topic
    _parseApprovalDef();

    return 1;
}

sub _parseApprovalDef {

    # reset the objects when we are parsed after state change
    $globObj_approval->resetObj();

    # get current state from topic
    my ( $meta, undef ) = Foswiki::Func::readTopic( $globObj_approval->currentWeb,
        $globObj_approval->currentTopic );

    my $approval = $meta->get('APPROVAL');
    $globObj_approval->state->currentState( $approval->{name} )
      if $approval->{name};
    $globObj_approval->state->reviewedBy( $approval->{reviewedBy} )
      if $approval->{reviewedBy};
    $globObj_approval->state->signoff( $approval->{signoff} )
      if $approval->{signoff};

    my $history = $meta->get('APPROVALHISTORY') || '';
    $history = $history->{value} if $history;
    $globObj_approval->history($history);

    # definition topic
    my ( undef, $text ) =
      Foswiki::Func::readTopic( $globObj_approval->definitionWeb,
        $globObj_approval->definitionTopic );

    my $inBlock = 0;

    foreach ( split( /\n/, $text ) ) {
        if (
/^\s*\|.*State[^|]*\|.*Action[^|]*\|.*Next State[^|]*\|.*Allowed[^|]*\|/
          )
        {

            # in the TRANSITION table
            $inBlock = 1;
        }
        elsif (/^\s*\|.*State[^|]*\|.*Allow Edit[^|]*\|.*Message[^|]*\|/) {

            # in the STATE table
            $inBlock = 2;

        }
        elsif (/^(\s*\* Set )([A-Za-z]+)( \= *)(.*)$/) {

            # preference
            $globObj_approval->preferenceByKey( $2, _expandVars($4) );

        }
        elsif ( ( $inBlock == 1 ) && s/^\s*\|//o ) {

            # read row in TRANSITION table
            my ( $state, $action, $next, $allowed, $notify, $signoff ) =
              split(/\s*\|\s*/);
            $state = _cleanField($state);

            if ( $state eq $globObj_approval->state->currentState ) {

                # Only care about current state
                $allowed = _expandVars($allowed);
                if ( $notify =~ /yes|on|1/i ) {
                    $notify = 1;
                }
                else {
                    $notify = 0;
                }
                $signoff =~ s/%//;

                my @allowedUsers;
                foreach ( split( /\s*,\s*/, $allowed ) ) {
                    my $allowedUser = Foswiki::Func::getWikiUserName($_);

                    next unless _userExists($allowedUser);

                    # is user already listed?
                    next if ( grep( /$allowedUser/, @allowedUsers ) );

                    push( @allowedUsers, $allowedUser );
                }

                my $obj_transition =
                  Foswiki::Plugins::ApprovalPlugin::Transition->new( $action,
                    \@allowedUsers, $next, $notify, $signoff );
                $globObj_approval->transitionByAction( $action,
                    $obj_transition );

            }
        }
        elsif ( ( $inBlock == 2 ) && s/^\s*\|//o ) {

            # read row in STATE table
            my ( $state, $allowedit, $message ) = split(/\s*\|\s*/);
            $state = _cleanField($state);

            if ( !$globObj_approval->state->defaultState ) {
                $globObj_approval->state->defaultState($state);
                $globObj_approval->state->currentState($state)
                  unless $globObj_approval->state->currentState;
            }

            if ( $state eq $globObj_approval->state->currentState ) {
                $allowedit = _expandVars($allowedit);
                $globObj_approval->state->allowedEdit($allowedit);
                $globObj_approval->state->message($message);
            }

        }
        else {
            $inBlock = 0;
        }
    }
}

# =========================
sub _handleTag {

    return _Return( 'This topic is not under approval control.', 1 )
      unless $globControlled;

    my $action = $_[1]->{action} || $_[1]->{_DEFAULT};

    for ($action) {
        /pref/i
          and return $globObj_approval->preferenceByKey( $_[1]->{name} )
          || _Return(
            "Preference '" . $_[1]->{name} . "' not found in definition topic.",
            1
          ),
          last;
        /message/i
          and return $globObj_approval->state->message
          || 'No message found for current state.', last;
        /reviewed/i
          and return $globObj_approval->state->reviewedBy
          || 'No one has reviewed the current state.', last;
        /history/i and return $globObj_approval->history || '', last;
        /transition/i and return &_createTransitionForm( $_[3], $_[2] ), last;
        return _Return( 'No valid action was found in this tag.', 1 );
    }
}

# creates the form to change state
sub _createTransitionForm {

    return _Return('You have already reviewed this state.')
      if ( $globObj_approval->state->reviewedBy
        && _userInList( $globObj_approval->state->reviewedBy ) );

    my ( $web, $topic ) = @_;
    my $user = Foswiki::Func::getWikiName();

    return _Return(
        'You must have CHANGE permission on this topic to change state.', 1 )
      if (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', $user, undef, $topic, $web, undef
        )
      );

    my @transitions;    # array of transition objects
    my $noactions = 0;  # true if there are any actions in the transition object

    if ( $globObj_approval->transitions ) {
        while ( my ( $action, $transition ) =
            each( %{ $globObj_approval->transitions } ) )
        {
            $noactions = 1;
            if (
                scalar @{ $transition->allowedUsers } == 0
                ||      # no users in allowed column, all can approve
                _userInArray( $transition->allowedUsers )
              )
            {           # user is in allowed column
                push( @transitions, $transition );
            }
        }
    }

    my $numberOfActions = scalar(@transitions);

    if ( $numberOfActions > 0 ) {

        # create most the form
        my $url = Foswiki::Func::getViewUrl( $web, $topic );

        my $form =
            "<form id='ApprovalTransition' action='$url' method='post'>"
          . "<input type='hidden' name='APPROVALSTATE' value='"
          . $globObj_approval->state->currentState . "' />";
        if ( $numberOfActions == 1 ) {

            # create just a button
            $form .=
                "<input type='hidden' name='APPROVALACTION' value='"
              . $transitions[0]->action . "' />"
              . "<input type='submit' value='"
              . $transitions[0]->action
              . "' class='foswikiSubmit' />";
        }
        else {

            # create drop down box and button
            my $select;
            @transitions = sort(@transitions);
            foreach my $obj_transition (@transitions) {
                $select .=
                    "<option value='"
                  . $obj_transition->action . "'> "
                  . $obj_transition->action
                  . " </option>";
            }

            $form .= "<select name='APPROVALACTION'>$select</select> "
              . "<input type='submit' value='Change status' class='foswikiSubmit' />";
        }
        $form .= '</form>';
        return $form;
    }
    if ($noactions) {

        # not permitted to change state
        my $logIn = '';
        my $guest = $Foswiki::cfg{DefaultUserWikiName} || 'WikiGuest';

        #if( Foswiki::Func::isGuest() ){ # didnt seem to work as expected...
        if ( $user eq $guest ) {
            my $url = Foswiki::Func::getScriptUrl( $web, $topic, 'login' );
            $logIn = "You may need to <a href='$url'>log in</a>.";
        }
        return _Return(
            'You are not permitted to change the state on this topic.'
              . $logIn );
    }

    return _Return('No actions can be carried out on this topic.');
}

# =========================
sub beforeCommonTagsHandler {

    _Debug("beforeCommonTagsHandler");

    return unless $globControlled;

    my $query = Foswiki::Func::getCgiQuery();
    return unless ($query);

    my $qAction;
    my $qState;

    return
      unless ( $qState = $query->param('APPROVALSTATE')
        and $qAction = $query->param('APPROVALACTION') );

    # so we only do this once
    $query->{'APPROVALSTATE'}  = undef;
    $query->{'APPROVALACTION'} = undef;

    return unless ( $globObj_approval->state->currentState eq $qState );

    # user has already reviewed this state
    return
      if ( $globObj_approval->state->reviewedBy
        && _userInList( $globObj_approval->state->reviewedBy ) );

    # user not allowed to change state
    if ( $globObj_approval->transitionByAction($qAction)->allowedUsers ) {
        return
          unless (
            scalar
            @{ $globObj_approval->transitionByAction($qAction)->allowedUsers }
            == 0
            || _userInArray(
                $globObj_approval->transitionByAction($qAction)->allowedUsers
            )
          );
    }

    _changeState( $qAction, $qState, $_[2], $_[1] );

    return;
}

# change the state
sub _changeState {

    _Debug('Changing state');

    my ( $qAction, $qState, $web, $topic ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $user         = Foswiki::Func::getWikiUserName();
    my $changedState = 0;

    my $notify = $globObj_approval->transitionByAction($qAction)->notify;
    $notify = 0
      if $Foswiki::cfg{Plugins}{$pluginName}{DisableNotify};
    my $notifyCc;

    # state
    my $minSignoff =
      $globObj_approval->transitionByAction($qAction)->signoff / 100 *
      $globObj_approval->transitionByAction($qAction)->getTotalAllowed
      if $globObj_approval->transitionByAction($qAction)->signoff;

    $globObj_approval->state->anotherSignoffInState();

    if ( $minSignoff && $globObj_approval->state->signoff < $minSignoff ) {

        # dont change state, just signoff
        _Debug(
"Concurrent Review - Minimum required to signoff: $minSignoff | Signoff's so far: "
              . $globObj_approval->state->signoff );

        $globObj_approval->state->reviewedBy
          ? $globObj_approval->state->reviewedByConcat( ', ' . $user )
          : $globObj_approval->state->reviewedBy($user);
    }
    else {

        # change state, delete signoff
        $changedState = 1;
        $globObj_approval->state->currentState(
            $globObj_approval->transitionByAction($qAction)->nextState );

        # FIXME
        if ($notify) {
            if ( $globObj_approval->state->reviewedBy ) {
                foreach ( split( /,/, $globObj_approval->state->reviewedBy ) ) {
                    $notifyCc .= Foswiki::Func::wikiToEmail($_) . ', ';
                }
                $notifyCc .= Foswiki::Func::wikiToEmail($user);
            }
            else {
                $notifyCc = Foswiki::Func::wikiToEmail($user);
            }
        }

        $globObj_approval->state->reviewedBy('');
        $globObj_approval->state->signoff('');
    }

    my $saveApproval = {};
    $saveApproval->{'name'}       = $globObj_approval->state->currentState;
    $saveApproval->{'reviewedBy'} = $globObj_approval->state->reviewedBy
      if $globObj_approval->state->reviewedBy;
    $saveApproval->{'signoff'} = $globObj_approval->state->signoff
      if $globObj_approval->state->signoff;
    $meta->remove('APPROVAL');
    $meta->put( 'APPROVAL', $saveApproval );

    # history
    my $date       = Foswiki::Func::formatTime( time(), undef, 'servertime' );
    my $mixedAlpha = $Foswiki::regex{mixedAlpha};
    my $fmt        = Foswiki::Func::getPreferencesValue("APPROVALHISTORYFORMAT")
      || '$n$state -- $date';
    $fmt =~ s/\"//go;
    $fmt =~ s/\$quot/\"/go;
    $fmt =~ s!\$n!<br />!go;
    $fmt =~ s!\$n\(\)!<br />!go;
    $fmt =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    my $ns = $globObj_approval->transitionByAction($qAction)->nextState;
    $fmt =~ s/\$state/$ns/go;
    $fmt =~ s/\$wikiusername/$user/geo;
    $fmt =~ s/\$date/$date/geo;
    $globObj_approval->historyConcat("\r\n") if $globObj_approval->history;
    $globObj_approval->historyConcat($fmt);
    $meta->remove("APPROVALHISTORY");
    $meta->put( 'APPROVALHISTORY',
        { name => 'APPROVALHISTORY', value => $globObj_approval->history } );

    # save
    $CalledByMyself = 1;
    my $saveError = Foswiki::Func::saveTopic(
        $web, $topic, $meta, $text,
        {
            minor   => 1,
            dontlog => 1
        }
    );
    if ($saveError) {
        my $url = Foswiki::Func::getOopsUrl( $web, $topic, "saveerr", $saveError );
        Foswiki::Func::redirectCgiQuery( undef, $url );
        return 0;
    }

    # need to parse the approval again here, so we can find out
    # who needs to be notified in the next state.
    # would need to parse the approval again anyway, as the state has
    # changed and so might the permissions and actions of the current user
    _parseApprovalDef();

    if ( $notify && $changedState && $globObj_approval->transitions ) {

        # load template
        my $emailOut = Foswiki::Func::readTemplate('approvalnotify') || <<'HERE';
From: %EMAILFROM%
To: %EMAILTO%
Cc: %EMAILCC%
Subject: %SUBJECT%
MIME-Version: 1.0
Content-Type: text/plain

ERROR: No approvalnotify notification template installed - please inform %WIKIWEBMASTER%
HERE

        my $notifyFrom =
             $Foswiki::cfg{WebMasterEmail}
          || Foswiki::Func::getPreferencesValue('WIKIWEBMASTER')
          || 'fosiwkiwebmaster@example.com';
        $emailOut =~ s/%EMAILFROM%/$notifyFrom/go;

        my $notifyTo;
        my $nextApprovers;
        while ( my ( $action, $transition ) =
            each( %{ $globObj_approval->transitions } ) )
        {
            for (
                @{
                    $globObj_approval->transitionByAction($action)->allowedUsers
                }
              )
            {
                my $allowedUser = $_;
                my $mainweb     = Foswiki::Func::getMainWebname();
                $allowedUser =~ s/$mainweb\.//g;

                # names of users who can approve the next state
                $nextApprovers
                  ? $nextApprovers .= ', ' . $allowedUser
                  : $nextApprovers = $allowedUser;
            }

            # email addresses of users who can approve the next state
            for (
                @{
                    $globObj_approval->transitionByAction($action)->allowedUsers
                }
              )
            {
                my $email = Foswiki::Func::wikiToEmail($_);
                $notifyTo .= $email . ', '
                  unless $notifyTo =~ m/$email/;
            }
        }
        if ( $globObj_approval->preferenceByKey('ADDITIONALNOTIFY') ) {

            # additional users to be notified on state change
            # for example: line managers, project managers, stakeholders, etc
            foreach (
                split(
                    /,/, $globObj_approval->preferenceByKey('ADDITIONALNOTIFY')
                )
              )
            {
                my $email = Foswiki::Func::wikiToEmail($_);

                # dont email out twice
                $notifyCc .= ', ' . $email
                  unless $notifyCc =~ m/$email/
                      || $notifyTo =~ m/$email/
                ;    # FIXME - seems to add to Cc even though in To, but why...
            }
        }
        $emailOut =~ s/%EMAILTO%/$notifyTo/go;
        $emailOut =~ s/%EMAILCC%/$notifyCc/go;

        my $notifySubject = "Change of state at %WEB%.%TOPIC%";
        $emailOut =~ s/%SUBJECT%/$notifySubject/go;

        $emailOut =~ s/%WEB%/$web/go;
        $emailOut =~ s/%TOPIC%/$topic/go;

        $emailOut =~ s/%PREVSTATE%/$qState/go;
        my $cs = $globObj_approval->state->currentState;
        $emailOut =~ s/%NEXTSTATE%/$cs/go;

        $emailOut =~ s/%NEXTSTATEAPPROVERS%/$nextApprovers/go;
        my $m = $globObj_approval->state->message;
        $emailOut =~ s/%NEXTSTATEMESSAGE%/$m/go;

        my $url = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
        $emailOut =~ s/%TOPICLINK%/$url/go;

        $emailOut = _expandVars($emailOut);

        if ( $Foswiki::cfg{Plugins}{$pluginName}{DebugNotify} ) {

            # dont send email, just output in debug
            # used for testing
            _Debug( '--- Email Notification ---' . "\n" . $emailOut );
        }
        else {
            my $mailError = Foswiki::Func::sendEmail($emailOut);
            if ($mailError) {
                _Warn($mailError);
            }
        }
    }

    # log
    $changedState
      ? _Log(
        "State changed from $qState to "
          . $globObj_approval->state->currentState
          . " by $user",
        $web,
        $topic
      )
      : _Log( "$user has reviewed the state '$qState'", $web, $topic );
}

# =========================
# Check edit permissions for topics under control
sub beforeEditHandler {
    _Debug('beforeEditHandler');
    _checkEdit();
}

sub beforeSaveHandler {
    return 1 if $CalledByMyself;
    _Debug('beforeSaveHandler');
    _checkEdit();
}

sub beforeAttachmentSaveHandler {
    _Debug('beforeAttachmentSaveHandler');
    _checkEdit();
}

# checks user is in 'allow edit' column
sub _checkEdit {

    return unless $globControlled;
    _Debug('topic is under control');

    if ( !_userInList( $globObj_approval->state->{allowedEdit}, 1 ) ) {
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Edit topic',
'The %SYSTEMWEB%.ApprovalPlugin controls this topic. You are not permitted to edit this topic'
            ]
        );
    }
}

# =========================
sub _cleanField {
    my ($text) = @_;
    $text = "" if ( !$text );
    $text =~ s/^\s*//go;
    $text =~ s/\s*$//go;
    $text =~ s/[^A-Za-z0-9_\.]//go;    # Need do for web.topic
    return $text;
}

# Expands common variables on the text, if there is any text
sub _expandVars {
    my ($text) = @_;
    $text =~ m/%.*%/
      ? return Foswiki::Func::expandCommonVariables($text)
      : return $text;
}

# Pulls in the modules we require. Done conditionally to avoid unnecessary compilation
sub _doRequire {
    require Foswiki::Plugins::ApprovalPlugin::Approval;
    require Foswiki::Plugins::ApprovalPlugin::State;
    require Foswiki::Plugins::ApprovalPlugin::Transition;
}

# =========================
# is user admin?
sub _isAdmin {
    return Foswiki::Func::isAnAdmin();
}

# checks if current user is in list
sub _userInList {
    my ( $list, $allowAdmin ) = @_;

    return 1 unless $list;

    if ($allowAdmin) {
        return 1 if _isAdmin();
    }


# loop though list, check if group or user, if group find out if allowed. if user, check if its signed in user. else return 0
    for ( split( /,/, $list ) ) {
        if ( Foswiki::Func::isGroup($_) ) {
            $_ =~ s/ //;
            return 1 if Foswiki::Func::isGroupMember($_);
        }
        else {
            my $user = Foswiki::Func::getWikiName();
            return 1 if ( $_ =~ m/$user$/ );
        }
    }
    return 0;
}

# checks if current user is in array
sub _userInArray {
    my ( $array, $allowAdmin ) = @_;

    return 1 unless $array;

    if ($allowAdmin) {
        return 1 if _isAdmin();
    }

    for ( @{$array} ) {
        if ( Foswiki::Func::isGroup($_) ) {
            $_ =~ s/ //;
            return 1 if Foswiki::Func::isGroupMember($_);
        }
        else {
            my $user = Foswiki::Func::getWikiUserName();
            return 1 if ( $_ =~ m/$user$/ );

            #return 1 if (  $_ eq $user );
        }
    }
    return 0;
}

# Checks the user exists
sub _userExists {
    my $user = shift;

    # SMELL: Not very good way to check...
    # could iterate over list of users? - might take a long time...
    return Foswiki::Func::topicExists( undef, $user );
}

# =========================
# HTML returned message
sub _Return {
    my ( $text, $error ) = @_;

    my $out = '<span class="ApprovalPluginMessage ';
    $out .= 'foswikiAlert' if $error;
    $out .= '">';
    $out .= " %SYSTEMWEB%.$pluginName - $text";
    $out .= '</span>';

    return $out;
}

# write to debug.txt
sub _Debug {
    my $text = shift;
    my $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    Foswiki::Func::writeDebug("- Foswiki::Plugins::${pluginName}: $text") if $debug;
}

# write warning
sub _Warn {
    my $text = shift;
    Foswiki::Func::writeWarning("- Foswiki::Plugins::${pluginName}: $text");
}

# logs actions in the standard foswiki log
sub _Log {
    my ( $text, $web, $topic ) = @_;

    _Debug($text);

    return
      ; # SMELL: As this uses an internal foswiki function, it is unreliable and therefore disabled

    my $logAction = $Foswiki::cfg{Plugins}{$pluginName}{Log} || 0;

    if ($logAction) {
        $Foswiki::Plugins::SESSION
          ? $Foswiki::Plugins::SESSION->writeLog( "approval", "$web.$topic",
            $text )
          : Foswiki::Store::writeLog( "approval", "$web.$topic", $text );
        Foswiki::Store::writeLog( "approval", "$web.$topic", $text );
    }
}

1;
