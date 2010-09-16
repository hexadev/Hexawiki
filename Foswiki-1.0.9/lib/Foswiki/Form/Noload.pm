# See bottom of file for license and copyright details
# base class for all form field types

package Foswiki::Form::Noload;
use base 'Foswiki::Form::FieldDefinition';
# our @ISA = qw(Foswiki::Form::FieldDefinition);

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );
    return $this;
}

sub renderHidden {
    return '';
}

sub populateMetaFromQueryData {
    return (1, 0);
}

sub renderForDisplay {
    return '';
}

sub renderForEdit {
    return ('noload','');
}

1;
__DATA__

Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Copyright (C) 2010 David Patterson. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

