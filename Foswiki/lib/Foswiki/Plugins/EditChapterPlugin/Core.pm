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

package Foswiki::Plugins::EditChapterPlugin::Core;

use Foswiki::Func ();
use Foswiki::Plugins ();
use strict;
use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- EditChapterPlugin - $_[0]\n" if DEBUG;
}

###############################################################################
sub new {
  my $class = shift;
  my $web = shift;
  my $topic = shift;

  my $minDepth = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_MINDEPTH") || 1;
  my $maxDepth = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_MAXDEPTH") || 6;
  my $editImg = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_EDITIMG") || 
    '<img src="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/pencil.png" height="16" width="16" border="0" />';
  my $editLabelFormat = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_EDITLABELFORMAT") || 
    '<span class="ecpHeading">$anchor $heading <a class="ecpEdit" href="$url" title="Edit this chapter">$img</a></span>';
  my $wikiName = Foswiki::Func::getWikiName();

  my $this = {
    minDepth => $minDepth,
    maxDepth => $maxDepth,
    editLabelFormat => $editLabelFormat,
    editImg => $editImg,
    baseWeb => $web,
    baseTopic => $topic,
    translationToken => "\1",
    wikiName => $wikiName,
    @_,
  };

  my $enabled = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_ENABLED") || 'on';

  $enabled = ($enabled eq 'on')?1:0;
  $this->{enabled}{$web.'.'.$topic} = $enabled;

  $this = bless($this, $class);

  return $this;
}

###############################################################################
sub handleEnableEditChapter {
  my ($this, $web, $topic, $flag) = @_;

  $this->{enabled}{$web.'.'.$topic} = ($flag eq 'EN')?1:0;

  #writeDebug("called handleEnableEditChapter($web, $topic, $flag)");

  return '';
}

