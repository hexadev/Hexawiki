#!/usr/bin/perl -w

use strict;

BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build( "TinyMCEPlugin" );
$build->build($build->{target});


