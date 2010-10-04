# See bottom of file for license and copyright information

# Implementation of Archivist for talking to a Berkeley DB.
#
# A Berkeley DB is a flat hash, so we have to be able to flatten out
# data structures involving hashes and arrays into this flat key map.
# This is done by the methods in the Collection, Map and Array classes.
# Each data structure stored in the DB has a unique ID, which is a number.
# This number is used as the index of a key in the DB that contains an
# encoded and typed value. If the type of the value is MAP or ARRAY, then
# the value is interpreted as an ID (effectively a reference to another
# structure).
# Structures themselves use other encodings to store information about
# the structure. For example, an array stores its size under (SCALAR)
# key 'S<id>' and the individual array entries under '<id>\0<n>' where <n> is
# the index of the entry, and a map stores a list of keys under 'K<id>' and
# the key data under '<id>\0<key>'.
#
# All keys and IDs are byte encoded.
#
# SMELL: looking up individual leaf values this way is not very efficient.
# It would be better to cache entire structures in memory.
#
package Foswiki::Contrib::DBCacheContrib::Archivist::BDB;
use strict;

use Foswiki::Contrib::DBCacheContrib::Archivist ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::Archivist' );

use Assert;

use BerkeleyDB ();

use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map ();
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array ();

# Type constants
sub _SCALAR { 0 };
sub _MAP    { 1 };
sub _ARRAY  { 2 };

sub new {
    my ( $class, $cacheName ) = @_;

    my $workDir   = Foswiki::Func::getWorkArea('DBCacheContrib');
    $cacheName =~ s/\//\./go;
    my $file = $workDir.'/'.$cacheName;

    my $this = bless( {}, $class );
    $this->{db} = new BerkeleyDB::Hash(
        -Flags    => BerkeleyDB::DB_CREATE(),
        -Filename => $file
    );
    ASSERT(defined $this->{db}, "$file: $! $BerkeleyDB::Error") if DEBUG;
    $this->{stubs} = {};
    return $this;
}

# Functions used to access the DB. These are intended to be used within the
# package only.

# Package private
sub db_get {
    my ($this, $key) = @_;
    my $value;
    my $status = $this->{db}->db_get($key, $value);
    return $status ? undef : $value;
}

# Package private
sub db_set {
    my ($this, $key, $value) = @_;
    my $status = $this->{db}->db_put($key, $value);
    return $status;
}

# Package private
sub db_exists {
    my ($this, $key) = @_;
    my $value;
    my $status = $this->{db}->db_get($key, $value);
    return $status ? 0 : 1;
}

# Package private
sub db_delete {
    my ($this, $key) = @_;
    my $status = $this->{db}->db_del($key);
    return $status;
}


sub getRoot {
    my $this = shift;
    unless ( $this->{root} ) {
        my $root = $this->db_get('__ROOT__');
        if ( $root ) {
            $this->{root} = $this->decode( $root );
        }
        else {
            # The root is always a map
            $this->{root} = $this->newMap();
            $this->{db}->db_put('__ROOT__', $this->encode($this->{root}))
        }
    }
    return $this->{root};
}

sub clear {
    my $this = shift;
    $this->{stubs} = {};
    $this->{root}  = undef;
}

sub DESTROY {
    my $this = shift;

    #$this->{db}->db_sync();
    #$this->{db}->db_close();
    undef $this->{db};
    undef $this->{stubs};
}

sub newMap {
    my $this = shift;
    return new Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map(
        archivist => $this,
        @_
    );
}

sub newArray {
    my $this = shift;
    return new Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array(
        archivist => $this,
        @_
    );
}

sub sync {
    my ( $this, $data ) = @_;
    return unless $this->{db};
    $this->{db}->db_sync();
}

sub encode {
    my ( $this, $value ) = @_;
    my $type = _SCALAR;
    if (
        UNIVERSAL::isa(
            $value, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map'
        )
      )
    {
        $type  = _MAP;
        $value = $value->{id};
    }
    elsif (
        UNIVERSAL::isa(
            $value, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array'
        )
      )
    {
        $type  = _ARRAY;
        $value = $value->{id};
    }
    elsif ( ref($value) ) {
        # SMELL: could use Data::Dumper or another freezer
        die 'Unstorable type ' . ref($value);
    }
    else {
        $value = '' unless defined $value;
    }
    $value = pack( 'ca*', $type, $value );
    return $value;
}

# Given an encoded value from the DB, decode it and if necessary create
# the stub map or array object.
# Note that this doesn't re-use stubs when the same id is referenced
# again. Perhaps it should.
sub decode {
    my ( $this, $s ) = @_;
    return $s unless defined $s && length($s);
    my ( $type, $value ) = unpack( 'ca*', $s );
    if ( $type != _SCALAR ) {
        if ( $type == _MAP ) {
            $this->{stubs}->{$value} ||= $this->newMap( id => $value );
        }
        elsif ( $type == _ARRAY ) {
            $this->{stubs}->{$value} ||= $this->newArray( id => $value );
        }
        else {
            die 'Corrupt DB; type '.$type;
        }
        $value = $this->{stubs}->{$value};
    }
    return $value;
}

# If passed an ID, make sure it can't get created again.
# If not passed an id, allocate one. Nothing gets explicitly
# created in the DB; we just reserve the ID.
sub allocateID {
    my ( $this, $id ) = @_;
    my $oid = $this->db_get('__ID__') || 0;
    if ( defined $id ) {
        if ( $id >= $oid ) {
            $this->db_set('__ID__', $id + 1);
        }
        return $id;
    }
    else {
        $this->db_set('__ID__', $oid + 1);
        return $oid;
    }
}

1;
__END__

Copyright (C) Crawford Currie 2009, http://c-dot.co.uk
and Foswiki Contributors. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution. NOTE: Please extend
that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
