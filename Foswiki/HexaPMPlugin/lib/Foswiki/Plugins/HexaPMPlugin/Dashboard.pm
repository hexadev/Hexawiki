package Foswiki::Plugins::HexaPMPlugin::Dashboard;

use Foswiki::Plugins::ZonePlugin;
use Assert;

our $DEBUG;


sub renderDashboard {
	require Foswiki::Plugins::HexaPMPlugin::Core;
	$DEBUG = $Foswiki::cfg{Plugins}{HexaPMPlugin}{DEBUG};
	my $pack = $DEBUG ? '.uncompressed' : '.compressed';
    Foswiki::Func::addToZone('head','HEXAPMPLUGIN_CSS', <<HERE);
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/HexaPMPlugin/css/dashboard$pack.css" type="text/css" media="all" />
HERE
   	Foswiki::Func::addToZone('body','HEXAPMPLUGIN_JS', <<HERE, 'JQUERYPLUGIN::FOSWIKI,JQUERYPLUGIN::UI');
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/ui/ui.core.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/ui/ui.sortable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/HexaPMPlugin/scripts/dashboard$pack.js"></script>
HERE
	my $dashboardHTML = <<HERE;
	<div class="portlets" id="hexapm-dashboard">
<div class="column">
	<div class="portlet">
		<div class="portlet-header"><h3>%MAKETEXT{"Projects"}%</h3></div>
		<div class="portlet-content" id="hexapm-projects">
                </div>
	</div>
</div>
<div class="column">
	<div class="portlet">
		<div class="portlet-header"><h3>%MAKETEXT{"Next Milestones"}%</h3></div>
		<div class="portlet-content" id="hexapm-milestones"></div>
	</div>
</div>
<div class="column">
	<div class="portlet">
		<div class="portlet-header"><h3>%MAKETEXT{"Lates changes"}%</h3></div>
		<div class="portlet-content" id="hexapm-lateschanges"></div>
	</div>
</div>
</div><!-- div dashboard -->
HERE
	return $dashboardHTML;
}

1;

