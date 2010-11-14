# See bottom of file for license and copyright information
#########################################################################
#
# Main package for the CompareRevisionsAddOn:
#
# This add-on compares the renderd HTML output of two revisions and shows
# the differences broken down to the word-by-word level if necessary.
# The output can be formatted by templates and skins.
#
########################################################################
package Foswiki::Contrib::CompareRevisionsAddOn::Compare;

use strict;
use warnings;

use Foswiki::UI;
use Foswiki::Func;
use Foswiki::Plugins;

use HTML::TreeBuilder;
use Algorithm::Diff;
use Data::Dumper;

my $HTMLElement = 'HTML::Element';
my $class_add   = 'craCompareAdd';
my $class_del   = 'craCompareDelete';
my $class_c1    = 'craCompareChange1';
my $class_c2    = 'craCompareChange2';
my $interweave;
my $context;
my $scripturl;

sub compare {
    my $session = shift;

    $Foswiki::Plugins::SESSION = $session;

    my $query   = $session->{request};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};

    unless ( Foswiki::Func::topicExists( $webName, $topic ) ) {
        Foswiki::Func::redirectCgiQuery( $query,
            Foswiki::Func::getOopsUrl( $webName, $topic, 'oopsmissing' ) );
    }

    $scripturl = Foswiki::Func::getScriptUrl( $webName, $topic, 'compare' );

    # Check, if interweave or sidebyside

    my $renderStyle =
         $query->param('render')
      || &Foswiki::Func::getPreferencesValue( "COMPARERENDERSTYLE", $webName )
      || 'interweave';
    $interweave = $renderStyle eq 'interweave';

    # Check context

    $context = $query->param('context');
    $context = &Foswiki::Func::getPreferencesValue( "COMPARECONTEXT", $webName )
      unless defined($context);
    $context = -1 unless defined($context) && $context =~ /^\d+$/;

    # Get Revisions. rev2 default to maxrev, rev1 to rev2-1

    my $maxrev = ( Foswiki::Func::getRevisionInfo( $webName, $topic ) )[2];
    my $rev2 = $query->param('rev2') || $maxrev;
    $rev2 =~ s/^1\.// if $rev2;

    # Fix for Codev.SecurityAlertExecuteCommandsWithRev
    $rev2 = $maxrev unless ( $rev2 =~ s/.*?([0-9]+).*/$1/o );
    $rev2 = $maxrev if $rev2 > $maxrev;
    $rev2 = 1       if $rev2 < 1;
    my $rev1 = $query->param('rev1') || $rev2 - 1;
    $rev1 =~ s/^1\.// if $rev1;

    # Fix for Codev.SecurityAlertExecuteCommandsWithRev
    $rev1 = $maxrev unless ( $rev1 =~ s/.*?([0-9]+).*/$1/o );
    $rev1 = $maxrev if $rev1 > $maxrev;
    $rev1 = 1       if $rev1 < 1;

    ( $rev1, $rev2 ) = ( $rev2, $rev1 ) if $rev1 > $rev2;

    # Set skin temporarily to classic, so attachments and forms
    # are not rendered with twisty tables

    my $savedskin = $query->param('skin');
    $query->param( 'skin', 'classic' );

    # Get the HTML trees of the specified versions

    my $tree2 = _getTree( $session, $webName, $topic, $rev2 );
    if ( $tree2 =~ /^http:.*oops/ ) {
        Foswiki::Func::redirectCgiQuery( $query, $tree2 );
    }

    # TablePlugin must reinitiatilise to reset all table counters (Item1911)
    if ( defined &Foswiki::Plugins::TablePlugin::initPlugin ) {
        if ( defined &Foswiki::Plugins::TablePlugin::initialiseWhenRender ) {
            Foswiki::Plugins::TablePlugin::initialiseWhenRender();
        }
        else {

            # If TablePlugin does not have the reinitialise API
            # we use try a shameless hack instead
            if ( defined $Foswiki::Plugins::TablePlugin::initialised ) {
                $Foswiki::Plugins::TablePlugin::initialised = 0;
            }
        }
    }

    my $tree1 = _getTree( $session, $webName, $topic, $rev1 );
    if ( $tree1 =~ /^http:.*oops/ ) {
        Foswiki::Func::redirectCgiQuery( $query, $tree1 );
    }

    # Reset the skin

    if ($savedskin) {
        $query->param( 'skin', $savedskin );
    }
    else {
        $query->delete('skin');
    }

    # Get revision info for the two revisions

    my $revinfo1 = getRevInfo( $webName, $rev1, $topic );
    my $revinfo2 = getRevInfo( $webName, $rev2, $topic );
    my $revtitle1 = 'r' . $rev1;
    my $revtitle2 = 'r' . $rev2;

    # get and process templates

    my $tmpl = Foswiki::Func::readTemplate(
        $interweave ? 'compareinterweave' : 'comparesidebyside' );

    $tmpl =~ s/\%META{.*?\}\%\s*//g;    # Meta data already processed
                                        # in _getTree
    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $webName );
    $tmpl =~ s/%REVTITLE1%/$revtitle1/g;
    $tmpl =~ s/%REVTITLE2%/$revtitle2/g;
    $tmpl =~ s/%REVINFO1%/$revinfo1/g;
    $tmpl =~ s/%REVINFO2%/$revinfo2/g;
    $tmpl = Foswiki::Func::renderText( $tmpl, $webName );
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    my (
        $tmpl_before, $tmpl_us, $tmpl_u, $tmpl_c,
        $tmpl_a,      $tmpl_d,  $tmpl_after
    );

    ( $tmpl_before, $tmpl_us, $tmpl_u, $tmpl_c, $tmpl_a, $tmpl_d, $tmpl_after )
      = split( /%REPEAT%/, $tmpl );
    $tmpl_u = $tmpl_us unless $tmpl_u =~ /\S/;
    $tmpl_c = $tmpl_u  unless $tmpl_c =~ /\S/;
    $tmpl_a = $tmpl_c  unless $tmpl_a =~ /\S/;
    $tmpl_d = $tmpl_a  unless $tmpl_d =~ /\S/;

    # Start the output

    my $output = $tmpl_before;

    # Compare the trees

    my @list1 = $tree1->content_list;
    my @list2 = $tree2->content_list;

    my @changes = Algorithm::Diff::sdiff( \@list1, \@list2, \&_elementHash );

    my $unchangedSkipped = 0;
    for my $i_action ( 0 .. $#changes ) {
        my $action = $changes[$i_action];

        # Skip unchanged section according to context

        if ( $action->[0] eq 'u' && $context >= 0 ) {

            my $skip          = 1;
            my $start_context = $i_action - $context;
            $start_context = 0 if $start_context < 0;
            my $end_context = $i_action + $context;
            $end_context = $#changes if $end_context > $#changes;

            for my $i ( $start_context .. $end_context ) {
                next if $changes[$i]->[0] eq 'u';
                $skip = 0;
                last;
            }

            if ($skip) {

                unless ($unchangedSkipped) {
                    $output .= $tmpl_us;
                    $unchangedSkipped = 1;
                }
                next;
            }
        }
        $unchangedSkipped = 0;

        # Process text;

        my ( $text1, $text2 );

        # If elements differ, but are of the same type, then
        # go deeper into the tree

        if (   $action->[0] eq 'c'
            && ref( $action->[1] )    eq $HTMLElement
            && ref( $action->[2] )    eq $HTMLElement
            && $action->[1]->starttag eq $action->[2]->starttag )
        {

            my @sublist1 = $action->[1]->content_list;
            my @sublist2 = $action->[2]->content_list;
            if (   @sublist1
                && @sublist2
                && Algorithm::Diff::LCS( \@sublist1, \@sublist2,
                    \&_elementHash ) >= 0 )
            {

                ( $text1, $text2 ) =
                  _findSubChanges( $action->[1], $action->[2] );
            }
        }

        # Otherwise format this particular action

        ( $text1, $text2 ) = _getTextFromAction($action)
          unless $text1 || $text2;

        my $tmpl =
            $action->[0] eq 'u' ? $tmpl_u
          : $action->[0] eq 'c' ? $tmpl_c
          : $action->[0] eq '+' ? $tmpl_a
          :                       $tmpl_d;

        # Do the replacement of %TEXT1% and %TEXT2% simultaneously
        # to prevent difficulties with text containing '%TEXT2%'
        $tmpl =~ s/%TEXT(1|2)%/$1==1?$text1:$text2/ge;
        $output .= $tmpl;

    }

    # Print remainder of document

    my $revisions = "";
    my $i         = $maxrev;
    while ( $i > 0 ) {
        $revisions .=
"  <a href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=$i\">r$i</a>";

        last
          if $i == 1
              || (   $Foswiki::cfg{NumberOfRevisions} > 0
                  && $i == $maxrev - $Foswiki::cfg{NumberOfRevisions} + 1 );
        if ( $i == $rev2 && $i - 1 == $rev1 ) {
            $revisions .= "  &lt;";
        }
        else {
            $revisions .=
"  <a href=\"%SCRIPTURLPATH%/compare%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=$i&rev2="
              . ( $i - 1 )
              . (
                $query->param('skin') ? '&skin=' . $query->param('skin') : '' )
              . (
                $query->param('context')
                ? '&context=' . $query->param('context')
                : ''
              )
              . '&render='
              . $renderStyle
              . '">&lt;</a>';
        }
        $i--;
    }

    $tmpl_after =~ s/%REVISIONS%/$revisions/go;
    $tmpl_after =~ s/%CURRREV%/$rev1/go;
    $tmpl_after =~ s/%MAXREV%/$maxrev/go;
    $tmpl_after =~ s/%REVTITLE1%/$revtitle1/go;
    $tmpl_after =~ s/%REVINFO1%/$revinfo1/go;
    $tmpl_after =~ s/%REVTITLE2%/$revtitle2/go;
    $tmpl_after =~ s/%REVINFO2%/$revinfo2/go;

    $tmpl_after =
      Foswiki::Func::expandCommonVariables( $tmpl_after, $topic, $webName );
    $tmpl_after = Foswiki::Func::renderText( $tmpl_after, $webName );
    $tmpl_after =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois
      ;    # remove <nop> and <noautolink> tags

    $output .= $tmpl_after;

