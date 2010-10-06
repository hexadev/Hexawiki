# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexWebListPlugin;

use strict;
use vars qw( $VERSION $RELEASE $core $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION);

$VERSION = '$Rev: 5698 (2009-12-02) $';
$RELEASE = 'v1.51';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Flexible way to display hierarchical weblists';

###############################################################################
sub initPlugin {
  $core = undef;
  Foswiki::Func::registerTagHandler('FLEXWEBLIST', \&renderFlexWebList);
  return 1;
}

###############################################################################
sub newCore {

  return $core if $core;
  require Foswiki::Plugins::FlexWebListPlugin::Core;
  $core = new Foswiki::Plugins::FlexWebListPlugin::Core;
  return $core;
}

###############################################################################
sub renderFlexWebList {
  return newCore()->handler(@_);
}

###############################################################################
1;
