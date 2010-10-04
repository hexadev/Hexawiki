# See bottom of file for license and copyright information

# Each map stored in the DB has a unique handle
# The data in the map is stored using the handle
# So, we tie a Map to the particular key we are interested in.
# When a FETCH is done on a referenced object, we need to convert that to a key.
# When a STORE is with a Map or Array type object, we need to convert that
# to a key.

package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map;
use strict;

use Foswiki::Contrib::DBCacheContrib::Map ();
# Mixin collections code
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::Map',
         'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection' );

use Assert;

# Create a new hash, or bind to an existing hash if id is passed
sub new {
    my $class = shift;
    my %args  = @_;
    my $initial;
    if ( $args{initial}) {

        # Delay parsing until we are bound
        $initial = $args{initial};
        delete $args{initial};
    }
    my $this = $class->SUPER::new(%args);
    if ( defined $args{id} ) {

        # Binding to existing record
        $this->{id} = $this->{archivist}->allocateID( $args{id} );
    }
    else {

        # Creating new record
        $this->{id} = $this->{archivist}->allocateID();
    }
    if ($initial) {
        if (ref($initial)) {
            while (my ($k, $v) = each %$initial) {
                $this->STORE($k, $v);
            }
        } else {
            $this->parse($initial);
        }
    }
    return $this;
}

sub STORE {
    my ( $this, $key, $value ) = @_;
    my $id = $this->getID($key);
    my %keys = map { $_ => 1 } $this->getKeys();
    unless ( $keys{$key} ) {
        push( @{ $this->{keys} }, $key );
        $this->{archivist}->db_set(
            'K'.$this->{id}, join( "\0", @{ $this->{keys} } ));
    }
    $this->{archivist}->db_set($id, $this->{archivist}->encode($value));
}

sub FIRSTKEY {
    my $this = shift;
    $this->getKeys();
    $this->{keyIt} = 0;
    return $this->{keys}->[$this->{keyIt}++];
}

sub NEXTKEY {
    my ( $this, $lastkey ) = @_;
    return unless $this->{keyIt} < scalar(@{$this->{keys}});
    return $this->{keys}->[$this->{keyIt}++];
}

sub EXISTS {
    my ( $this, $key ) = @_;
    return $this->{archivist}->db_exists( $this->getID($key) );
}

sub DELETE {
    my ( $this, $key ) = @_;
    $this->{archivist}->db_delete( $this->getID($key) );
    $this->getKeys();
    my %keys = map { $_ => 1 } $this->getKeys();
    delete( $keys{$key} );
    $this->{archivist}->db_set('K'.$this->{id}, join( "\0", keys %keys ));
    $this->{keys} = undef;
}

sub SCALAR {
    my ($this) = @_;
    my %keys = map { $_ => 1 } $this->getKeys();
    return scalar %keys;
}

sub equals {
    my ( $this, $that ) = @_;
    return 0 unless ref($that) eq ref($this);
    return $that->{id} eq $this->{id};
}

sub getKeys {
    my $this = shift;

    unless ( defined $this->{keys} ) {
        @{ $this->{keys} } =
          split( "\0", $this->{archivist}->db_get('K'.$this->{id}) || '' );
    }

    return @{ $this->{keys} };
}

sub getValues {
    my $this = shift;

    my @values;
    foreach my $k ( $this->getKeys() ) {
        push( @values, $this->FETCH($k) );
    }
    return @values;
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