# Break circular references to avoid memory leaks. (Tasks:9127)
    $tree1 = $tree1->parent() while defined $tree1->parent();
    $tree1->delete();
    $tree2 = $tree2->parent() while defined $tree2->parent();
    $tree2->delete();
    
    $session->writeCompletePage( $output, 'view' );

}

sub _getTree {

    # Purpose: Get the rendered version of a document as HTML tree

    my ( $session, $webName, $topicName, $rev ) = @_;

    # Read document

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $webName, $topicName, $rev );
    $text .= "\n" . '%META{"form"}%';
    $text .= "\n" . '%META{"attachments"}%';

    $session->enterContext( 'can_render_meta', $meta );
    $text = Foswiki::Func::expandCommonVariables( $text, $topicName, $webName, $meta );
    $text = Foswiki::Func::renderText( $text, $webName );

    $text =~ s/^\s*//;
    $text =~ s/\s*$//;

    # Generate tree

    my $tree = new HTML::TreeBuilder;
    $tree->implicit_body_p_tag(1);
    $tree->p_strict(1);
    if ( $Foswiki::cfg{UseLocale} ) {
        require Encode;
        $text = Encode::decode( $Foswiki::cfg{Site}{CharSet}, $text );
    }
    $tree->parse($text);
    $tree->eof;
    $tree->elementify;
    $tree = $tree->find('body');

    # Remove blank paragraphs

    $_->delete foreach (
        $tree->look_down(
            '_tag' => 'p',
            sub { $_[0]->is_empty }
        )
    );

    return $tree;
}

