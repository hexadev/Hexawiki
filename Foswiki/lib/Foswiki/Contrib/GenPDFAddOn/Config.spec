# ---+ Extensions
# ---++ GenPDFAddOn
# **PATH**
# htmldoc executable including complete path.
$Foswiki::cfg{Extensions}{GenPDFAddOn}{htmldocCmd} = '';
# **PERL H**
# This setting is required to enable executing genpdf script from the bin directory
$Foswiki::cfg{SwitchBoard}{genpdf} = {
    package  => 'Foswiki::Contrib::GenPDFAddOn',
    function => 'viewPDF',
    context  => { view => 1,
                  static => 1
                },
    };

1;
