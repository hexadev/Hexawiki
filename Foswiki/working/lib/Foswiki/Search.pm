# See bottom of file for license and copyright information
package Foswiki::Search;

=begin TML

---+ package Foswiki::Search

This module implements all the search functionality.

=cut

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                           ();
use Foswiki::Sandbox                  ();
use Foswiki::Search::InfoCache        ();
use Foswiki::Search::ResultSet        ();
use Foswiki::ListIterator             ();
use Foswiki::Iterator::FilterIterator ();
use Foswiki::WebFilter                ();
use Foswiki::MetaCache                ();

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching -
    # main locale settings are done in Foswiki::setupLocale
    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new ($session)

Constructor for the singleton Search engine object.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

 Note to developers; please undef *all* fields in the object explicitly,
 whether they are references or not. That way this method is "golden
 documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;
    undef $this->{session};

# these may well be function objects, but if (a setting changes, it needs to be picked up again.
    if ( defined( $this->{queryParser} ) ) {
        $this->{queryParser}->finish();
        undef $this->{queryParser};
    }
    if ( defined( $this->{searchParser} ) ) {
        $this->{searchParser}->finish();
        undef $this->{searchParser};
    }
    if ( defined( $this->{MetaCache} ) ) {
        $this->{MetaCache}->finish();
        undef $this->{MetaCache};
    }
}

=begin TML

---++ ObjectMethod metacache
returns the metacache.

=cut

sub metacache {
    my $this = shift;

# these may well be function objects, but if (a setting changes, it needs to be picked up again.
    if ( !defined( $this->{MetaCache} ) ) {
        $this->{MetaCache} = new Foswiki::MetaCache( $this->{session} );
    }
    return $this->{MetaCache};
}

=begin TML

---++ ObjectMethod parseSearch($searchString, $params) -> Foswiki::*::Node 

parses the search string and builds the appropriate nodes (uses $param->{type} to work out which parser 

TODO: make parser register themselves with their type, so that we could plug in anything.

=cut

sub parseSearch {
    my $this         = shift;
    my $searchString = shift;
    my $params       = shift;

    my $query;
    my $theParser;
    if ( $params->{type} eq 'query' ) {
        unless ( defined( $this->{queryParser} ) ) {
            require Foswiki::Query::Parser;
            $this->{queryParser} = new Foswiki::Query::Parser();
        }
        $theParser = $this->{queryParser};
    }
    else {
        unless ( defined( $this->{searchParser} ) ) {
            require Foswiki::Search::Parser;
            $this->{searchParser} =
              new Foswiki::Search::Parser( $this->{session} );
        }
        $theParser = $this->{searchParser};
    }
    try {
        $query = $theParser->parse( $searchString, $params );
    }
    catch Foswiki::Infix::Error with {

        # Pass the error on to the caller
        throw Error::Simple( shift->stringify() );
    };
    return $query;
}

sub _extractPattern {
    my ( $text, $pattern ) = @_;

    # Pattern comes from topic, therefore tainted
    $pattern =
      Foswiki::Sandbox::untaint( $pattern, \&Foswiki::validatePattern );

    my $ok = 0;
    eval {

        # The eval acts as a try block in case there is anything evil in
        # the pattern.
        $ok = 1 if ( $text =~ s/$pattern/$1/is );
    };
    $text = '' unless $ok;

    return $text;
}

# With the same argument as $pattern, returns a number which is the count of
# occurences of the pattern argument.
sub _countPattern {
    my ( $text, $pattern ) = @_;

    $pattern =
      Foswiki::Sandbox::untaint( $pattern, \&Foswiki::validatePattern );

    my $count;
    try {

        # see: perldoc -q count
        $count = () = $text =~ /$pattern/g;
    }
    catch Error::Simple with {
        $count = 0;
    };

    return $count;
}

=begin TML

---++ StaticMethod _isSetTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is _actually set to_ true, and 0 otherwise. 

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub _isSetTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/on//gi;
    $value =~ s/yes//gi;
    $value =~ s/true//gi;
    return ($value) ? 0 : 1;
}

=begin TML

---++ ObjectMethod searchWeb (...)

Search one or more webs according to the parameters.

If =_callback= is set, that means the caller wants results as
soon as they are ready. =_callback_ should be set to a reference
to a function which takes =_cbdata= as the first parameter and
remaining parameters the same as 'print'.

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

The function will throw Error::Simple if it encounters any problems with the
syntax of the search string.

Note: If =format= is set, =template= will be ignored.

Note: For legacy, if =regex= is defined, it will force type='regex'

If =type="word"= it will be changed to =type="keyword"= with =wordboundaries=1=. This will be used for searching with scope="text" only, because scope="topic" will do a Perl search on topic names.

SMELL: If =template= is defined =bookview= will not work

SMELL: it seems that if you define =_callback= then you are
	responsible for converting the TML to HTML yourself!

