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
package Foswiki::Plugins::ObjectPlugin;

use strict;
use Assert;
use Error qw( :try );
use JSON -convert_blessed_universally;
# use Data::Dumper;

require Foswiki::Func;
require Foswiki::Plugins;
require Foswiki::OopsException;
require Foswiki::AccessControlException;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $disableStandardProcessing $debug $defaultsAdded );
$debug = 0; # toggle me
$VERSION = '$Rev: 8478 (2010-08-12) $';
$RELEASE = '1.01';
$SHORTDESCRIPTION = 'Use a topic as an Object store.';

sub initPlugin {

    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ObjectPlugin and Plugins.pm $Foswiki::Plugins::VERSION. 1.026 required.' );
    }

	$Foswiki::Plugins::SESSION->{objectplugin} = {forms => {}, templates => {}};


    Foswiki::Func::registerRESTHandler( 'save', \&_saveObjectRESTHandler );
	Foswiki::Func::registerRESTHandler( 'new', \&_newObjectRESTHandler );
	Foswiki::Func::registerRESTHandler( 'view', \&_viewObjectRESTHandler );
	Foswiki::Func::registerRESTHandler( 'delete', \&_deleteObjectRESTHandler );
	Foswiki::Func::registerRESTHandler( 'move', \&_moveObjectRESTHandler );
    Foswiki::Func::registerTagHandler( 'OBJECTSEARCH', \&_handleObjectSearch, 'context-free');
	Foswiki::Func::registerTagHandler( 'OBJECTBUTTON', \&_handleObjectButton, 'context-free');
    # $debug = $Foswiki::cfg{Plugins}{ObjectPlugin}{Debug} || 1;
	
	$disableStandardProcessing = 0;
	$defaultsAdded = 0;
    return 1;
};

sub init {
	require Foswiki::Plugins::ObjectPlugin::ObjectSet;
	require Foswiki::Plugins::ObjectPlugin::Object;
	Foswiki::Plugins::ObjectPlugin::Object::setNow();
}

sub disableStandardProcessing {
	$disableStandardProcessing = 1;
}

sub commonTagsHandler {
    my( $otext, $topic, $web, $meta ) = @_;

	return if $disableStandardProcessing;
    return unless ( $_[0] =~ m/%OBJECT{.*}%/o );

	init();

	# load everything including text and deleted objects
    my $os = Foswiki::Plugins::ObjectPlugin::ObjectSet::load($_[2], $_[1], $_[0], undef, 0, 1);
	$_[0] = $os->renderForDisplay();
}

sub beforeSaveHandler {
    my( $text, $topic, $web ) = @_;

	return if $disableStandardProcessing;
	return unless $_[0] =~ m/%OBJECT{.*?}%/o;
	# OK, the topic itself is being saved
	# and there are some objects that may have been 
	# manually added. Process the objects and add UIDs 
	# and other default attributes

	init();

    my %seenUID;
    my $os = Foswiki::Plugins::ObjectPlugin::ObjectSet::load($_[2], $_[1], $_[0], undef, 0, 1);
	# writeDebug(Dumper($os));
    foreach my $object (@{$os->{OBJECTS}}) {
        next unless ref($object);
        $object->populateDefaultFields();
        if ( $seenUID{$object->{uid}} ) {
            # This can happen if there has been a careless
            # cut and paste. In this case, the first instance
            # of the object gets the old UID.
            $object->{uid} = $object->getNewUID();
        }
        $seenUID{$object->{uid}} = 1;
    }
    $_[0] = $os->stringify();
}

# Perform filtered search for all objects
sub _handleObjectSearch {
    my( $session, $attrs, $topic, $web ) = @_;

	init();
    my $sort = $attrs->remove( 'sort' );
	my $format = $attrs->remove( 'format' );

    my $objects = Foswiki::Plugins::ObjectPlugin::ObjectSet::allObjectsInWebs( $web, $attrs, 0 );
    $objects->sort( $sort );
	return $objects->stringify() if $disableStandardProcessing;
    return $objects->renderForDisplay( $format );
}

