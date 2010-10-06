# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2010 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::EditChapterPlugin;

use strict;

use Foswiki::Func;

use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $sharedCore $baseWeb $baseTopic $enabled 
);

$VERSION = '$Rev: 6337 (2010-02-15) $';
$RELEASE = '2.12';
$SHORTDESCRIPTION = 'An easy sectional edit facility';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  $sharedCore = undef;

  Foswiki::Func::registerTagHandler('EXTRACTCHAPTER', \&EXTRACTCHAPTER);
  Foswiki::Func::addToZone('head', 'EDITCHAPTERPLUGIN', <<'HERE', 'JQUERYPLUGIN::FOSWIKI');
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpstyles.css" type="text/css" media="all" />
HERE
  Foswiki::Func::addToZone('body', 'EDITCHAPTERPLUGIN', <<'HERE', 'JQUERYPLUGIN::FOSWIKI');
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpjavascript.js"></script>
HERE

  return 1;
}

###############################################################################
sub finishHandler {
  $sharedCore = undef;
}

###############################################################################
sub initCore {

  unless ($sharedCore) {
    require Foswiki::Plugins::EditChapterPlugin::Core;
    $sharedCore = new Foswiki::Plugins::EditChapterPlugin::Core(@_);
  }

  return $sharedCore;
}

###############################################################################
sub commonTagsHandler {
  ### my ( $text, $topic, $web, $meta ) = @_;

  my $context = Foswiki::Func::getContext();
  return unless $context->{'view'};
  return unless $context->{'authenticated'};

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param('contenttype') || '';
  return if $contenttype eq "application/pdf"; 

  my $core = initCore($baseWeb, $baseTopic);
  $core->commonTagsHandler(@_);
}

###############################################################################
sub postRenderingHandler {
  return unless $sharedCore;
  my $translationToken = $sharedCore->{translationToken};
  $_[0] =~ s/$translationToken//g;
  $_[0] =~ s/(<a name=["'])A_01_/$1/g; # cleanup anchors
  $_[0] =~ s/(<a href=["']#)A_01_/$1/g; 

}

###############################################################################
sub EXTRACTCHAPTER {
  my $core = initCore($baseWeb, $baseTopic);
  return $core->handleEXTRACTCHAPTER(@_);
}

1;
