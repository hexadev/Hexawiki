# Base class of collection types
package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection;

use strict;
use Assert;

sub getID {
    my ( $this, $k ) = @_;
    return $this->{id} unless defined $k;
    return $this->{id}."\0$k";
}

sub FETCH {
    my ( $this, $key ) = @_;
    return $this->{archivist}->decode(
        $this->{archivist}->db_get( $this->getID($key) ));
}

sub DESTROY {
    my $this = shift;
    $this->{archivist} = undef;
}

sub set {
    return shift->STORE(@_);
}

1;