sub _handleObjectButton {
    my( $session, $attrs, $topic, $web ) = @_;

	my $type = $attrs->{_DEFAULT} || '';
	return '' unless $type;
	$web = $attrs->{web} if $attrs->{web};
	$topic = $attrs->{topic} if $attrs->{topic};
	my $insertPos = $attrs->{insertpos} || 'prepend';
	
	my $button = <<HERE;
<button title="New object" id="newObjectButton" type="%TYPE%"> Add a new %TYPE% </button>%SELECT%
%INCLUDE{"%SYSTEMWEB%.JQueryQuickSearch" target="div.object-container" position="after" label="Search entries"}%
<div id="objectsObject"></div>
HERE
	addDefaultsToPage();
	Foswiki::Func::addToZone('body','OBJECTBUTTON_JS', <<"HERE",'OBJECTPLUGIN_JS');
<script type='text/javascript'>
jQuery(function(){
    jQuery('#newObjectButton').click(function(){
		foswiki.ObjectPlugin.newObject(jQuery('#objectType').val(),'$web','$topic','$insertPos');
	});
});
</script>
HERE
	my $select = qq(<select id="objectType">%OPTIONS%</select>);
	my @types = split(/\s*,\s*/,$type);
	if (scalar(@types) > 1) {
		$button =~ s/%TYPE%//g;
		my $options = '';
		foreach my $t (@types) {
			$options .= "<option>$t</option>";
		}
		$select =~ s/%OPTIONS%/$options/;
	} else {
		$button =~ s/%TYPE%/$types[0]/g;
		$select = '<input type="hidden" value="'.$types[0].'" id="objectType">';
	}
	$button =~ s/%SELECT%/$select/g;
	return $button;
}

sub addDefaultsToPage {
	return if $defaultsAdded;
	$defaultsAdded = 1;
	
    my $src = $debug ? '_src' : ''; # not using this at the moment, object$src.js

    Foswiki::Func::addToZone('head','OBJECTPLUGIN_CSS', <<HERE,'JQUERYPLUGIN::THEME');
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/ObjectPlugin/object.css" type="text/css" media="all" />
HERE
    Foswiki::Func::addToZone('body','OBJECTPLUGIN_JS', <<"HERE",'HIJAXPLUGIN_JS');
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/ObjectPlugin/object.js'></script>
<script type='text/javascript'>
jQuery(function(){
    jQuery('div.object-container').initObject();
});
</script>
HERE

}

# =========================
# REST functions

sub _saveObjectRESTHandler {
    my $session = shift;
	return objectResponse($session,\&_objectSave);
}

sub _newObjectRESTHandler {
    my $session = shift;
	return objectResponse($session,\&_objectNew);
}

sub _viewObjectRESTHandler {
    my $session = shift;
	return objectResponse($session,\&_objectView);
}

sub _deleteObjectRESTHandler {
    my $session = shift;
	return objectResponse($session,\&_objectDelete);
}

sub _moveObjectRESTHandler {
    my $session = shift;
	return objectResponse($session,\&_objectMove);
}

sub _objectSave {
	my ($web, $topic, $query) = @_;
	if ($query->param('uid')) {
		return _objectUpdate($web, $topic, $query, 'updateFromQuery');
	} else {
		return _objectNew(@_);
	}
}

sub _objectDelete {
	my ($web, $topic, $query) = @_;
	return _objectUpdate($web, $topic, $query, 'deleteObject');
}

sub _objectUpdate {
	my ($web, $topic, $query, $fn) = @_;
	my $uid = $query->param('uid');

	my ($object, $pre, $post, $meta) = Foswiki::Plugins::ObjectPlugin::ObjectSet::loadToFind(
		$uid, $web, $topic, undef, 'CHANGE' );

	if (defined $object) {
		$object->$fn($query);
		$disableStandardProcessing = 1;
		Foswiki::Func::saveTopic($web, $topic, $meta, $pre.$object->stringify().$post, { comment => 'op save' });
		# $object->{id} = $object->{uid};
		return $object;
	} else {
		throw Foswiki::OopsException('object',
									def => 'noobjectuid',
									web => $web,
									topic => $topic,
									params => [ $uid, "$web.$topic" ] );
	}
}

sub _objectNew {
	my ($web, $topic, $query) = @_;

	my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
	checkAccess('CHANGE', $web, $topic, $text, $meta);  # can throw AccessControlException

	my $object = Foswiki::Plugins::ObjectPlugin::Object::createFromQuery($web, $topic, $query);
	$object->{uid} = ''; # belts and braces, set in stringify if empty
	# writeDebug(Dumper($object));
	$text = insertObject($object, $query, $text);
	$disableStandardProcessing = 1;
	Foswiki::Func::saveTopic($web, $topic, $meta, $text,{ comment => 'new object' });
	# $object->{id} = $object->{uid};
	# $object = {
		# uid => $object->{uid}
	# };
	return $object;
}

