# ChartPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, Peter@Thoeny.org
# Plugin written by http://TWiki.org/cgi-bin/view/Main/TaitCyrus
# Copyright (C) 2008 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This file contains routines for producing PNG graphic files containing
# chart information, useful for building dashboards.
#    NOTE: ONLY in the case where an old version of GD (1.19 or earlier) is
#    available will GIF's be created.  If the GD version is > 1.19, then
#    PNG's are created.
#
# This plugin uses Perl object oriented programming.  The ChartPlugin
# object contains several other Perl objects:
#     Table
#     Parameters
#     Chart
# In addition to having it's own getter/setters.

# =========================
package Foswiki::Plugins::ChartPlugin;

use strict;

# =========================
use vars qw(
            $installWeb $VERSION $RELEASE $debug
            $pluginInitialized $initError
            $defaultType @defaultAreaColors @defaultLineColors
            $defaultWidth $defaultHeight $defaultBGcolor $defaultNumYGrids
            $defaultDataValue $defaultScale $defaultGridColor $defaultPointSize
            $defaultLineWidth
            $defaultBarLeadingSpace $defaultBarTrailingSpace $defaultBarSpace
           );

$VERSION = '$Rev: 6743 (2010-03-14) $';

$RELEASE = '13 Mar 2010';

$pluginInitialized = 0;
$initError = '';

