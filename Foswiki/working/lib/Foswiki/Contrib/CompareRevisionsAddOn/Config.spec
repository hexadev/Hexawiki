# ---+ Extensions
# ---++ CompareRevisionsAddOn
# **PERL H**
# This setting is required to enable executing the compare script from the bin directory
$Foswiki::cfg{SwitchBoard}{compare} = {
    package  => 'Foswiki::Contrib::CompareRevisionsAddOn::Compare',
    function => 'compare',
    context  => { diff => 1,
                  comparing => 1
                },
    };
1;
