# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::DBCacheContrib::Archivist

This is an abstract base class defining the interface to a DBCacheContrib
archivist. An archivist handles the mechanics of storage of data on disc.
It serves up maps and arrays that obey the
Foswiki::Contrib::DBCacheContrib::Array and
Foswiki::Contrib::DBCacheContrib::Map interfaces.

NOTE: this is a pure virtual base class, and cannot be instantiated on its own.

=cut

package Foswiki::Contrib::DBCacheContrib::Archivist;

use strict;
use Assert;

=begin TML

---++ ObjectMethod newArray() -> $array

Construct a new Foswiki::Contrib::DBCacheContrib::Map in the DB. See
the documentation of Foswiki::Contrib::DBCacheContrib::Map for information
on how to tie this to a perl hash.

=cut

sub newMap {
    ASSERT("Pure virtual method not implemented");
}

=begin TML

---++ ObjectMethod newArray() -> $array

Construct a new Foswiki::Contrib::DBCacheContrib::Array in the DB. See
the documentation of Foswiki::Contrib::DBCacheContrib::Array for information
on how to tie this to a perl array.

=cut

sub newArray {
    ASSERT("Pure virtual method not implemented");
}

=begin TML

---++ ObjectMethod sync()

Sync data changes to disc. Some archivist implementations may cache
data changes in memory. A call to this method ensures that the DB on
disc is synchronised with that memory representation.

-cut

sub sync {
    ASSERT("Pure virtual method not implemented");
}

=begin TML

---++ ObjectMethod getRoot() -> $map

Return the DB root map. The root of the DB is always of type
Foswiki::Contrib::DBCacheContrib::Map, under which you can create keys
that point to maps or arrays.

=cut

sub getRoot {
    ASSERT("Pure virtual method not implemented");
}

=begin TML

---++ ObjectMethod clear()

Completely clear down the DB; removes all data and creates a new root.
Intended primarily for use in testing.

=cut

sub clear {
    ASSERT("Pure virtual method not implemented");
}

1;
__END__

Copyright (C) Crawford Currie, http://c-dot.co.uk and Foswiki Contributors.
Foswiki Contributors are listed in the AUTHORS file in the root of this
distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