sub _findSubChanges {

    # Purpose: Finds and formats changes between two HTML::Elements.
    # Returns HTML formatted text, either $text1/2 according to
    # the two revisions, or only $text1 if interwoven output.
    # May be called recursively.

    my ( $e1, $e2 ) = @_;
    my ( $text1, $text2 );

    if ( !ref($e1) && !ref($e2) ) {    # Two text segments

        return $e1 eq $e2
          ? ( $e1, $interweave ? '' : $e2 )
          : _compareText( $e1, $e2 );

    }
    elsif ( ref($e1) ne $HTMLElement || ref($e2) ne $HTMLElement ) {

        # One text, one HTML

        $text1 = _getTextWithClass( $e1, $class_c1 );
        $text2 = _getTextWithClass( $e2, $class_c2 );
        return $interweave ? ( $text1 . $text2, '' ) : ( $text1, $text2 );

    }

    my @list1 = $e1->content_list;
    my @list2 = $e2->content_list;

    if ( @list1 && @list2 ) {    # Two non-empty lists
        die "Huch!:" . $e1->tag . "!=" . $e2->tag
          if $e1->tag ne $e2->tag;
        $text1 = $e1->starttag;
        $text2 = $e2->starttag;
        my @changes =
          Algorithm::Diff::sdiff( \@list1, \@list2, \&_elementHash );
        foreach my $action (@changes) {

            my ( $subtext1, $subtext2 );
            if (
                $action->[0] eq 'c'
                && (   ref( $action->[1] ) ne $HTMLElement
                    || ref( $action->[2] ) ne $HTMLElement
                    || $action->[1]->tag eq $action->[2]->tag )
              )
            {

                ( $subtext1, $subtext2 ) =
                  _findSubChanges( $action->[1], $action->[2] );

            }
            else {
                ( $subtext1, $subtext2 ) = _getTextFromAction($action);
            }

            $text1 .= $subtext1 if $subtext1;
            ( $interweave ? $text1 : $text2 ) .= $subtext2 if $subtext2;
        }

        $text1 .= $e1->endtag;
        $text2 .= $e2->endtag;

        $text2 = '' if $interweave;

    }
    else {    # At least one final HTML element

        $text1 = _getTextWithClass( $e1, $class_c1 );
        $text2 = _getTextWithClass( $e2, $class_c2 );
        if ($interweave) {
            $text1 = $text1 . $text2;
            $text2 = '';
        }
    }

    return ( $text1 || '', $text2 || '' );
}