sub _objectView {
	my ($web, $topic, $query) = @_;
	my $uid = $query->param('uid');
	my $context = $query->param('context');
	
	if ($context eq 'edit' && !$uid) {
		my $type = $query->param('type');
		throw Foswiki::OopsException('object',
									def => 'missingobjecttype',
									web => $web,
									topic => $topic,
									params => $query->query_string() ) unless $type;
		my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
		checkAccess('CHANGE', $web, $topic, $text, $meta);  # can throw AccessControlException
		return new Foswiki::Plugins::ObjectPlugin::Object($web, $topic, 'type="'.$type.'"', '', $meta);
	}

	my ($object, $pre, $post, $meta) = Foswiki::Plugins::ObjectPlugin::ObjectSet::loadToFind(
		$uid, $web, $topic, undef, 'VIEW' );

	if (defined $object) {
		return $object;
	} else {
		throw Foswiki::OopsException('object',
									def => 'noobjectuid',
									web => $web,
									topic => $topic,
									params => [ $uid, "$web.$topic" ] );
	}

}

# SMELL: can this be optimised? - 
# possibly slow when there are lots of objects in a topic - depends on performance of loadToFind
# and probably painfully slow when an object to be moved has lots of attachments
sub _objectMove {
	my ($web, $topic, $query) = @_;
	my $uid = $query->param('uid');
	my $target = $query->param('target');
	my ($newweb, $newtopic) = Foswiki::Func::normalizeWebTopicName('', $target);

	my ($object, $pre, $post, $meta) = 
		Foswiki::Plugins::ObjectPlugin::ObjectSet::loadToFind($uid, $web, $topic, undef, 'CHANGE', 1);

	throw Foswiki::OopsException('object',
								def => 'noobjectuid',
								web => $web,
								topic => $topic,
								params => [ $uid, "$web.$topic" ] ) unless defined $object; 
	writeDebug("moving uid $uid - ".$object->stringify()." $pre $post");
								
	my $curUser = $Foswiki::Plugins::SESSION->{user};
	my ($newmeta, $newtext) = (undef, '');
	my $woa = $query->param('woattachments') || 0; # default is to move with associated attachments
	
	if ($newweb eq $Foswiki::cfg{TrashWebName}) { # trashing an object
		$Foswiki::Plugins::SESSION->{user} = $Foswiki::cfg{AdminUserWikiName};
		($newmeta, $newtext) = Foswiki::Func::readTopic($newweb, $newtopic);
	} else {
		($newmeta, $newtext) = Foswiki::Func::readTopic($newweb, $newtopic);
		checkAccess('CHANGE', $newweb, $newtopic, $newtext, $newmeta);  # can throw AccessControlException
	}
	
	if ($object->{attachments}) {
		unless ($woa) { # move with attachements
				foreach my $attachment (@{$object->{attachments}}) {
					# ouch! can only move attachments one at a time
					Foswiki::Func::moveAttachment($web, $topic, $attachment, $newweb, $newtopic, undef)
						if Foswiki::Func::attachmentExists($web, $topic, $attachment);
				}
				# meta data has changed, so...
				($newmeta, $newtext) = Foswiki::Func::readTopic($newweb, $newtopic);
				($meta, my $ignore) = Foswiki::Func::readTopic($web, $topic);
		} else { # move w/o attachments so remove them from the object
			$object->{attachments} = ();
		}
	}
	
	$newtext = insertObject($object, $query, $newtext);
	$disableStandardProcessing = 1;
	Foswiki::Func::saveTopic($newweb, $newtopic, $newmeta, $newtext, { comment => "moved object $uid to here from $web.$topic" });

	$Foswiki::Plugins::SESSION->{user} = $curUser; # switch back incase we did a switch to admin
	
	Foswiki::Func::saveTopic($web, $topic, $meta, $pre.$post, { comment => "(re)moved object $uid to $newweb.$newtopic" });
	return $object;
}