FIXME: =callback= cannot work with format parameter (consider format='| $topic |'

=cut

sub searchWeb {
    my $this    = shift;
    my $session = $this->{session};
    ASSERT( defined $session->{webName} ) if DEBUG;
    my %params = @_;

    my $baseWebObject = Foswiki::Meta->new( $session, $session->{webName} );

    my ( $callback, $cbdata ) = setup_callback( \%params, $baseWebObject );

    my $baseTopic = $params{basetopic} || $session->{topicName};
    my $baseWeb   = $params{baseweb}   || $session->{webName};
    $params{casesensitive} = Foswiki::isTrue( $params{casesensitive} );
    $params{excludeTopics} = $params{excludetopic} || '';
    my $formatDefined = $params{formatdefined} = defined $params{format};
    my $format = $params{format};

    $params{multiple} = Foswiki::isTrue( $params{multiple} );
    $params{nonoise}  = Foswiki::isTrue( $params{nonoise} );
    $params{noempty}  = Foswiki::isTrue( $params{noempty}, $params{nonoise} );
###    $params{zeroresults} = Foswiki::isTrue( ( $params{zeroresults} ), $params{nonoise} );

#paging - this code should be hidden in the InfoCache iterator, but atm, that won't let me do multi-web
#TODO: or... I may wrap an AggregateIterator in a PagingIterator which then is evaluated by a Formattingiterator.
    my $pagesize =
         $params{pagesize}
      || $Foswiki::cfg{Search}{DefaultPageSize}
      || 25;

    require Digest::MD5;
    my $string_id = $params{_RAW} || 'we had better not go there';
    my $paging_ID = 'SEARCH' . Digest::MD5::md5_hex($string_id);
    $params{pager_urlparam_id} = $paging_ID;

    # 1-based system; 0 is not a valid page number
    my $showpage = $session->{request}->param($paging_ID) || $params{showpage};

    if ( defined( $params{pagesize} ) or defined($showpage) ) {
        if ( !defined($showpage) ) {
            $showpage = 1;
        }
        $params{pager_skip_results_from} = $pagesize * ( $showpage - 1 );
        $params{pager_show_results_to} = $pagesize;
    }

    #TODO: refactorme
    my $header  = $params{header};
    my $footer  = $params{footer};
    my $noTotal = Foswiki::isTrue( $params{nototal}, $params{nonoise} );

    my $noEmpty = Foswiki::isTrue( $params{noempty}, $params{nonoise} );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    my $noHeader =
      !defined($header)
      && Foswiki::isTrue( $params{noheader}, $params{nonoise} )
      || ( !$header && $formatDefined );

    my $noFooter =
      !defined($footer)
      && Foswiki::isTrue( $params{nofooter}, $params{nonoise} )
      || ( !$footer && $formatDefined );

    my $noSummary = Foswiki::isTrue( $params{nosummary}, $params{nonoise} );
    my $zeroResults =
      Foswiki::isTrue( $params{zeroresults}, $params{nonoise} || 1 );

    #END TODO

    my $doBookView = Foswiki::isTrue( $params{bookview} );

    my $revSort = Foswiki::isTrue( $params{reverse} );
    $params{scope} = $params{scope} || '';
    my $searchString = defined $params{search} ? $params{search} : '';

    $params{includeTopics} = $params{topic} || '';
    $params{type}          = $params{type}  || '';

    $params{wordboundaries} = 0;
    if ( $params{type} eq 'word' ) {

        # 'word' is exactly the same as 'keyword', except we will be searching
        # with word boundaries
        $params{type}           = 'keyword';
        $params{wordboundaries} = 1;
    }

    my $webNames = $params{web}       || '';
    my $date     = $params{date}      || '';
    my $recurse  = $params{'recurse'} || '';

    $baseWeb =~ s/\./\//go;

    $params{type} = 'regex' if ( $params{regex} );

#TODO: quick hackjob - see what the feature proposal gives before it becomes public
    if ( defined( $params{groupby} ) and ( $params{groupby} eq 'none' ) ) {

        #_only_ allow groupby="none" - as its a secrect none public setting.
    }
    else {
        $params{groupby} = 'web';
    }

################### Perform The Search
    my $query = $this->parseSearch( $searchString, \%params );

#setting the inputTopicSet to be undef allows the search/query algo to use
#the topic="" and excludetopic="" params and web Obj to get a new list of topics.
#this allows the algo's to customise and optimise the getting of this list themselves.
    my $infoCache = Foswiki::Meta::query( $query, undef, \%params );

################### Do the Rendering

    # If the search did not return anything, return the rendered zeroresults
    # if it is defined as a string.
    # (http://foswiki.org/Development/AddDefaultTopicParameterToINCLUDE)
    if ( not $infoCache->hasNext() ) {
        if ( not $zeroResults ) {
            return '';
        }
        else {
            if ( not _isSetTrue( $params{zeroresults}, 1 ) ) {

#foswiki 1.1 Feature Proposal: SEARCH needs an alt parameter in case of zero results


          #TODO: extract & merge with extraction of footer processing code below
                my $result = $params{zeroresults};

                $result =~ s/\$web/$baseWeb/gos;    # expand name of web
                $result =~ s/([^\n])$/$1\n/os;      # add new line at end

                # output footer of $web
                $result =~ s/\$ntopics/0/gs;
                $result =~ s/\$nhits/0/gs;
                $result =~ s/\$index/0/gs;

                #legacy SEARCH counter support
                $result =~ s/%NTOPICS%/0/go;

                $result = Foswiki::expandStandardEscapes($result);
                $result =~ s/\n$//os;               # remove trailing new line
                

                return $result;
            }
        }
    }

    my $tmplSearch =
      $this->loadTemplates( \%params, $baseWebObject, $formatDefined,
        $doBookView, $noHeader, $noSummary, $noTotal, $noFooter );

    # Generate 'Search:' part showing actual search string used
    # Ommit any text before search results if either nosearch or nonoise is on
    my $nonoise = Foswiki::isTrue( $params{nonoise} );
    my $noSearch = Foswiki::isTrue( $params{nosearch}, $nonoise );
    unless ($noSearch) {
        my $searchStr = $searchString;
        $searchStr =~ s/&/&amp;/go;
        $searchStr =~ s/</&lt;/go;
        $searchStr =~ s/>/&gt;/go;

        $tmplSearch =~ s/%SEARCHSTRING%/$searchStr/go;
        &$callback( $cbdata, $tmplSearch );
    }

    # We now format the results.
    # All the
    my ( $numberOfResults, $web_searchResult ) =
      $this->formatResults( $query, $infoCache, \%params );

    return if ( defined $params{_callback} );

    my $searchResult = join( '', @{ $params{_cbdata} } );

    $searchResult = Foswiki::expandStandardEscapes($searchResult);

    # Remove trailing separator or new line if nofinalnewline parameter is set
    my $noFinalNewline = Foswiki::isTrue( $params{nofinalnewline}, 1 );
    if ( $formatDefined && $noFinalNewline ) {
        if ( $params{separator} ) {
            my $separator = quotemeta( $params{separator} );
            $searchResult =~ s/$separator$//s;    # remove separator at end
        }
        else {
            $searchResult =~ s/\n$//os;           # remove trailing new line
        }
    }

    return $searchResult;
}

=begin TML

---++ ObjectMethod loadTemplates (...)

this code was extracted from searchWeb, and should probably be private.

=cut

sub loadTemplates {
    my (
        $this,          $params,     $baseWebObject,
        $formatDefined, $doBookView, $noHeader,
        $noSummary,     $noTotal,    $noFooter
    ) = @_;

    my $session = $this->{session};

    #tmpl loading code.
    my $tmpl = '';

    my $template = $params->{template} || '';
    if ($formatDefined) {
        $template = 'searchformat';
    }
    elsif ($template) {

        # template definition overrides book and rename views
    }
    elsif ($doBookView) {
        $template = 'searchbookview';
    }
    else {
        $template = 'search';
    }
    $tmpl = $session->templates->readTemplate($template);

#print STDERR "}}} $tmpl {{{\n";
# SMELL: the only META tags in a template will be METASEARCH
# Why the heck are they being filtered????
#TODO: write a unit test that uses topic based templates with META's in them and if ok, remove.
    $tmpl =~ s/\%META{.*?}\%//go;    # remove %META{'parent'}%

    # Split template into 5 sections
    my ( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) =
      split( /%SPLIT%/, $tmpl );

    my $repeatText;

    if ( !defined($tmplTail) ) {
        $tmplSearch = $session->templates->expandTemplate('SEARCH:searched');
        $tmplNumber = $session->templates->expandTemplate('SEARCH:count');

#it'd be nice to not need this if, but it seem that the noheader setting is ignored if a header= is set. truely bizzare
#TODO: push up the 'noheader' evaluation to take not of this quirk
#TODO: um, we die when ASSERT is on with a wide char in print
        unless ($noHeader) {
            $params->{header} =
              $session->templates->expandTemplate('SEARCH:header')
              unless defined $params->{header};
        }

        $repeatText = $session->templates->expandTemplate('SEARCH:format');

        unless ($noFooter) {
            $params->{footer} =
              $session->templates->expandTemplate('SEARCH:footer')
              unless defined $params->{footer};
        }
    }
    else {

        #Historical legacy form of the search TMPL's
        # header and footer of $web
        my $beforeText;
        my $afterText;
        ( $beforeText, $repeatText, $afterText ) =
          split( /%REPEAT%/, $tmplTable );

        unless ($noHeader) {
            $params->{header} = $beforeText unless defined $params->{header};
        }

        unless ($noFooter) {
            $params->{footer} ||= $afterText;
        }
    }

    #nosummary="on" nosearch="on" noheader="on" nototal="on"
    if ($noSummary) {
        $repeatText =~ s/%TEXTHEAD%//go;
        $repeatText =~ s/&nbsp;//go;
    }
    else {
        $repeatText =~ s/%TEXTHEAD%/\$summary(searchcontext)/go;
    }
    $params->{format} ||= $repeatText;

    $params->{footercounter} ||= $tmplNumber;

    return $tmplSearch;
}

=begin TML
---++ formatResults

the implementation of %FORMAT{}%

TODO: rewrite to take a resultset, a set of params? and a hash of sub's to
enable evaluations of things like '$include(blah)' in format strings.

have a default set of replacements like $lt, $nop, $percnt, $dollar etc, and then
the hash of subs can take care of %MACRO{}% specific complex to evaluate replacements..

(that way we don't pre-evaluate and then subst)

=cut

sub formatResults {
    my ( $this, $query, $infoCache, $params ) = @_;
    my $session = $this->{session};
    my $users   = $session->{users};

    my ( $callback, $cbdata ) = setup_callback($params);

    my $baseTopic = $params->{basetopic} || $session->{topicName};
    my $baseWeb   = $params->{baseweb}   || $session->{webName};
    my $doBookView    = Foswiki::isTrue( $params->{bookview} );
    my $caseSensitive = Foswiki::isTrue( $params->{casesensitive} );
    my $doExpandVars  = Foswiki::isTrue( $params->{expandvariables} );
    my $nonoise       = Foswiki::isTrue( $params->{nonoise} );
    my $noSearch      = Foswiki::isTrue( $params->{nosearch}, $nonoise );
    my $formatDefined = defined $params->{format};
    my $format        = $params->{format} || '';
    my $header        = $params->{header} || '';
    my $footer        = $params->{footer} || '';
    my $limit         = $params->{limit} || '';

    # Limit search results. Cannot be deprecated
    # Limit will still be needed for the application types of SEARCHES
    # even if pagesize is added as feature. Example for searching and listing
    # text from first 5 bullets in a formatted multiple type search
    if ( $limit =~ /(^\d+$)/o ) {

        # only digits, all else is the same as
        # an empty string.  "+10" won't work.
        $limit = $1;
    }
    else {

        # change 'all' to 0, then to big number
        $limit = 0;
    }
    $limit = 32000 unless ($limit);

    #pager formatting
    my %pager_formatting;
    if ( defined( $params->{pager_show_results_to} )
        and $params->{pager_show_results_to} > 0 )
    {
        $limit = $params->{pager_show_results_to};

#paging - this code should be hidden in the InfoCache iterator, but atm, that won't let me do multi-web
        my $pagesize =
             $params->{pagesize}
          || $Foswiki::cfg{Search}{DefaultPageSize}
          || 25;

        #TODO: paging only implemented for SEARCH atm :/
        my $paging_ID = $params->{pager_urlparam_id};

        # 1-based system; 0 is not a valid page number
        my $showpage =
             $session->{request}->param($paging_ID)
          || $params->{showpage}
          || 1;

        #TODO: need to ask the result set
        my $numberofpages = $infoCache->numberOfTopics / $params->{pagesize};
        $numberofpages = int($numberofpages) + 1;

        #TODO: excuse me?
        my $sep = ' ';

        my $nextidx     = $showpage + 1;
        my $previousidx = $showpage - 1;

        my %new_params;

        #kill me please, i can't find a way to just load up the hash :(
        foreach my $key ( $session->{request}->param ) {
            $new_params{$key} = $session->{request}->param($key);
        }

        $session->templates->readTemplate('searchformat');

        my $previouspagebutton = '';
        my $previouspageurl    = '';
        if ( $previousidx >= 1 ) {
            $new_params{$paging_ID} = $previousidx;
            $previouspageurl =
              Foswiki::Func::getScriptUrl( $baseWeb, $baseTopic, 'view',
                %new_params );
            $previouspagebutton =
              $session->templates->expandTemplate('SEARCH:pager_previous');
        }
        my $nextpagebutton = '';
        my $nextpageurl    = '';
        if ( $nextidx <= $numberofpages ) {
            $new_params{$paging_ID} = $nextidx;
            $nextpageurl =
              Foswiki::Func::getScriptUrl( $baseWeb, $baseTopic, 'view',
                %new_params );
            $nextpagebutton =
              $session->templates->expandTemplate('SEARCH:pager_next');
        }
        %pager_formatting = (
            '\$previouspage'  => sub { return $previousidx },
            '\$currentpage'   => sub { return $showpage },
            '\$nextpage'      => sub { return $showpage + 1 },
            '\$numberofpages' => sub { return $numberofpages },
            '\$pagesize'      => sub { return $pagesize },
            '\$previousurl'   => sub { return $previouspageurl },
            '\$nexturl'       => sub { return $nextpageurl },
            '\$sep'           => sub { return $sep; }
        );

        $previouspagebutton =
          $this->formatCommon( $previouspagebutton, \%pager_formatting );
        $pager_formatting{'\$previousbutton'} =
          sub { return $previouspagebutton };

        $nextpagebutton =
          $this->formatCommon( $nextpagebutton, \%pager_formatting );
        $pager_formatting{'\$nextbutton'} = sub { return $nextpagebutton };

        my $pager_control = $params->{pagerformat}
          || $session->templates->expandTemplate('SEARCH:pager');
        $pager_control =
          $this->formatCommon( $pager_control, \%pager_formatting );
        $pager_formatting{'\$pager'} = sub { return $pager_control; };
    }

    #TODO: multiple is an attribute of the ResultSet
    my $doMultiple = Foswiki::isTrue( $params->{multiple} );
    my $noEmpty = Foswiki::isTrue( $params->{noempty}, $nonoise );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    my $noHeader =
      !defined($header) && Foswiki::isTrue( $params->{noheader}, $nonoise )
      || ( !$header && $formatDefined );

    my $noFooter =
      !defined($footer) && Foswiki::isTrue( $params->{nofooter}, $nonoise )
      || ( !$footer && $formatDefined );

    my $noSummary = Foswiki::isTrue( $params->{nosummary}, $nonoise );
    my $zeroResults =
      Foswiki::isTrue( ( $params->{zeroresults} ), $nonoise || 1 );
    my $noTotal = Foswiki::isTrue( $params->{nototal}, $nonoise );
    my $newLine   = $params->{newline} || '';
    my $separator = $params->{separator};
    my $type      = $params->{type} || '';

    # output the list of topics in $web
    my $ntopics    = 0;         # number of topics in current web
    my $nhits      = 0;         # number of hits (if multiple=on) in current web
    my $headerDone = $noHeader;

    my $web              = $baseWeb;
    my $webObject        = new Foswiki::Meta( $session, $web );
    my $lastWebProcessed = '';

    #total number of topics and hits - not reset when we swap webs
    my $ttopics = 0;
    my $thits   = 0;

    while ( $infoCache->hasNext() ) {
        my $listItem = $infoCache->next();
        ASSERT( defined($listItem) ) if DEBUG;

        #pager..
        if ( defined( $params->{pager_skip_results_from} )
            and $params->{pager_skip_results_from} > 0 )
        {
            $params->{pager_skip_results_from}--;
            next;
        }

        #############################################################
        #TOPIC specific
        my $topic = $listItem;
        my $text;    #undef means the formatResult() gets it from $info->text;
        my $info;
        my @multipleHitLines = ();
        if (
            ( $infoCache->isa('Foswiki::Search::ResultSet') ) or    #SEARCH
            ( $infoCache->isa('Foswiki::Search::InfoCache') )
          )                                                         #FORMAT
        {
            ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( '', $listItem );

# add dependencies (TODO: unclear if this should be before the paging, or after the allowView - sadly, it can't be _in_ the infoCache)
            if ( my $cache = $session->{cache} ) {
                $cache->addDependency( $web, $topic );
            }

            $info = $this->metacache->get( $web, $topic );

# Check security (don't show topics the current user does not have permission to view)
            next unless $info->{allowView};

            # Special handling for format='...'
            if ($formatDefined) {
                $text = $info->{tom}->text();
                $text = '' unless defined $text;

                if ($doExpandVars) {
                    if ( $web eq $baseWeb && $topic eq $baseTopic ) {

                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text = $info->{tom}->expandMacros($text);
                }
            }

            #TODO: should extract this somehow

            if ( $doMultiple && $query->{tokens} ) {

                #TODO: i wonder if this shoudl be a HoistRE..
                #TODO: well, um, and how does this work for query search?
                my @tokens = @{ $query->{tokens} };
                my $pattern = $tokens[$#tokens];   # last token in an AND search
                $pattern = quotemeta($pattern) if ( $type ne 'regex' );
                $text = $info->{tom}->text() unless defined $text;
                $text = '' unless defined $text;

                if ($caseSensitive) {
                    @multipleHitLines =
                      reverse grep { /$pattern/ } split( /[\n\r]+/, $text );
                }
                else {
                    @multipleHitLines =
                      reverse grep { /$pattern/i } split( /[\n\r]+/, $text );
                }
            }
        }

        $ntopics += 1;
        $ttopics += 1;
        do {    # multiple=on loop

            $nhits += 1;
            $thits += 1;

            $text = pop(@multipleHitLines) if ( scalar(@multipleHitLines) );

            my $justdidHeaderOrFooter = 0;
            if (    ( defined( $params->{groupby} ) )
                and ( $params->{groupby} eq 'web' ) )
            {
                if ( $lastWebProcessed ne $web ) {

                    #output the footer for the previous listItem
                    if ( $lastWebProcessed ne '' ) {

                        #c&p from below
                        #TODO: needs refactoring.
                        my $processedfooter = $footer;
                        if ( not $noTotal ) {
                            $processedfooter .= $params->{footercounter};
                        }
                        if ( defined($processedfooter)
                            and ( $processedfooter ne '' ) )
                        {

                            #footer comes before result
                            $ntopics--;
                            $nhits--;

#because $pager contains more $ntopics like format strings, it needs to be expanded first.
                            $processedfooter =
                              $this->formatCommon( $processedfooter,
                                \%pager_formatting );
                            $processedfooter =~ s/\$web/$lastWebProcessed/gos
                              ;    # expand name of web
#                            $processedfooter =~
#                              s/([^\n])$/$1\n/os;    # add new line at end
                                                     # output footer of $web

                            $processedfooter =~ s/\$ntopics/$ntopics/gs;
                            $processedfooter =~ s/\$nhits/$nhits/gs;
                            $processedfooter =~ s/\$index/$thits/gs;

                            #legacy SEARCH counter support
                            $processedfooter =~ s/%NTOPICS%/$ntopics/go;

                            $processedfooter =
                              $this->formatCommon( $processedfooter,
                                \%pager_formatting );
#                            $processedfooter =~
#                              s/\n$//os;    # remove trailing new line

                            $justdidHeaderOrFooter = 1;
                            &$callback( $cbdata, $processedfooter );

                            #go back to counting results
                            $ntopics++;
                            $nhits++;
                        }
                    }

                    #trigger a header for this new web
                    $headerDone = undef;
                }
            }

            if ( $lastWebProcessed ne $web ) {
                $webObject = new Foswiki::Meta( $session, $web );
                $lastWebProcessed = $web;

                #reset our web partitioned legacy counts
                $ntopics = 1;
                $nhits   = 1;
            }

            # lazy output of header (only if needed for the first time)
            if (    ( !$headerDone and ( defined($header) ) )
                and ( $header ne '' ) )
            {

                my $processedheader = $header;

                # because $pager contains more $ntopics like format
                # strings, it needs to be expanded first.
                $processedheader =
                  $this->formatCommon( $processedheader, \%pager_formatting );
                $processedheader =~ s/\$web/$web/gos;      # expand name of web
                
                # add new line after the header unless separator is defined
                # per Item1773 / SearchSeparatorDefaultHeaderFooter
                unless ( defined $separator ) {
                    $processedheader =~ s/([^\n])$/$1\n/os;
                }

                $headerDone = 1;
                my $thisWebBGColor = $webObject->getPreference('WEBBGCOLOR')
                  || '\#FF00FF';
                $processedheader =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                $processedheader =~ s/%WEB%/$web/go;
                $processedheader =~ s/\$ntopics/($ntopics-1)/gse;
                $processedheader =~ s/\$nhits/($nhits-1)/gse;
                $processedheader =~ s/\$index/($thits-1)/gs;
                $processedheader =
                  $this->formatCommon( $processedheader, \%pager_formatting );
                &$callback( $cbdata, $processedheader );
                $justdidHeaderOrFooter = 1;
            }

            if (    defined($separator)
                and ( $thits > 1 )
                and ( $justdidHeaderOrFooter != 1 ) )
            {
                &$callback( $cbdata, $separator );
            }

            ###################Render the result
            my $out;
            if ( $formatDefined and ( $format ne '' ) ) {

      #TODO: hack to convert a bad SEARCH format to the one used by getRevInfo..
                $format =~ s/\$createdate/\$createlongdate/gs;

       #it looks like $isodate in format is equive to $iso in renderRevisionInfo
       #TODO: clean these 3 hacks up
                $format =~ s/\$isodate/\$iso/gs;
                $format =~ s/\%TIME\%/\$date/gs;
                $format =~ s/\$date/\$longdate/gs;

                #other tmpl based renderings
                $format =~ s/%WEB%/\$web/go;
                $format =~ s/%TOPICNAME%/\$topic/go;
                $format =~ s/%AUTHOR%/\$wikiusername/g;

                # pass search options to summary parser
                my $searchOptions = {
                    type           => $params->{type},
                    wordboundaries => $params->{wordboundaries},
                    casesensitive  => $caseSensitive,
                    tokens         => $query->{tokens}
                };

#TODO: why is this not part of the callback? at least the non-result element format strings can be common here.
#or do i need a formatCommon sub that formatResult can also call.. (which then goes into the callback?
                $out = $this->formatResult(
                    $format,
                    $info->{tom} || $webObject,    #SMELL: horrid hack
                    $text,
                    $searchOptions,
                    {
                        '\$ntopics' => sub { return $ntopics },
                        '\$nhits'   => sub { return $nhits },
                        '\$index'   => sub { return $thits },
                        '\$item'    => sub { return $listItem },

                        %pager_formatting,

  #rev1 info
  #TODO: move the $create* formats into Render::renderRevisionInfo..
  #which implies moving the infocache's pre-extracted data into the tom obj too.
  #    $out =~ s/\$create(longdate|username|wikiname|wikiusername)/
  #      $infoCache->getRev1Info( $topic, "create$1" )/ges;
                        '\$createlongdate' => sub {
                            return $this->metacache->get( $web, $topic )->{tom}
                              ->getRev1Info("createlongdate");
                        },
                        '\$createusername' => sub {
                            return $this->metacache->get( $web, $topic )->{tom}
                              ->getRev1Info("createusername");
                        },
                        '\$createwikiname' => sub {
                            return $this->metacache->get( $web, $topic )->{tom}
                              ->getRev1Info("createwikiname");
                        },
                        '\$createwikiusername' => sub {
                            return $this->metacache->get( $web, $topic )->{tom}
                              ->getRev1Info("createwikiusername");
                        },

                   #TODO: hacky bits that need to be moved out of formatResult()
                        '$revNum' => sub { return ( $info->{revNum} || 0 ); },
                        '$doBookView' => sub { return $doBookView; },
                        '$baseWeb'    => sub { return $baseWeb; },
                        '$baseTopic'  => sub { return $baseTopic; },
                        '$newLine'    => sub { return $newLine; },
                        '$separator'  => sub { return $separator; },
                        '$noTotal'    => sub { return $noTotal; },
                        '$paramsHash' => sub { return $params; },
                    }
                );
            }
            else {
                $out = '';
            }

            &$callback( $cbdata, $out );
        } while (@multipleHitLines);    # multiple=on loop

        last if ( $ttopics >= $limit );
    }    # end topic loop

    # output footer only if hits in web
    if ( $ntopics == 0 ) {
        if ( $zeroResults and not $noTotal ) {
            $footer = $params->{footercounter};
        }
        else {
            $footer = '';
        }
        ##MOVEDUP $webObject = new Foswiki::Meta( $session, $baseWeb );
    }
    else {
        if ( ( not $noTotal ) and ( defined( $params->{footercounter} ) ) ) {
            $footer .= $params->{footercounter};
        }

        if ( ( defined( $params->{pager} ) ) and ( $params->{pager} eq 'on' ) )
        {
            $footer .= '$pager';
        }
    }
    if ( defined $footer ) {

#because $pager contains more $ntopics like format strings, it needs to be expanded first.
        $footer = $this->formatCommon( $footer, \%pager_formatting );
        $footer =~ s/\$web/$web/gos;      # expand name of web
#        $footer =~ s/([^\n])$/$1\n/os;    # add new line at end

        # output footer of $web
        $footer =~ s/\$ntopics/$ntopics/gs;
        $footer =~ s/\$nhits/$nhits/gs;
        $footer =~ s/\$index/$thits/gs;

        #legacy SEARCH counter support
        $footer =~ s/%NTOPICS%/$ntopics/go;

#        $footer =~ s/\n$//os;             # remove trailing new line

        &$callback( $cbdata, $footer );
    }

    return ( $ntopics,
        ( ( not defined( $params->{_callback} ) ) and ( $nhits >= 0 ) )
        ? join( '', @$cbdata )
        : '' );
}

sub formatCommon {
    my ( $this, $out, $customKeys ) = @_;

    my $session = $this->{session};

    foreach my $key ( keys(%$customKeys) ) {
        $out =~ s/$key/&{$customKeys->{$key}}()/ges;
    }
    return $out;
}

=begin TML

---++ ObjectMethod formatResult
   * $text can be undefined.
   * $searchOptions is an options hash to pass on to the summary parser
   * customKeys is a hash of {'$key' => sub {my $item = shift; return value;} }
     where $item is a tom object (initially a Foswiki::Meta, but I'd like to be more generic)
     
TODO: i don't really know what we'll need to do about order of processing.
TODO: at minimum, the keys need to be sorted by length so that $datatime is processed before $date
TODO: need to cater for $summary(params) style too

=cut

sub formatResult {
    my ( $this, $out, $topicObject, $text, $searchOptions, $customKeys ) = @_;

    my $session = $this->{session};

    my $web   = $topicObject->web();
    my $topic = $topicObject->topic();

    #TODO: these need to go away.
    my $revNum     = &{ $customKeys->{'$revNum'} }();
    my $doBookView = &{ $customKeys->{'$doBookView'} }();
    my $baseWeb    = &{ $customKeys->{'$baseWeb'} }();
    my $baseTopic  = &{ $customKeys->{'$baseTopic'} }();
    my $newLine    = &{ $customKeys->{'$newLine'} }();
    my $separator  = &{ $customKeys->{'$separator'} }();
    my $noTotal    = &{ $customKeys->{'$noTotal'} }();
    my $params     = &{ $customKeys->{'$paramsHash'} }();
    foreach my $key (
        '$revNum',  '$doBookView', '$baseWeb', '$baseTopic',
        '$newLine', '$separator',  '$noTotal', '$paramsHash'
      )
    {
        delete $customKeys->{$key};
    }

    foreach my $key ( keys(%$customKeys) ) {
        $out =~ s/$key/&{$customKeys->{$key}}()/ges;
    }

    #SMELL: hack to stop non-topic based FORMAT's from doing topic code
    #TODO: this should be extracted into the customKeys above
    $out = $session->renderer->renderRevisionInfo( $topicObject, $revNum, $out )
      if ( defined($topic) );

    if ( $out =~ m/\$text/ and defined($topic) )
    {    #TODO: don't muck with text if we're not even a topic
        $text = $topicObject->text() unless defined $text;
        $text = '' unless defined $text;

        if ( $topic eq $session->{topicName} ) {

#TODO: extract the diffusion and generalise to whatever MACRO we are processing - anything with a format can loop

            # defuse SEARCH in current topic to prevent loop
            $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
        }
        $out =~ s/\$text/$text/gos;
    }

    #TODO: extract the rev
    my $srev = 'r' . $revNum;
    if ( $revNum eq '0' || $revNum eq '1' ) {
        $srev = CGI::span( { class => 'foswikiNew' },
            ( $session->i18n->maketext('NEW') ) );
    }
    $out =~ s/%REVISION%/$srev/o;

    if ($doBookView) {

        # BookView
        $text = $topicObject->text() unless defined $text;
        $text = '' unless defined $text;

        if ( $web eq $baseWeb && $topic eq $baseTopic ) {

            # primitive way to prevent recursion
            $text =~ s/%SEARCH/%<nop>SEARCH/g;
        }
        $text = $topicObject->expandMacros($text);
        $text = $topicObject->renderTML($text);

        $out =~ s/%TEXTHEAD%/$text/go;

    }
    else {

        #TODO: more topic specific bits
        if ( defined($topic) ) {
            $out =~ s/\$summary(?:\(([^\)]*)\))?/
              $topicObject->summariseText( $1, $text, $searchOptions )/ges;
            $out =~ s/\$changes(?:\(([^\)]*)\))?/
              $topicObject->summariseChanges(Foswiki::Store::cleanUpRevID($1), $revNum)/ges;
            $out =~ s/\$formfield\(\s*([^\)]*)\s*\)/
              displayFormField( $topicObject, $1 )/ges;
            $out =~ s/\$parent\(([^\)]*)\)/
              Foswiki::Render::breakName(
                  $topicObject->getParent(), $1 )/ges;
            $out =~ s/\$parent/$topicObject->getParent()/ges;
            $out =~ s/\$formname/$topicObject->getFormName()/ges;
            $out =~ s/\$count\((.*?\s*\.\*)\)/_countPattern( $text, $1 )/ges;

   # FIXME: Allow all regex characters but escape them
   # Note: The RE requires a .* at the end of a pattern to avoid false positives
   # in pattern matching
            $out =~
              s/\$pattern\((.*?\s*\.\*)\)/_extractPattern( $text, $1 )/ges;
        }
        $out =~ s/\r?\n/$newLine/gos if ($newLine);


        # If separator is not defined we default to \n
        # We also add new line after last search result but before footer
        # when separator is not defined for backwards compatibility
        # per Item1773 / SearchSeparatorDefaultHeaderFooter
        if ( !defined($separator) ) {
            unless ( $noTotal && !$params->{formatdefined} ) {
                $out =~ s/([^\n])$/$1\n/s;
            }
        }
    }

#see http://foswiki.org/Tasks/Item2371 - needs unit test exploration
#the problem is that when I separated the formating from the searching, I set the format string to what is in the template,
#and thus here, format is always set.
#		elsif ($noSummary) {
#		    #TODO: i think that means I've broken SEARCH{nosummary=on" with no format specified
#		    $out =~ s/%TEXTHEAD%//go;
#		    $out =~ s/&nbsp;//go;
#		}
#		else {
#		    #SEARCH with no format and nonoise="off" or nosummary="off"
#		    #TODO: BROKEN, need to fix the meaning of nosummary and nonoise in SEARCH
#		    # regular search view
#		    $text = $info->{tom}->summariseText( '', $text );
#		    $out =~ s/%TEXTHEAD%/$text/go;
#		}
    return $out;
}

=begin TML

---++ StaticMethod displayFormField( $meta, $args ) -> $text

Parse the arguments to a $formfield specification and extract
the relevant formfield from the given meta data.

   * =args= string containing name of form field

In addition to the name of a field =args= can be appended with a commas
followed by a string format (\d+)([,\s*]\.\.\.)?). This supports the formatted
search function $formfield and is used to shorten the returned string or a
hyphenated string.