# =========================
sub initPlugin {
    ( my $topic, my $web, my $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1 ) {
        &Foswiki::Func::writeWarning( "Version mismatch between ChartPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag( "CHARTPLUGIN_DEBUG" ) || 0;

    &Foswiki::Func::writeDebug( "- Foswiki::Plugins::ChartPlugin::initPlugin($web.$topic) is OK" ) if $debug;

    # Mark that we are not fully initialized yet.  Only get the default
    # values from the plugin topic page iff a CHART is found in a topic
    $pluginInitialized = 0;
    return 1;
}

# =========================

# Initialize all default values from the plugin topic page.
sub _init_defaults {
    return if $pluginInitialized;
    $pluginInitialized = 1;
    require Exporter;
    foreach my $module qw( GD POSIX
                           Foswiki::Plugins::ChartPlugin::Chart
                           Foswiki::Plugins::ChartPlugin::Parameters
                           Foswiki::Plugins::ChartPlugin::Table) {
        eval "require $module";
        if ($@) {
            $initError = "Required Perl module '$module' not found: $@";
            return;
        }
    }

    # Get default chart type
    $defaultType = Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_TYPE" ) || 'line';
    # Get default chart values
    $defaultWidth = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_WIDTH" ) || 60;
    $defaultHeight = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_HEIGHT" ) || 16;
    my $defaultAreaColors = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_AREA_COLORS" )
      || "#FF0000 #FFFF00 #00FF00";
    @defaultAreaColors = split(/[\s,]+/, $defaultAreaColors);
    my $defaultLineColors = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_LINE_COLORS" )
      || "#FFFF00 #FF00FF #00FFFF";
    @defaultLineColors = split(/[\s,]+/, $defaultLineColors);
    # Get default chart bgcolor
    $defaultBGcolor = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_BGCOLOR" ) || '#FFFFFF #FFFFFF';
    # Get default number of Y axis grids
    $defaultNumYGrids = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_NUMYGRIDS" ) || 10;
    # Get default value to use if there is no data seen in the table
    $defaultDataValue = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_DEFAULTDATA" );
    # Get default value for the scale (linear/semilog)
    $defaultScale = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_SCALE" );
    # Get default grid color.
    $defaultGridColor = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_GRIDCOLOR" ) || '#000000';
    # Get default value for the size, in pixels, of drawn data points
    $defaultPointSize = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_POINTSIZE" ) || 2;
    # Get default value for the width, in pixels, of drawn lines
    $defaultLineWidth = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_LINEWIDTH" ) || 3;
    # Get default value for the leading space before the first bar.
    $defaultBarLeadingSpace = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_BARLEADINGSPACE" ) || 0;
    # Get default value for the trailing space after the last bar.
    $defaultBarTrailingSpace = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_BARTRAILINGSPACE" ) || 0;
    # Get default value for the space between bars.
    $defaultBarSpace = &Foswiki::Func::getPreferencesValue( "CHARTPLUGIN_BARSPACE" ) || 0;
}

# Object constructor for creating a ChartPlugin Perl object.  The object is
# initialized with the current web.topic.
sub ChartPlugin {
    my ($currentTopic, $currentWeb, $currentTopicContents) = @_;
    my $this = {};
    bless $this;
    $this->{CURRENT_TOPIC} = $currentTopic;
    $this->{CURRENT_WEB} = $currentWeb;
    $this->{CURRENT_TOPICONTENTS} = $currentTopicContents;
    return $this;
}

# Setter for storing the Table object
sub _setTables { my ($this, $table) = @_; $this->{TABLES} = $table; }
# Getter for Table object
sub _tables { my ($this) = @_; return $this->{TABLES}; }

# Setter for storing the Parameters object
sub _setParameters {
    my ($this, $args) = @_;
    $this->{PARAMETERS} = Foswiki::Plugins::ChartPlugin::Parameters->new($args);
}

# Getter for Parameters object
sub _Parameters { my ($this) = @_; return $this->{PARAMETERS}; }

# This routine sets the specified web.topic as the location from where to
# get the table information.  If the specified web.topic happen to be the
# same as the web.topic from which the %CHART% was found, then the
# web.topic contents is already part of the ChartPlugin object so there is
# nothing to do.  Otherwise, this routine will read in the specified
# web.topic getting its contents and using that as the source to parse out
# table information.
sub _setTopicContents {
    my ($this, $inWeb, $inTopic) = @_;
    my $topicContents;
    # If $inWeb and $inTopic match the current web/topic, then we already
    # have the topic contents in the object so there is nothing to do.
    # Otherwise, we need to open the specified web/topic and read in its
    # contents.
    if ( ($inWeb eq $this->{CURRENT_WEB}) && ($inTopic eq $this->{CURRENT_TOPIC}) ) {
        $topicContents = $this->{CURRENT_TOPICONTENTS};
    } else {
        # A difference, so read in the topic.
        (my $meta, $topicContents) = Foswiki::Func::readTopic( $inWeb, $inTopic );
        # Check to make sure the web.topic actually exists.  If not, return
        # undef so the caller can catch the error.
        return undef if ($topicContents eq "");
        $topicContents = Foswiki::Func::expandCommonVariables($topicContents, $inTopic, $inWeb);
    }

    # Lets parse the specified topic contents looking for tables.
    $this->_setTables(Foswiki::Plugins::ChartPlugin::Table->new($topicContents));
    return 1;
}

# Return the maximum value of the two specified numbers.
sub _max {
    my ( $v1, $v2 ) = @_;
    return $v1 if( $v1 > $v2 );
    return $v2;
}

# Return the minimum value of the two specified numbers.
sub _min {
    my ( $v1, $v2 ) = @_;
    return $v1 if( $v1 < $v2 );
    return $v2;
}

# Generate the file name in which the graphic file will be placed.  Also
# make sure that the directory in which the graphic file will be placed
# exists.  If not, create it.
sub _make_filename {
    my ( $type, $name, $topic, $web ) = @_;
    # Generate the file name to be created
    my $fullname;
    # If GD version 1.19 or earlier, then create gif files else png files.
    if( $GD::VERSION > 1.19 ) {
        $fullname = "_ChartPlugin_${type}_${name}.png";
    } else {
        $fullname = "_ChartPlugin_${type}_${name}.gif";
    }

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = Foswiki::Func::getPubDir() . "/$web";
    if( ! -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if( ! -e "$tempPath" ) {
        umask( 002 );
        mkdir( $tempPath, 0775 );
    }
    # Return both the directory and the filename
    return ($tempPath, $fullname);
}

# This routine returns an red colored error message.
sub _make_error {
    my ( $msg ) = @_;
    return "<font color=red>ChartPlugin error: $msg</font>";
}

# Actually construct the chart by parsing out each of the %CHART%
# parameters, putting the parameters into the chart object, and then
# creating the chart.
sub _makeChart {
    my ( $this, $args, $topic, $web ) = @_;

    # Check to see if the GD module was found.  If not, then create an
    # error message to display back to the user.
    if( $initError ) {
        # It appears that a library wasn't found so we return a
        # different type of error that is just plain text.
        return _make_error($initError);
    }
    # Set/parse the %CHART% parameters putting into the ChartPlugin object
    $this->_setParameters ($args);

    # Make a chart object in which we will place user specified parameters
    my $chart = Foswiki::Plugins::ChartPlugin::Chart->new();

    # See if the parameter 'type' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $type = $this->_Parameters->getParameter( "type", $defaultType);
    return _make_error("parameter *type* must be specified") if( ! defined $type );
    my @unknownTypes = grep(!/area|line|bar|arealine|combo|scatter/, ($type));
    # Check for a valid type
    return _make_error("Invalid value of *$type* for parameter *type* ") if (@unknownTypes);
    $chart->setType($type);

    # See if the parameter 'subtype' (old name 'datatype') is available.
    my $dataType = $this->_Parameters->getParameter( "datatype", undef);
    my $subType = $this->_Parameters->getParameter( "subtype", undef);
    return _make_error("paramters *datatype* and *subtype* can't both be specified") if (defined $dataType && defined $subType);
    $subType = $dataType if (defined $dataType);
    if (defined $subType) {
        my @subTypes = split(/[\s,]+/, $subType);
        # Check for valid subtypes
        my @unknownSubTypes = grep(!/area|line|point|pline|scatter|bar/, @subTypes);
        return _make_error("unknown subtypes: " . join(", ", @unknownSubTypes)) if (@unknownSubTypes);
        # Now check to make sure that the subtypes specified are valid for the
        # specified type.
        ### Check 'line' type
        if ($type eq "line") {
            @unknownSubTypes = grep(!/line|point|pline/, @subTypes);
            return _make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type line") if (@unknownSubTypes);
        }

        ### Check 'area' type
        if ($type eq "area") {
            @unknownSubTypes = grep(!/area/, @subTypes);
            return _make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type area") if (@unknownSubTypes);
        }

        ### Check 'scatter' type
        if ($type eq "scatter") {
            @unknownSubTypes = grep(!/area|line|point|pline|bar/, @subTypes);
            return _make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type scatter") if (@unknownSubTypes);
        }

        ### Check 'combo' type
        if ($type eq "combo") {
            @unknownSubTypes = grep(!/area|line|point|pline|bar/, @subTypes);
            return _make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type combo") if (@unknownSubTypes);
        }

        # All OK so set the subtype.
        $chart->setSubTypes(@subTypes);
    }

    # See if the parameter 'scale' is available.
    my $scale = $this->_Parameters->getParameter( "scale", $defaultScale);
    if ($scale ne "base10" and $scale ne "linear" and $scale ne "semilog") {
        return _make_error("Invalid value of *$scale* for parameter *scale* ");
    }
    $chart->setScale($scale);

    # See if the parameter 'name' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $name = $this->_Parameters->getParameter( "name", undef);
    return _make_error("parameter *name* must be specified") if( ! defined $name );

    # See if the parameter 'web' is available.  If not, then default to
    # looking for tables in the current web.
    my $inWeb = $this->_Parameters->getParameter( "web", $web);

    # See if the parameter 'topic' is available.  If not, then default to
    # looking for tables in the current topic.
    my $inTopic = $this->_Parameters->getParameter( "topic", $topic);

    # Before we parse any further parameters, lets get the contents of the
    # specified web/topic.
    if (! $this->_setTopicContents($inWeb, $inTopic)) {
        return _make_error("Error retrieving Foswiki topic $inWeb<nop>.$inTopic");
    }

    # Determine which table the user wants to chart
    my $tableName = $this->_Parameters->getParameter( "table", 1);
    # Verify that the table name is valid.
    if (! $this->_tables->checkTableExists($tableName) ) {
        return _make_error("parameter *table* is not valid table; the specified table '$tableName' does not exist.");
    }

    # See if the parameter 'title' is available.
    $chart->setTitle($this->_Parameters->getParameter( "title", undef));

    # See if the parameter 'xlabel' is available.
    $chart->setXlabel($this->_Parameters->getParameter( "xlabel", undef));

    # See if the parameter 'ylabel' is available.
    $chart->setYlabel($this->_Parameters->getParameter( "ylabel", undef));

    # See if the parameter 'data' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $data = $this->_Parameters->getParameter( "data", undef);
    return _make_error("parameter *data* must be specified") if( ! defined $data );

    # See if the parameter 'xaxis' is available.
    my $xAxis = $this->_Parameters->getParameter( "xaxis", undef);

    # See if the parameter 'yaxis' is available.
    my $yAxis = $this->_Parameters->getParameter( "yaxis", "off");
    $chart->setYaxis($yAxis);

    # See if the parameter 'ytic' is available.
    my $yTic = $this->_Parameters->getParameter( "ytics", -1);
    $chart->setNumYTics($yTic);

    # See if the parameter 'xaxisangle' is available.
    my $xaxisangle = $this->_Parameters->getParameter( "xaxisangle", 0);
    $chart->setXaxisAngle($xaxisangle);

    # See if the parameter 'ymin' is available.
    my $yMin = $this->_Parameters->getParameter( "ymin", undef);
    if (defined $yMin) {
        if ($scale eq "semilog" && $yMin <= 0) {
            return _make_error("user set ymin=$yMin is &lt;= 0 which is not valid when scale=semilog");
        }
    }
    $chart->setYmin( $yMin );

    # See if the parameter 'ymax' is available.
    my $yMax = $this->_Parameters->getParameter( "ymax", undef);
    if (defined $yMax) {
        if ($scale eq "semilog" && $yMax <= 0) {
            return _make_error("user set ymax=$yMax is &lt;= 0 which is not valid when scale=semilog");
        }
    }
    $chart->setYmax( $yMax );

    # See if the parameter 'numygrids' is available.
    $chart->setNumYGrids( $this->_Parameters->getParameter( "numygrids", $defaultNumYGrids) );

    # See if the parameter 'numxgrids' is available.
    my $numxgrids = $this->_Parameters->getParameter( "numxgrids", 10);
    $chart->setNumXGrids($numxgrids);

    # See if the parameter 'xgrid' is available.
    my $xGrid = $this->_Parameters->getParameter( "xgrid", "dot");
    $chart->setXgrid($xGrid);

    # See if the parameter 'ygrid' is available.
    my $yGrid = $this->_Parameters->getParameter( "ygrid", "dot");
    $chart->setYgrid($yGrid);

    # See if the parameter 'datalabel' is available.
    my $dataLabels = $this->_Parameters->getParameter( "datalabel", "off");
    $chart->setDataLabels(split(/[\s,]+/, $dataLabels)) if (defined $dataLabels);

    # See if the parameter 'legend' is available.
    my $legend = $this->_Parameters->getParameter( "legend", undef);

    # Get the chart width and height
    $chart->setImageWidth( $this->_Parameters->getParameter( "width", $defaultWidth) );
    $chart->setImageHeight( $this->_Parameters->getParameter( "height", $defaultHeight) );

    # Get the chart IMG 'alt' text.
    my $alt = $this->_Parameters->getParameter( "alt", "");

    # Get the chart 'bgcolor' color.
    my $bgcolor = $this->_Parameters->getParameter( "bgcolor", $defaultBGcolor);
    $chart->setBGcolor(split(/[\s,]+/, $bgcolor));

    # Set line/area colors.  If the parameter 'colors' is defined, then the
    # chart will be made with the user specified colors.  Otherwise the
    # chart will be made with the default colors, and then it will depend
    # on if an 'area' or 'line' is being drawn which will determine which
    # set of colors to use.
    $chart->setLineColors(@defaultLineColors);
    $chart->setAreaColors(@defaultAreaColors);
    # See if the parameter 'colors' is available.
    my $colors = $this->_Parameters->getParameter( "colors", undef);
    $chart->setColors(split(/[\s,]+/, $colors)) if (defined $colors);

    # Get the chart grid  color.
    my $gridColor = $this->_Parameters->getParameter( "gridcolor", $defaultGridColor);
    $chart->setGridColor(split(/[\s,]+/, $gridColor));

    # See if the parameter 'defaultdata' is available.
    my $DataValueDefault = $this->_Parameters->getParameter( "defaultdata", $defaultDataValue);
    $DataValueDefault = '' if ($DataValueDefault eq "none");
    $chart->setDefaultDataValue($DataValueDefault);

    # Get the name of the directory and filename in which to create the
    # graphics file.
    my ($dir, $filename) = _make_filename($type, $name, $topic, $web);
    $chart->setFileDir($dir);
    $chart->setFileName($filename);

    # Validate the legend data making sure it only specifies a single row
    # or a single column.
    my @legend;
    if ($legend) {
        my $cnt = my @d = $this->_tables->getData($tableName, $legend);
        if ($cnt > 1) {
            @d = Foswiki::Plugins::ChartPlugin::Table::transpose( @d );
            $cnt = scalar(@d);
        }
        if ($cnt > 1) {
            return _make_error("parameter *legend* specifies multiple ($cnt) rows.");
        }
        if ($cnt == 0) {
            return _make_error("parameter *legend* contains an invalid value '$legend'.");
        }
        @legend = @{$d[0]};
        #die Data::Dumper->Dump([\@legend]);
        $chart->setLegend(@legend);
    }

    # If the user specified an X axis range, then extract from the X axis
    # data the starting and ending row/columns.  This defines whether the
    # data is row ordered or column ordered.  If there is no X axis
    # information specified, then assume that the data is in column order.
    my $columnOrdered = 0;
    my $rowOrdered = 0;
    if (defined ($xAxis)) {
        my ($xAxisRows, $xAxisColumns) =
          $this->_tables->getRowColumnCount($tableName, $xAxis);
        return _make_error("parameter *xaxis* value of '$xAxis' is not valid")
          if (! defined($xAxisRows));
        if (abs($xAxisRows) > 1) {
            if ($xAxisColumns > 1) {
                return _make_error("parameter *xaxis* specifies multiple (${xAxisRows}X$xAxisColumns) rows and columns.");
            }
            $columnOrdered = 1;
        } else {
            $rowOrdered = 1;
        }
        my @d = $this->_tables->getData($tableName, $xAxis, $columnOrdered);
        return _make_error("no X axis data found in specified area of table [$xAxis]") if (! @d);
        $chart->setXaxis(@{$d[0]});
    } else {
        $columnOrdered = 1;
    }

    # Validate the data range as valid
    #my ($dataRows, $dataColumns) =
    #  $this->_tables->getRowColumnCount($tableName, $data);
    #return _make_error("parameter *data* value of '$data' is not valid") if (! defined($dataRows));

    # Get the actual area data.
    my @data = ();
    @data = $this->_tables->getData($tableName, $data, $columnOrdered );
    # Validate that there is real data returned.
    return _make_error("no data found in specified area of table [$data]") if (! @data);
    #my @ranges = $this->_tables->getTableRanges($tableName, $data);
    #die $data, ' ', Data::Dumper->Dump([\@ranges]);
    $yMin = $chart->setData(@data);
    # If scale=semilog and any data is <= 0, then error
    if ($scale eq "semilog" && $yMin <= 0) {
        return _make_error("data ($yMin) &lt;= 0 not valid when scale=semilog");
    }

    # Make sure that there are enough legends to go with all specified
    # data sets (if legends were specified)
    if ($legend) {
        my $numLegends = @legend;
        my $numDataSets = @data;
        if ($numDataSets != $numLegends) {
            return _make_error("parameter *legend* contains an invalid value '$legend' since it specifies $numLegends legends and there are $numDataSets data sets.");
        }
    }

    # Set the default point size
    $chart->setPointSize( $this->_Parameters->getParameter( "pointsize", $defaultPointSize ) );

    # Set the default line width
    $chart->setLineWidth( $this->_Parameters->getParameter( "linewidth", $defaultLineWidth ) );

    # Set default bar graph values
    $chart->setBarLeadingSpace($defaultBarLeadingSpace);
    $chart->setBarTrailingSpace($defaultBarTrailingSpace);
    $chart->setBarSpace($defaultBarSpace);

    # Create the actual chart.
    my $err = $chart->makeChart();
    return _make_error("chart error: name=$name: $err") if ($err);

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    my %parameters = $this->_Parameters->getAllParameters();
    foreach my $k (keys %parameters) {
        $options .= "$k=\"$parameters{$k}\" ";
    }
    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so changes to the values used to generate the chart, or the
    # chart layout specifications, are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values/parameters used in creating the chart have changed.
    my $timestamp = time();
    return "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$alt\" $options />";
}

# The following is really for debugging and timing purposes and is not an
# advertised interface.  This routine basically creates a number of charts
# and (roughly) times how long it took to create them.
# Usage: %CHART_TIMER{### <parameters>}%
# where ### is the number of charts to create and <parameters> are valid
# %CHART% parameters ('name' is overridden by the timer so is ignored if
# specified in <parameters>
sub _timeit {
    my ( $this, $loops, $params, $topic, $web ) = @_;
    my $removeFiles = 0;	# Flag on whether to remove the test graphics or not
    my $start_time = time();
    for (my $i = 0; $i < $loops; $i++) {
        my $str = "$params name=\"timeit_$i\"";
        $this->_makeChart( $str, $topic, $web );
    }
    my $finish_time = time();
    my $diff = $finish_time - $start_time;
    # Remove the just created test files.
    if ($removeFiles) {
        for (my $i = 0; $i < $loops; $i++) {
            my ($dir, $filename) = _make_filename("area", "timeit_$i", $topic, $web);
            unlink("$dir/$filename");
        }
    }
    return "To make $loops charts it (roughly) took $diff seconds.<BR>";
}

# =========================
sub commonTagsHandler {
    ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    my $topic = $_[1];
    my $web = $_[2];

    # If no %CHART%s on this page, then there is nothing to do so just
    # return.
    if ( $_[0] !~ m/%CHART.*{.*}%/) {
        # nothing to do
        return;
    }
    _init_defaults();
    my $chart = ChartPlugin($topic, $web, $_[0]);
    $_[0] =~ s/%CHART{(.*?)}%/$chart->_makeChart($1, $topic, $web)/eog;
    $_[0] =~ s/%CHART_TIMER{(\d+) (.*)}%/$chart->_timeit($1, $2, $topic, $web)/eog;
}

1;
