# See bottom of file for copyright and license information

=begin tml

---+ package Foswiki::Plugins::ObjectPlugin::Object

Object that represents a single object

=cut

package Foswiki::Plugins::ObjectPlugin::Object;
# use base Foswiki::Meta;

use strict;
use integer;

require Foswiki::Time;
require Foswiki::Func;
require Foswiki::Attrs;
require Foswiki::Form;
require Time::ParseDate;

use vars qw( $now );
# use Data::Dumper;
use JSON;

sub setNow {
	$now = time();
}

# PUBLIC Constructor
sub new {
    my ( $class, $web, $topic, $attrs, $descr, $meta ) = @_;

    my $this = bless({}, $class);  # $class->SUPER::new($session, $web, $topic);

    my $attr = new Foswiki::Attrs( $attrs, 1 );
	my $type = $attr->{type};
	
	# throw Foswiki::OopsException('object',web=>$web,topic=>$topic,def=>'badobject',params=>[$attrs]) unless $type;
	$this->{oDef} = loadObjectDef($type,$web);
	# Foswiki::Plugins::ObjectPlugin::writeDebug("new ".$this->{oDef});
	return 0 unless ref($this->{oDef});
	my $objectTypes = $this->{oDef}->{types};
	
    # conditionally load field values, interpreting them
    # according to their type.
    foreach my $key ( keys %$attr ) {
		next if $key =~ m/^_/;
        my $fieldType = $objectTypes->{$key};
		# next unless $fieldType;
		$fieldType ||= 'text'; # dynamically generated objects can contain whatever attributes they want
        my $val = dataDecode($attr->{$key});
		if ( $fieldType =~ 'multi' ) {
			@{$this->{$key}} = split(/\s*,\s*/, $val);
        } else { # should we be filtering 'label' types?
            # treat as plain string; text, select
            $this->{$key} = $val;
        }
		# Foswiki::Plugins::ObjectPlugin::writeDebug("$key = $val");
    }

    # do these last so they override any attribute values
    $this->{web} = $web;
    $this->{topic} = $topic;
	$this->{meta} = $meta;  # meta hash of the $topic containing the object
	# $this->{session} = $session;

	$descr = dataDecode($descr);
	# $descr =~ s/^\s{3}/\t/sgo;
	# $descr =~ s/^\s+//sgo;
    $descr =~ s/\s+$//o;
    $descr =~ s/\r+//o;

    $this->{text} = $descr;
	$this->{type} = lc $type;
	
	# Foswiki::Plugins::ObjectPlugin::writeDebug(Dumper($this));
    return $this;  #bless( $this, $class );
}

sub setMeta {
	my ($this, $meta) = @_;
	$this->{meta} = $meta;
}

sub loadObjectDef {
	my ($type, $web) = @_;
	unless ($type) {
		Foswiki::Func::writeWarning("ObjectPlugin - missing object type.");
		return 'none';
	}
	$type = ucfirst $type;
	
	my $session = $Foswiki::Plugins::SESSION;
	
	my $formObjects = $session->{objectplugin}->{forms};
	# Foswiki::Plugins::ObjectPlugin::writeDebug("loadObjectDef ".$formObjects->{"$web.$type"});
	return $formObjects->{"$web.$type"} if $formObjects->{"$web.$type"};

	my $formTopic = $type.'Object';
	my $formWeb;
	if (Foswiki::Func::topicExists($web, $formTopic)) {
		$formWeb = $web;
	} elsif (Foswiki::Func::topicExists('%USERSWEB%', $formTopic)) {
		$formWeb = '%USERSWEB%';
	} elsif (Foswiki::Func::topicExists('%SYSTEMWEB%', $formTopic)) {
		$formWeb = '%SYSTEMWEB%';
	} else {
		Foswiki::Plugins::ObjectPlugin::writeDebug(
			"ObjectPlugin - an object definition for type $type cannot be found. Using default params only.");
		# $formObjects->{"$web.$type"} = 'none';
		# return 'none';
	}

	my $objectDef;
	if ($formWeb) {
		$objectDef = new Foswiki::Form($session, $formWeb, $formTopic);
		$objectDef->{types} = {};
		foreach my $fieldDef (@{$objectDef->{fields}}) {
			$objectDef->{types}->{$fieldDef->{name}} = $fieldDef->{type};
			if ($fieldDef->{type} =~ /noload/) { # cache the values for css, js and sanitise
				$objectDef->{$fieldDef->{name}} = $fieldDef->{value};
			}
		}
	} else {
		$objectDef = {
						types => {}
					};
	}
	foreach my $default (qw(creator created uid deleted edited)) {
		$objectDef->{types}->{$default} = 'default';
	}
	$objectDef->{types}->{created} .= ',date';
	foreach my $reserved (qw(type reltopic)) {
		$objectDef->{types}->{$reserved} = 'reserved';
	}
	foreach my $noload (qw(oDef meta css js insertpos insertloc)) {
		$objectDef->{types}->{$noload} = 'noload';
	}

	$formObjects->{"$web.$type"} = $objectDef;
	
	return $objectDef;
}