=cut

sub displayFormField {
    my ( $meta, $args ) = @_;

    my $name      = $args;
    my $breakArgs = '';
    my @params    = split( /\,\s*/, $args, 2 );
    if ( @params > 1 ) {
        $name      = $params[0] || '';
        $breakArgs = $params[1] || 1;
    }

    # SMELL: this is a *terrible* idea. Not only does it munge the result
    # so it can only be used for display, it also munges it such that it
    # can't be repaired by the options on %SEARCH.
    return $meta->renderFormFieldForDisplay( $name, '$value',
        { break => $breakArgs, protectdollar => 1, showhidden => 1 } );
}

#my ($callback, $cbdata) = setup_callback(\%params, $baseWebObject);
sub setup_callback {
    my ( $params, $webObj ) = @_;

    my $callback = $params->{_callback};
    my $cbdata   = $params->{_cbdata};

    #add in the rendering..
    if ( defined( $params->{_callback} ) ) {
        $callback = sub {
            my $cbdata      = shift;
            my $text        = shift;
            my $oldcallback = $params->{_callback};

            $text = $webObj->renderTML($text) if defined($webObj);
            $text =~ s|</*nop/*>||goi;    # remove <nop> tag
            &$oldcallback( $cbdata, $text );
        };
    }
    else {
        $cbdata = $params->{_cbdata} = [] unless ( defined($cbdata) );
        $callback = \&_collate_to_list;
    }
    return ( $callback, $cbdata );
}

# callback for search function to collate to list
sub _collate_to_list {
    my $ref = shift;

    push( @$ref, @_ );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. 
All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
