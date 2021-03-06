# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::EXTEND

Specialised UI used by =configure= to generate the extension installation
screen (and to actually perform the installation). Does not use the
conventional renderHtml interface, instead implementing a special
'install' method.

=cut

package Foswiki::Configure::UIs::EXTEND;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');
use Foswiki::Configure::Util ();

use File::Copy ();
use File::Spec ();
use Cwd        ();

=begin TML

---++ ObjectMethod install() -> $html

(Un)Install the extensions selected by the URL parameters.

This method uses *print* rather than gathering output. This is to give
the caller early feedback.

=cut

sub install {
    my $this  = shift;
    my $query = $Foswiki::query;

    $this->findRepositories();

    my @remove = $query->param('remove');
    foreach my $extension (@remove) {
        $extension =~ /(.*)\/(\w+)$/;
        my $repositoryPath = $1;
        my $extensionName  = $2;
        print "Bad extension name" unless $extensionName && $repositoryPath;

        $this->_uninstall( $repositoryPath, $extensionName );
    }

    my @add = $query->param('add');
    foreach my $extension (@add) {
        $extension =~ /(.*)\/(\w+)$/;
        my $repositoryPath = $1;
        my $extensionName  = $2;
        print "Bad extension name" unless $extensionName && $repositoryPath;

        $this->_install( $repositoryPath, $extensionName );
    }
    return '';
}

sub _install {
    my ( $this, $repositoryPath, $extension ) = @_;
    my $err;

    my $feedback = '';

    my $repository = $this->getRepository($repositoryPath);
    if ( !$repository ) {
        $feedback .= $this->ERROR(
            "Repository not found. <pre> " . $repository . "</pre>" );
        _printFeedback($feedback);
        return;
    }

    unless ( eval { require Foswiki } ) {
        die "Can't load Foswiki: $@";
    }

    # Load up a new Foswiki session so that the install can checkin
    # topics and attchments that are under revision control.
    my $user    = $Foswiki::cfg{AdminUserLogin};

    # Temporarily override the password and mapping manager
    # So configure can still work if LDAP or other extensions are not functional
    $Foswiki::cfg{PasswordManager} = 'none';
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';

    my $session = new Foswiki($user);
    require Foswiki::Configure::Package;

    my $pkg =
      new Foswiki::Configure::Package( $this->{root}, $extension, $session );
    $pkg->repository($repository);
    my ( $rslt, $plugins, $depCPAN ) = $pkg->fullInstall();
    $err = $pkg->errors();

    _printFeedback($rslt);

    $pkg->finish();
    undef $pkg;
    $session->finish();
    undef $session;

    if ($err) {
        $feedback .= $this->ERROR(
"Errors encountered during package installation.  The Extension may not be usable. <pre>$err</pre>"
        );
        $feedback .= "Installation terminated";
        _printFeedback($feedback);
        return 0;
    }

    if ( $this->{warnings} ) {
        $feedback .=
          $this->NOTE( "Installation finished with $this->{errors} error"
              . ( $this->{errors} == 1 ? '' : 's' )
              . " and $this->{warnings} warning"
              . ( $this->{warnings} == 1 ? '' : 's' ) );
    }
    else {

        # OK
        $feedback .= $this->NOTE_OK(
            "Installation of $extension and dependencies finished");
        $feedback .= $this->NOTE(<<HERE);
Before proceeding, review the dependency reports of each installed
extension and resolve any dependencies as required.  <ul><li>External
dependencies are never automatically resolved by Foswiki. <li>Dependencies
noted as "Optional" will not be automatically resolved, and <li>CPAN
dependencies are not resolved by the web installer.
HERE
    }

    if ( keys %$depCPAN ) {
        $feedback .= $this->NOTE(<<HERE);
Warning:  CPAN dependencies were detected, but will not be automatically
installed by the Web installer.  The following dependencies should be
manually resolved as required. 
HERE
        $feedback .= "<pre>";
        foreach my $dep ( sort { lc($a) cmp lc($b) } keys %$depCPAN ) {
            $feedback .= "$dep\n";
        }
        $feedback .= "</pre>";
    }

    if ( keys(%$plugins) ) {
        $feedback .= $this->NOTE(<<HERE);
Note: Before you can use newly installed plugins, you must enable them in the
"Plugins" section in the main page.
HERE
        $feedback .= "<pre>";
        foreach my $plu ( sort { lc($a) cmp lc($b) } keys %$plugins ) {
            $feedback .= "$plu \n";
        }
        $feedback .= "</pre>";
    }
    _printFeedback($feedback);
}

sub _printFeedback {
    my ($feedback) = @_;

    print "<div class='configureMessageBox foswikiAlert'>$feedback</div>";
}

sub _uninstall {
    my ( $this, $repositoryPath, $extension ) = @_;

    my $feedback = '';
    $feedback .= "<h3 style='margin-top:0'>Uninstalling $extension</h3>";

    my @removed;
    my $rslt;
    my $err;

    require Foswiki::Configure::Package;
    my $pkg = new Foswiki::Configure::Package( $this->{root}, $extension );

    # For uninstall, set repository in case local installer is not found
    # it can be downloaded to recover the manifest
    my $repository = $this->getRepository($repositoryPath);
    if ( !$repository ) {
        $rslt .=
            "Repository not found. "
          . $repository
          . " - Local installer must exist)\n";
    }
    else {
        $pkg->repository($repository);
    }

    # And allow the package to use / prefer the local _installer file if found
    ( $rslt, $err ) = $pkg->loadInstaller( { USELOCAL => 1 } );

    if ($rslt) {
        $feedback .= "Loading installer for manifest <br />\n";
        $feedback .= "<pre>$rslt </pre>";
    }

    unless ($err) {
        my $rslt = $pkg->createBackup();
        $feedback .= "Creating Backup: <br />\n<pre>$rslt</pre>" if $rslt;

        $pkg->loadExits();

        if ( defined $pkg->preuninstall ) {
            $feedback .= "Running Pre-uninstall...<br />\n";
            $rslt = $pkg->preuninstall() || '';
            $feedback .= '<pre>' . $rslt . '</pre>';
        }

        @removed = $pkg->uninstall();

        if ( defined $pkg->postuninstall ) {
            $feedback .= "Running Post-uninstall...<br />\n";
            $rslt = $pkg->postuninstall() || '';
            $feedback .= '<pre>' . $rslt . '</pre>';
        }
    }

    $pkg->finish();
    undef $pkg;

    if ($err) {
        $feedback .=
          $this->WARN("Error $err encountered - uninstall not completed");
        _printFeedback($feedback);
        return;
    }

    unless ( scalar @removed ) {
        $feedback .= $this->WARN(" Nothing removed for $extension");
        _printFeedback($feedback);
        return;
    }

    my @plugins;
    my $unpackedFeedback = '';
    foreach my $file (@removed) {
        $unpackedFeedback .= "$file\n";
        my ($plugName) = $file =~ m/.*\/Plugins\/([^\/]+Plugin)\.pm$/;
        push( @plugins, $plugName ) if $plugName;
    }
    $feedback .= "Removed files:<br />\n<pre>$unpackedFeedback</pre>"
      if $unpackedFeedback;

    if ( scalar @plugins ) {
        $feedback .= $this->WARN(<<HERE);
Note: Don't forget to disable uninstalled plugins in the
"Plugins" section in the main page, listed below:
HERE
        $feedback .= "<pre>";
        foreach my $plugName (@plugins) {
            $feedback .= "$plugName \n" if $plugName;
        }
        $feedback .= "</pre>";
    }
    _printFeedback($feedback);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