# Allocate a new UID for this object.
sub getNewUID {
    my $this = shift;

    my $workArea = Foswiki::Func::getWorkArea('ObjectPlugin');
    my $uidRegister = $workArea . '/UIDRegister_' . $this->{type};

    my $lockFile = $uidRegister.'.lock';

    # Could do this using flock but it's not guaranteed to be
    # implemented on all systems. This technique is simpler
    # and mostly works.
    # COVERAGE OFF lock file wait
    while ( -f $lockFile ) {
        # if it's more than 10 mins old something is wrong, so just ignore
        # it.
        my @s = stat( $lockFile );
        if( time() - $s[9] > 10 * 60 ) {
            Foswiki::Func::writeWarning("Object Plugin: Warning: broke $lockFile");
            last;
        }
        sleep(1);
    }
    # COVERAGE ON

    open( FH, ">$lockFile" ) or die "Locking $lockFile: $!";
    print FH "locked\n";
    close( FH );

    my $lastUID = 0;
    if ( -f $uidRegister ) {
        open( FH, "<$uidRegister" ) or die "Reading $uidRegister: $!";
        $lastUID = <FH>;
        close( FH );
    }

    my $uid = $lastUID + 1;
    open( FH, ">$uidRegister" ) or die "Writing $uidRegister: $!";
    print FH "$uid\n";
    close( FH );
    unlink( $lockFile ) or die "Unlocking $lockFile: $!";

    $this->{uid} = $this->{type} . sprintf( '%06d', $uid );
}

sub populateDefaultFields {
    my $this = shift;

    if ( !defined($this->{uid}) || $this->{uid} eq '' ) {
        $this->getNewUID();
    }

    if ( !defined($this->{creator}) || $this->{creator} eq '' ) {
        $this->{creator} = Foswiki::Func::getWikiName();
    }

    if ( !defined($this->{created}) || $this->{created} eq '' ) {
        $this->{created} = formatTime($now,'attr');
    }
	
	# $this->{deleted} = '' unless defined $this->{deleted};
	# $this->{edited} = '' unless defined $this->{edited};
}

