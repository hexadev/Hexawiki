# See bottom of file for license and copyright information

package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array;
use strict;

use Foswiki::Contrib::DBCacheContrib::Array ();
# Mixin collections code
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::Array',
         'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection' );

use Assert;

sub new {
    my $class = shift;
    my %args  = @_;
    my $this  = $class->SUPER::new(%args);
    if ( defined $args{id} ) {

        # Binding to existing record
        $this->{id} = $this->{archivist}->allocateID( $args{id} );
    }
    else {

        # Creating new record
        $this->{id} = $this->{archivist}->allocateID();
    }
    return $this;
}

sub STORE {
    my ( $this, $index, $value ) = @_;
    if ( $index >= $this->FETCHSIZE() ) {
        $this->STORESIZE( $index + 1 );
    }
    $this->{archivist}->db_set(
        $this->getID($index), $this->{archivist}->encode($value));
}

sub FETCHSIZE {
    my ($this) = @_;
    unless (defined $this->{size}) {
        $this->{size} = $this->{archivist}->db_get('S'.$this->{id}) || 0;
    }
    return $this->{size};
}

sub STORESIZE {
    my ( $this, $count ) = @_;
    my $sz = $this->FETCHSIZE();
    if ( $count > $sz ) {
        for ( my $i = $sz ; $i < $count ; $i++ ) {
            $this->{archivist}->db_set( $this->getID($i), '');
        }
    }
    elsif ( $count < $sz ) {
        for ( my $i = $count ; $i < $sz ; $i++ ) {
            $this->{archivist}->db_delete( $this->getID($i) );
        }
    }
    $this->{size} = $count;
    $this->{archivist}->db_set( 'S'.$this->{id}, $count );
}

sub EXISTS {
    my ( $this, $index ) = @_;
    return 0 if $index < 0 || $index >= $this->FETCHSIZE();

    # Not strictly correct; should return true only if the cell has
    # been explicitly set. Unassigned pattern, maybe?
    return 1;
}

sub DELETE {
    my ( $this, $index ) = @_;
    $this->STORE( $index, '' );
}

sub equals {
    my ( $this, $that ) = @_;
    return 0 unless ref($that) eq ref($this);
    return $that->{id} eq $this->{id};
}

sub getValues {
    my $this = shift;
    my $n    = $this->FETCHSIZE();
    my @values;
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        push( @values, $this->FETCH($i) );
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
