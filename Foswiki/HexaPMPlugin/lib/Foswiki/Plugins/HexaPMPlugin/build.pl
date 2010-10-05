#!/usr/bin/perl -w
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('HexaPMPlugin');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible Foswiki installation.
# These defaults will be used when expanding tokens in .txt
# files, but be warned, they can be overridden at upload time!

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'https://foswiki.hexa.co';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'https://foswiki.hexa.co/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'https://foswiki.hexa.co/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build($build->{target});