# PUBLIC format as an object
sub stringify {
    my $this = shift;
    my $attrs = '';
    my $descr = '';

	$this->populateDefaultFields();
# Foswiki::Plugins::ObjectPlugin::writeDebug(Dumper($this));
	my $types = $this->{oDef}->{types};
    foreach my $key ( sort keys %$this ) {
		# only stringify the key if there is an associated value
        my $type = $types->{$key} || 'noload';
        if ( $key eq 'text') {
            $descr = $this->{text};
			$descr =~ s/^(?:\t|   )+(\*\s+?(?:Set|Local)\s+?\w+\s*?=\s*?.*?)$/>>>$1/mg; # no sneaking in any preferences
			# $descr =~ s/^\s{3}/\t/os;
            $descr =~ s/\s+$//os;
			$descr =~ s/%(\w*OBJECT\w*)\{/%<nop>$1\{/gso;
        } elsif ( $type =~ /multi/ ) {
				# Foswiki::Plugins::ObjectPlugin::writeDebug(Dumper($this->{$key}));
				my $val = join(',',@{$this->{$key}});
				$attrs .= ' '.$key.'="'.dataEncode($val) . '"' if $val ne '';
		} elsif ( $type !~ /noload/ && $this->{$key} ne '' ) {
			# select or text; treat as plain text
			$attrs .= ' '.$key.'="'.dataEncode($this->{$key}) . '"';
		}
    }

    return '%OBJECT{'.$attrs.'}%'.$descr.'%ENDOBJECT%';
}

sub TO_JSON {
	my $this = shift;
	my $new = {};
	my $types = $this->{oDef}->{types};
	foreach my $key (keys %$this) {
		# return everything unless specifically told not to
		next if $types->{$key} && $types->{$key} =~ /noload/;
		$new->{$key} = $this->{$key};
	}
	return $new;
}

# PRIVATE STATIC format a time string
sub formatTime {
    my ( $time, $format ) = @_;
    my $stime;

    # Default to time=0
    $time ||= 0;

    if (!$time) {
        $stime = '';
    } elsif ( $format eq 'attr' ) {
        $stime = Foswiki::Func::formatTime( $time, '$iso', 'servertime' );
    } else {
        $stime = Foswiki::Func::formatTime( $time, '$wday, $day $month $year - $hours:$minutes', 'servertime' );
    }
    return $stime;
}

# PRIVATE match the passed names against the given names type field.
# The match passes if any of the names passed matches any of the
# names in the field.
sub _matchType_names {
    my ( $this, $vbl, $val ) = @_;

    return 0 unless ( defined( $this->{$vbl} ));

    foreach my $name ( split( /\s*,\s*/, $val )) {
        my $r;
        eval {
            $r = ( $this->{$vbl} =~ m/$name,\s*/ || $this->{$vbl} =~ m/$name$/);
        };
        return 1 if ( $r );
    }
    return 0;
}

sub _matchType_date {
    my ( $this, $vbl, $val ) = @_;
    my $cond;
    if ( $val =~ s/^([><]=?)\s*// ) {
        $cond = $1;
    } else {
        $cond = '==';
    }
    return 0 unless defined( $this->{$vbl} );
	$vbl = Foswiki::Time::parseTime($this->{$vbl});
    my $tim = Time::ParseDate::parsedate( $val, PREFER_PAST => 1, FUZZY => 1 );
    return eval "$vbl $cond $tim";
}

# PUBLIC true if the object matches the search attributes
# The match is made either by calling a match function for the attribute
# or by comparing the value of the field with the value of the
# corresponding attribute, which is considered to be an RE.
# To match, an object must match all conditions.
sub matches {
    my ( $this, $a ) = @_;
	my $types = $this->{oDef}->{types};
    foreach my $attrName ( keys %$a ) {
        next if $attrName =~ /^_/;
        my $attrVal = $a->{$attrName};
        my $attrType = $types->{$attrName};
		$attrType = 'date' if $attrType =~ m/date/;
        my $class = ref( $this );
        if ( defined( $attrType ) &&
                  defined( &{$class."::_matchType_$attrType"} ) ) {
            my $fn = "_matchType_$attrType";
            if ( !$this->$fn( $attrName, $attrVal )) {
                return 0;
            }
        } elsif ( defined( $attrVal ) &&
                  defined( $this->{$attrName} ) ) {
            # re match
            my $r;
            eval {
                $r = ( $this->{$attrName} !~ m/$attrVal/ );
            };
            return 0 if ( $r );
        } else {
            return 0;
        }
    }
    return 1;
}

# PUBLIC STATIC create a new object filling in attributes
# from a CGI query as used in the object edit.
sub createFromQuery {
    my ( $web, $topic, $query ) = @_;
    my $desc = $query->param( 'text' ) || 'No description';
    # $desc =~ s/\r?\n\r?\n/ <p \/>/sgo;
    # $desc =~ s/\r?\n/ <br \/>/sgo;

    # for each of the legal attribute types, see if the query
    # contains a value for that attribute. If it does, fill it
    # in.
    my $attrs = '';
	my $objectDef = loadObjectDef($query->param('type'),$web);
	throw Foswiki::OopsException('object',
								web=>$web,topic=>$topic,
								def=>'missingobjecttype',
								params=>$query->query_string()) unless ref($objectDef);

    my $types = $objectDef->{types};
	foreach my $attrname ( keys %$types ) {
		if ( $types->{$attrname} !~ m/(default|noload)/o ) {
			my @values = $query->param( $attrname );
			my $val = '';
			$val = join(',',@values) if scalar @values;
			$attrs .= ' '.$attrname.'="'.dataEncode($val).'"';
		}
    }
    return new Foswiki::Plugins::ObjectPlugin::Object( $web, $topic, $attrs, $desc );
}

# PUBLIC STATIC update an existing object filling in attributes
# from a CGI query as used in the object edit.
sub updateFromQuery {
    my ( $this, $query ) = @_;
    my $desc = $query->param( 'text' );
	if ($desc) {
	    # $desc =~ s/\r?\n\r?\n/ <p \/>/sgo;
	    # $desc =~ s/\r?\n/ <br \/>/sgo;
		# $desc =~ s/^\s{3}/\t/sgo;
	    $this->{text} = $desc; #dataEncode{$desc};
	}

    # for each of the legal attribute types, see if the query
    # contains a value for that attribute. If it does, fill it
    # in.
	my $types = $this->{oDef}->{types};
    foreach my $attrname ( keys %$types ) {
        my $type = $types->{$attrname};
        if ( $type =~ m/multi/o ) {
            my @val = $query->param( $attrname );
            if ( scalar @val ) {
                @{$this->{$attrname}} = @val;
            }
        } elsif ( $type !~ m/(default|noload)/o ) {
			my $val = $query->param( $attrname );
			$this->{$attrname} = $val if $val;
		}
    }
	
	# update the edit history if required
	my $existing = '';
	if ($this->{edited}) {
		my ($lastEdit, $ignore) = split(/=/,$this->{edited},2);
		return if ($now - Foswiki::Time::parseTime($lastEdit)) 
								< $Foswiki::cfg{ReplaceIfEditedAgainWithin};
		$existing = ','.$this->{edited};
	}
	$this->{edited} = formatTime($now,'attr').'='.Foswiki::Func::getWikiName().$existing;
}

sub deleteObject {
	my $this = shift;
	
	$this->{deleted} = formatTime($now,'attr').'='.Foswiki::Func::getWikiName();
}

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

# PRIVATE get the given template and do standard expansions
sub _getTemplate {
    my ( $this, $type, $tail, $warn ) = @_;
	$tail ||= '';

	my $tmpls = $Foswiki::Plugins::SESSION->{objectplugin}->{templates};
	return $tmpls->{$type.$tail} if $tmpls->{$type.$tail};
	Foswiki::Plugins::ObjectPlugin::writeDebug('tmpls->{type.tail} must be empty, getting template from file');

    $warn ||= '';
	my $name = $type.$tail;

	my $file = ucfirst $type;
    # Get the templates.
    my $templates = Foswiki::Func::loadTemplate( $file );
    if (! $templates ) {
	    my $templateFile = Foswiki::Func::getPreferencesValue('OBJECTPLUGIN_DEFAULTTEMPLATES') || 'Object';
        Foswiki::Plugins::ObjectPlugin::writeDebug(
			"Could not read template file '".$file."Template'. Using ".$templateFile."Template file.");
		$name = 'object'.$tail;
		$templates = Foswiki::Func::loadTemplate( $templateFile );
        # TODO: throw installation error if still no templates
    }

    my $t = Foswiki::Func::expandTemplate( $name );
    $t = "%RED%No such template def TMPL:DEF{$name}%ENDCOLOR%"
		unless ( defined($t) && $t ne '' ) || $warn eq 'off';

	# the template for a given object type should only be loaded once, 
	# same goes for 'adding' of the css and js files
    Foswiki::Func::addToZone('head','ObjectPlugin_'.$type.'_CSS', 
		qq(<link rel="stylesheet" href="$this->{oDef}->{'css'}" type="text/css" media="all" />),
		'OBJECTPLUGIN_CSS') 
			if $this->{oDef}->{'css'};
    Foswiki::Func::addToZone('body','ObjectPlugin_'.$type.'_JS', 
		qq(<script type="text/javascript" src="$this->{oDef}->{'js'}"></script>),
		'OBJECTPLUGIN_JS') 
			if $this->{oDef}->{'js'};
	# Foswiki::Plugins::ObjectPlugin::writeDebug("css: $this->{oDef}->{'css'}, js: $this->{oDef}->{'js'}");

	$tmpls->{$type.$tail} = $t;
	Foswiki::Plugins::ObjectPlugin::writeDebug($tmpls->{$type.$tail});
    return $t;
}

sub prepareForDisplay {
	my ($this, $format, $bgClass) = @_;
	$format ||= undef; # format can be defined in an OBJECTSEARCH
	$bgClass ||= '';
	my $tmpl = '';
	my $when = '';
	my $who = '';
	my $session = $Foswiki::Plugins::SESSION;
	
	if ($this->{deleted}) {
		# the display template for the given type of a deleted object 
		# may be an empty string so turn off the warning
		$tmpl = $this->_getTemplate($this->{type}, ':deleted', 'off');
		($when, $who) = split(/=/,$this->{deleted});
	} else {
		$tmpl = $this->_getTemplate($this->{type});
		if ($this->{edited}) { 
			my @edits = split(/,/,$this->{edited});
			($when, $who) = split(/=/,$edits[0]);
		}
		$tmpl = $format if $format; 
		# done like this so _getTemplate can load the js and css so it can be used in the format
	}

	my $val;
	my $fields = $this->{oDef}->{types};
	foreach my $field ( keys %$fields ) {
		my $type = $fields->{$field};
		if ( $type =~ m/multi/o ) {
			$val = defined $this->{$field} ? join(',',@{$this->{$field}}) : '';
		} elsif ( $type =~ m/date/o ) {
			$val = formatTime(Foswiki::Time::parseTime($this->{$field}),'string');
		} elsif ( $type !~ m/noload/o ) {
			$val = $this->{$field} || '';
		} else {
			$val = '';
		}
		$tmpl =~ s/\$$field/$val/g;
	}
	my $descr = $this->{text};
	# Translate newlines in the description to XHTML tags
	# $descr =~ s/\n\n/<p \/>/gos;
	# $descr =~ s/\n([^(?:(?:   |\t)+\*)])/<br \/>$1/gos;
	$descr =~ s/%(\w*OBJECT\w*)\{/%<nop>$1\{/gso;
	$descr =~ s/<(\/?script)/&lt;$1/gsoi;  # knobble any attempt at running scripts
	$tmpl =~ s/(%TEXT%|\$text)/$descr/;
	
	if ($tmpl =~ /%ATTACHMENTS%/) {
		my $atchs = '';
		if ($this->{attachments}) {
			#my @attachments = split(/\s*,\s*/,$this->{attachments});
			foreach my $attachment (@{$this->{attachments}}) {
				next unless $attachment;
				my $fileType = $session->mapToIconFileName($attachment); # SMELL: no func api
				my $iconUrl = $session->getIconUrl(0, $fileType);
				my $icon = '<img src="'.$iconUrl.'" width="16" height="16" align="top" '.
				  'alt="'.$fileType.'" border="0" />';
				$atchs .= "   * $icon [[%PUBURL%/$this->{web}/$this->{topic}/$attachment][$attachment]]\n";
			}
		}
		$tmpl =~ s/(%ATTACHMENTS%|\$attachments)/$atchs/;
	}
	
	# Tidy up the skin string -
	# 'object' is already part of the template
	# and 'ajax' gets added client side if js is enabled
	my $skin = Foswiki::Func::getSkin();
	my @skin = split(/\s*,\s*/,$skin);
	@skin = grep(/!(object|ajax)/,@skin);
	$skin = join(',',@skin);
	
	$tmpl =~ s/(%CMDSKIN%|\$cmdskin)/$skin/g;
	$tmpl =~ s/(%WHEN%|\$when)/$when/g;
	$tmpl =~ s/(%WHO%|\$who)/$who/g;
	$tmpl =~ s/(%BG%|\$bg)/$bgClass/g;  # css striping if it's wanted
	$tmpl =~ s/(%OWEB%|\$oweb)/$this->{web}/g;
	$tmpl =~ s/(%OTOPIC%|\$otopic)/$this->{topic}/g;
	Foswiki::Plugins::ObjectPlugin::writeDebug("prepareForDisplay - finished.");

	return $tmpl;
}

sub renderForDisplay {
	my $this = shift;
	my $tmpl = Foswiki::Func::readTemplate('view');
	my $text = $this->prepareForDisplay();

	Foswiki::Plugins::ObjectPlugin::addDefaultsToPage();

	$tmpl =~ s/%TEXT%/$text/o;
    $tmpl = Foswiki::Func::expandCommonVariables($tmpl);
    $tmpl = Foswiki::Func::renderText($tmpl);
	Foswiki::Plugins::ObjectPlugin::writeDebug("renderForDisplay - finished.");
	return $tmpl;
}

sub renderForEdit {
	my $this = shift;
	my $web = $this->{web};
	my $topic = $this->{topic};
	$this->{uid} ||= '';
	$this->{type} ||= 'object';
	
	# my $name = "EDIT:".$this->{type};
	# my $tmpl = _getTemplate($this->{type}, $name);
    my $tmpl = Foswiki::Func::readTemplate('edit', Foswiki::Func::getSkin());

    $tmpl =~ s/%UID%/$this->{uid}/g; # here because of ADDTOZONE which otherwise would remove the tag as part
									 # of the next step before it could be replaced here
    $tmpl = Foswiki::Func::expandCommonVariables($tmpl);
    $tmpl = Foswiki::Func::renderText($tmpl);

	my $formText = '';
	my $formDef = $this->{oDef};
	
	if ($formDef->{fields}) { # only if the object has an object definition topic
		my $meta = new Foswiki::Meta($Foswiki::Plugins::SESSION, $web, $topic);
		my $newObject = $this->{uid} ? 0 : 1;
		my $types = $formDef->{types};
		
		foreach my $fieldDef (@{$formDef->{fields}}) {
			my $name = $fieldDef->{name};
			next if ($types->{$name} =~ m/noload/o);
			my $title = $fieldDef->{title};
			if ($name =~ m/\battachments\b/oi) {
				my @attachments = $this->{meta}->find('FILEATTACHMENT');
				$fieldDef->{value} = '';
				foreach my $attachment (@attachments) {
					$fieldDef->{value} .= ','.$attachment->{name};
				}
			}
			my $value = '';
			if ($newObject) {
				# $value = Foswiki::expandStandardEscapes($fieldDef->{value});
			} elsif ( $types->{$name} =~ m/multi/o ) {
				$value = defined $this->{$name} ? join(',',@{$this->{$name}}) : '';
			} else {
				$value = $this->{$name};
			}
			# Foswiki::Plugins::ObjectPlugin::writeDebug("adding name = $name, value = $value to meta object");
			$meta->putKeyed('FIELD',{name => $name, title => $title, value => $value});
		}
		
		$formText = $formDef->renderForEdit( $web, $topic, $meta );
	}
	
	$tmpl =~ s/%FORMFIELDS%/$formText/g;

	$tmpl =~ s/%TYPE%/$this->{type}/g;

    # Process the text so it's nice to edit.
	my $text = $this->{text};
    $text =~ s/^\t/   /gos;
    $text =~ s/<br( \/)?>/\n/gios;
    $text =~ s/<p( \/)?>/\n\n/gios;
    $text = Foswiki::entityEncode( $text );
    $tmpl =~ s/%TEXT%/$text/g;

	return $tmpl;
}

1;
__DATA__
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