sub _elementHash {

    # Purpose: Stringify HTML ELement for comparison in Algorithm::Diff
    my $text = ref( $_[0] ) eq $HTMLElement ? $_[0]->as_HTML : "$_[0]";

    # Strip leading & trailing blanks in text and paragraphs
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $text =~ s|(\<p[^>]*\>)\s+|$1|g;
    $text =~ s|\s+(\<\/p\>)|$1|g;

    # Ignore different tables for sorting
    $text =~ s%(\<a href="$scripturl[^"]*sortcol=\d+(\&|\&amp;))table=\d+%$1%g;

    return $text;
}

sub _addClass {

    # Purpose: Add a Class to a subtree

    my ( $element, $class ) = @_;

    $element->attr( 'class', $class );

    foreach my $subelement ( $element->content_list ) {
        _addClass( $subelement, $class ) if ref($subelement) eq $HTMLElement;
    }
}

sub _compareText {

    # Purpose: Compare two text elements. Output as in _findSubChanges

    my ( $text1, $text2 ) = @_;

    my @list1 = split( ' ', $text1 );
    my @list2 = split( ' ', $text2 );

    my @changes = Algorithm::Diff::sdiff( \@list1, \@list2 );

    # Try to combine adjacent changes, to avoid unnecessary spaces

    my $i = 0;
    while ( $i < $#changes ) {
        if ( $changes[$i]->[0] ne $changes[ $i + 1 ]->[0] ) {
            $i++;
            next;
        }

        $changes[$i]->[1] .= ' ' if $changes[$i]->[1];
        $changes[$i]->[1] .= $changes[ $i + 1 ]->[1];
        $changes[$i]->[2] .= ' ' if $changes[$i]->[2];
        $changes[$i]->[2] .= $changes[ $i + 1 ]->[2];

        splice @changes, $i + 1, 1;
    }

    # Format the text changes

    my ( $ctext1, $ctext2 );

    foreach my $action (@changes) {
        if ( $action->[0] eq '+' ) {
            ( $interweave ? $ctext1 : $ctext2 ) .=
              '<span class="' . $class_add . '">' . $action->[2] . '</span> ';
        }
        elsif ( $action->[0] eq '-' ) {
            $ctext1 .=
              '<span class="' . $class_del . '">' . $action->[1] . '</span> ';
        }
        elsif ( $action->[0] eq 'c' ) {
            $ctext1 .=
              '<span class="' . $class_c1 . '">' . $action->[1] . '</span> ';
            ( $interweave ? $ctext1 : $ctext2 ) .=
              '<span class="' . $class_c2 . '">' . $action->[2] . '</span> ';
        }
        else {
            $ctext1 .= $action->[1] . ' ';
            $ctext2 .= $action->[2] . ' ' unless $interweave;
        }
    }

    return ( $ctext1 || '', $ctext2 || '' );
}

sub _getTextWithClass {

    # Purpose: Format text with a class

    my ( $element, $class ) = @_;

    if ( ref($element) eq $HTMLElement ) {
        _addClass( $element, $class ) if $class;
        return $element->as_HTML( undef, undef, {} );
    }
    elsif ($class) {
        return '<span class="' . $class . '">' . $element . '</span>';
    }
    else {
        return $element;
    }
}

sub _getTextFromAction {

    # Purpose:

    my $action = shift;

    my ( $text1, $text2 );

    if ( $action->[0] eq 'u' ) {
        $text1 = _getTextWithClass( $action->[1], undef );
        $text2 = _getTextWithClass( $action->[2], undef ) unless $interweave;
    }
    elsif ( $action->[0] eq '+' ) {
        ( $interweave ? $text1 : $text2 ) =
          _getTextWithClass( $action->[2], $class_add );
    }
    elsif ( $action->[0] eq '-' ) {
        $text1 = _getTextWithClass( $action->[1], $class_del );
    }
    else {
        $text1 = _getTextWithClass( $action->[1], $class_c1 );
        $text2 = _getTextWithClass( $action->[2], $class_c2 );
        if ($interweave) {
            $text1 = $text1 . $text2;
            $text2 = '';
        }
    }

    return ( $text1 || '', $text2 || '' );
}

sub getRevInfo {
    my ( $web, $rev, $topic, $short ) = @_;

    my ( $date, $user ) = Foswiki::Func::getRevisionInfo( $web, $topic, $rev );
    my $mainweb = Foswiki::Func::getMainWebname();
    $user = "$mainweb.$user";

#    $user = Foswiki::Render::getRenderedVersion( Foswiki::userToWikiName( $user ) );
    $date = Foswiki::Func::formatTime($date);

    my $revInfo = "$date - $user";
    $revInfo =~ s/[\n\r]*//go;
    return $revInfo;
}

# =========================

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
