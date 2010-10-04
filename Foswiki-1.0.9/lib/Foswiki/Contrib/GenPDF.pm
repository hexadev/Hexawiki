#!/usr/local/bin/perl -wI.
#
# GenPDF.pm (converts Foswiki page to PDF using HTMLDOC)
#    (based on PrintUsingPDF pdf script)
#
# This script Copyright (c) 2005 Cygnus Communications
# and distributed under the GPL (see below)
#
# Foswiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
# Additional mess by Patrick Ohl - Biomax Bioinformatics AG
# January 2003
# fixes for Foswiki 4.2 (c) 2008 SvenDowideit@fosiki.com
# 24-Dec-2008 - litt@acm.org
# Fixes for images & title page segfaults.  Include some patches
# from the plugin wiki.  Added
# pdffirstpage GENPDFADDON_FIRSTPAGE toc p1, c1, toc
# pdfdestination GENPDFADDON_DESTINATION view view,save
# pdfpagelayout GENPDFADDON_PAGELAYOUT single single, one, twoleft, tworight
# pdfpagemode GENPDFADDON_PAGEMODE outline document, outline, fullscreen
# pdftitledoc GENPDFADDON_TITLEDOC undef document (file) as title
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

=pod

=head1 Foswiki::Contrib::GenPDF

Foswiki::Contrib::GenPDF - Displays Foswiki page as PDF using HTMLDOC

=head1 DESCRIPTION

See the GenPDFAddOn Foswiki topic for a description.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package Foswiki::Contrib::GenPDF;

use strict;

use Foswiki::Contrib::GenPDFAddOn;

sub viewPDF {

    goto &Foswiki::Contrib::GenPDFAddOn::viewPDF;

}

1;