sub insertObject {
	my ($object, $query, $text) = @_;
	my $inserted = 0;
	# add new object at the bottom? default is at the top
	my $otext = $object->stringify();
	my $position = $query->param('insertpos') || $object->{insertpos} || 'prepend';
	my $append = $position =~ m/(bottom|after|append)/io ? 1 : 0;
	my $location = $query->param('insertloc') || $object->{insertloc} || 'topic:';
	my ($target, $match) = split(/:/,$location,2);
	if ($target eq 'section') {
		if ($append) {
			$text =~ s/(%ENDSECTION{.*?name="$match".*?}%)/$otext\n$1/o;
		} else {
			$text =~ s/(%SECTION{.*?name="$match".*?}%)/$1\n$otext/o;
		}
		$inserted = 1 if $text =~ m/$otext/;
	} elsif ($target eq 'object') {
		my ($obj, $pre, $post, $meta) = 
			Foswiki::Plugins::ObjectPlugin::ObjectSet::loadToFind(
				$match, $object->{web}, $object->{topic}, $text, undef, 1);

		# throw Foswiki::OopsException('object',
							# def => 'noobjectuid',
							# web => $object->{web},
							# topic => $object->{topic},
							# params => [ $match, "$object->{web}.$object->{topic}" ] ) unless defined $obj; 
		if ($obj) {
			if ($append) {
				$text = $pre.$obj->stringify()."\n".$otext.$post;
			} else {
				$text = $pre.$otext."\n".$obj->stringify().$post;
			}
			$inserted = 1;
		}
	} elsif ($target eq 'target') {
		if ($append) {
			$text =~ s/($match)/$1\n$otext/o;
		} else {
			$text =~ s/($match)/$otext\n$1/o;
		}
		$inserted = 1 if $text =~ m/$otext/;
	} 
	if ($target eq 'topic' || !$inserted) {
		$text = $append ? $text."\n".$otext : $otext."\n".$text;
	}
	return $text;
}

sub objectResponse {
	my ($session, $method) = @_;
    my $query = Foswiki::Func::getCgiQuery();
	my $context = $query->param('context') || 'view';
	my $result = '';
	my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $query->param('topic'));

    try {
        init();
		my $object = &$method($web, $topic, $query);
		$result = formatResponse($query, $context, $object);

	} catch Foswiki::AccessControlException with {
        my $e = shift;
        unless( $session->{users}->{loginManager}->forceAuthentication() ) {
            # Login manager did not want to authenticate, perhaps because
            # we are already authenticated.
            my $exception = new Foswiki::OopsException(
                'accessdenied',
                web => $e->{web}, topic => $e->{topic},
                def => 'topic_access',
                params => [ $e->{mode}, $e->{reason} ] );

            $exception->redirect( $session );
        }

    } catch Foswiki::OopsException with {
        shift->redirect( $session );

    } catch Error::Simple with {
        my $e = shift;
		my $mess = $e->stringify();  # or $e->{-text}
		$session->writeWarning( $mess );
		# tell the browser where to look for more help
		$mess =~ s/ at .*$//s;
		# cut out pathnames from public announcement
		$mess =~ s#/[\w./]+#path#g;
		my $exception = new Foswiki::OopsException('object',
												web => $web, topic => $topic,
												def => 'error_simple',
												params => [ $mess ] );
		$exception->redirect( $session );

	} otherwise {
		my $exception = new Foswiki::OopsException('object',
												web => $web, topic => $topic,
												def => 'unspecified_error');
		$exception->redirect( $session );
    };

	return $result;
}

sub formatResponse {
	my ($query, $context, $object) = @_;

	my $redirectto = $query->param('redirectto');
	if ( defined($redirectto) ) {
		# if redirecting with the skin or cover containing 'ajax', 
		# the HijaxPlugin will return the result as JSON
	    Foswiki::Func::redirectCgiQuery( undef, $redirectto );
		return undef;
	}
	if ( $query->param('asobject') ) {
		# writeDebug(Dumper($object));
		my $json = JSON->new->allow_nonref->allow_blessed->convert_blessed->encode($object);
		# writeDebug("$json");
		return $json;
	}
	my $result = $context eq 'edit' ? $object->renderForEdit() : $object->renderForDisplay();

    return $result;
}

sub writeDebug {
	Foswiki::Func::writeDebug("ObjectPlugin - $_[0]") if $debug;
}

sub checkAccess {
	my ($type, $web, $topic, $text, $meta) = @_;
	my $user = Foswiki::Func::getWikiName();
	my $access = Foswiki::Func::checkAccessPermission($type, $user, $text, $topic, $web, $meta);
	throw Foswiki::AccessControlException(
            $type, $user, $web, $topic,
            $Foswiki::Plugins::SESSION->security->getReason()) unless $access;
}

1;