###############################################################################
sub commonTagsHandler {
  my $this = shift;
  ### my ( $text, $topic, $web, $include, $meta ) = @_;

  my $text = $_[0];
  my $topic = $_[1];
  my $web = $_[2];

  return unless $topic;

  my $insideInclude = $_[3] || Foswiki::Func::getContext()->{insideInclude} || 0;
  my $key = $web.'.'.$topic;

  #writeDebug("called commonTagsHandler($web, $topic)");

  my $blocks = {};
  my $renderer = $Foswiki::Plugins::SESSION->renderer;
  $text = takeOutBlocks($text, 'verbatim', $blocks);
  $text = takeOutBlocks( $text, 'pre', $blocks);

  $text =~ s/%(EN|DIS)ABLEEDITCHAPTER%/
    $this->handleEnableEditChapter($web, $topic, $1)
  /ge;

  # disable edit if we have no access
  my $access = 
    Foswiki::Func::checkAccessPermission('edit', $this->{wikiName}, undef, $topic, $web, undef);
  $this->{enabled}{$key} = 0 unless $access;

  my $enabled = $this->{enabled}{$key};
  $enabled = 1 unless defined $enabled;

  # prohibit edit on self-includes
  $enabled = 0 if $insideInclude && 
    $this->{baseWeb} eq $web && $this->{baseTopic} eq $topic;

  #writeDebug("enabled=$enabled");


  # loop over all lines
  my $chapterNumber = 0;
  $text =~ s/(^)(---+[\+#]{$this->{minDepth},$this->{maxDepth}}[0-9]*(?:!!)?)([^$this->{translationToken}\+#!].+?)($)/
    $1.
    $this->handleSection($web, $topic, \$chapterNumber, $3, $2, $4, $enabled)
  /gme;

  putBackBlocks( \$text, $blocks, 'pre' );
  putBackBlocks( \$text, $blocks, 'verbatim' );

  $_[0] = $text;
}

###############################################################################
sub handleSection {
  my ($this, $web, $topic, $chapterNumber, $heading, $before, $after, $enabled) = @_;

  #writeDebug("called handleSection($web, $topic, '$heading')");

  my $result;

  unless ($enabled) {
    $result = $heading;
  } else {

    $$chapterNumber++;

    #writeDebug("chapterNumber=$$chapterNumber");

    my $from = $$chapterNumber;
    my $to = $$chapterNumber;

    #$from = 0 if $from == 1; # include chapter 0 in chapter 1

    my %args = (
      from=>$from,
      to=>$to,
      t=>time(),
      cover=>'chapter',
      nowysiwyg=>'on',
    );

    my $anchor = lc($web.'_'.$topic);
    $anchor =~ s/\//_/go;
    $anchor = 'chapter_'.$anchor.'_'.$$chapterNumber;

    my $query = Foswiki::Func::getCgiQuery();
    my $queryString = $query->query_string();
    $queryString = $queryString?"?$queryString":"";

    $args{redirectto} = 
      Foswiki::Func::getScriptUrl($this->{baseWeb}, $this->{baseTopic}, 'view').
      $queryString.
      "#$anchor";

    my $url = Foswiki::Func::getScriptUrl($web, $topic, 'edit', %args);

    $anchor = '<a name="'.$anchor.'"></a>';

    # format
    $result = $this->{editLabelFormat};
    $result =~ s/\$anchor/$anchor/g;
    $result =~ s/\$url/$url/g;
    $result =~ s/\$web/$web/g;
    $result =~ s/\$topic/$topic/g;
    $result =~ s/\$baseweb/$this->{baseWeb}/g;
    $result =~ s/\$basetopic/$this->{baseTopic}/g;
    $result =~ s/\$heading/$heading/g;
    $result =~ s/\$index/$$chapterNumber/g;
    $result =~ s/\$img/$this->{editImg}/g;
  }

  $result = $before.$this->{translationToken}.$result.$after;
  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleEXTRACTCHAPTER {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleEXTRACTCHAPTER()");

  my $theFrom = $params->{from} || 0;
  my $theTo = $params->{to} || 9999999;
  my $theNumber = $params->{nr};
  my $theBefore = $params->{before};
  my $theAfter = $params->{after};
  my $theEncode = $params->{encode} || 'off';

  $theEncode = ($theEncode eq 'on')?1:0;

  $theFrom =~ s/[^\d]//go;
  $theTo =~ s/[^\d]//go;

  if (defined($theNumber)) {
    $theNumber =~ s/[^\d]//go;
    $theFrom = $theNumber;
    $theTo = $theNumber;
  }
  if (defined($theBefore)) {
    $theBefore =~ s/[^\d]//go;
    $theBefore ||= 0;
    $theTo = $theBefore - 1;
  }
  if (defined($theAfter)) {
    $theAfter =~ s/[^\d]//go;
    $theAfter ||= 0;
    $theFrom = $theAfter + 1;
  }

  return '' if $theTo < 0;

  my $thisWeb = $params->{web} || $this->{baseWeb};
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $this->{baseTopic};

  ($thisWeb, $thisTopic) = 
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  #writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic, theFrom=$theFrom, theTo=$theTo");

  my ($meta, $text) = Foswiki::Func::readTopic($thisWeb, $thisTopic);

  # check access permissions
  my $access = 
    Foswiki::Func::checkAccessPermission('view', $this->{wikiName}, $text, $thisTopic, $thisWeb, $meta);
  return '' unless $access;

  #writeDebug("BEGIN TEXT\n$text\nEND TEXT");

  # translate chapter span to text positions
  my $chapterNumber = 0;
  my $fromPos;
  my $toPos;
  my $insidePre = 0;
  $fromPos = 0 if $theFrom == 0;
  while ($text =~ /(^.*$)/gm) {
    my $line = $1;
    #writeDebug("line='$line'");

    $insidePre++ if $line =~ /<(pre|verbatim)[^>]*>/goi;
    $insidePre-- if $line =~ /<\/(pre|verbatim)>/goi;
    next if $insidePre > 0;

    if ($line =~ /^---+[\+#]{$this->{minDepth},$this->{maxDepth}}(?:!!)?\s*(.+?)$/m) {
      $chapterNumber++;
      if ($chapterNumber == $theFrom) {
        $fromPos = pos($text) - length($line);
        #writeDebug("found start at $fromPos");
        next;
      }
      if ($chapterNumber > $theTo) {
        last unless defined $fromPos;
        $toPos = pos($text) - length($line);
        #writeDebug("found end at $toPos");
        last;
      }
    }
  }
  return '' unless defined $fromPos;

  $toPos = length($text) unless defined $toPos;
  my $length = $toPos - $fromPos;

  #writeDebug("fromPos=$fromPos, toPos=$toPos, length=$length");
  return '' unless $length;

  my $result = substr($text, $fromPos, $length);

  $result = entityEncode( $result, "\n" ) if $theEncode;
  writeDebug("BEGIN RESULT\n$result\nEND RESULT");
  return $result;
}

###############################################################################
sub entityEncode {
  my ( $text, $extra ) = @_;
  $extra ||= '';

  $text =~
    s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;

  return $text;
}

###############################################################################
# compatibility wrapper 
sub takeOutBlocks {
  return Foswiki::takeOutBlocks(@_) if defined &Foswiki::takeOutBlocks;
  return $Foswiki::Plugins::SESSION->{renderer}->takeOutBlocks(@_);
}

###############################################################################
# compatibility wrapper 
sub putBackBlocks {
  return Foswiki::putBackBlocks(@_) if defined &Foswiki::putBackBlocks;
  return $Foswiki::Plugins::SESSION->{renderer}->putBackBlocks(@_);
}

1;
