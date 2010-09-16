# ---+ Extensions
# ---++ AutoTemplate settings
# This is the configuration used by the <b>AutoTemplatePlugin</b>.

# **BOOLEAN**
# Turn on/off debugging in debug.txt
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Debug} = 0;

# **BOOLEAN**
# Template defined by form overrides existing VIEW_TEMPLATE or EDIT_TEMPLATE settings
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Override} = 0;

# **STRING**
# Comma separated list of modes defining how to find the view or edit template. 
# The following modes can be combined:
# <ul>
# <li> 'exist': the template name is derived from the name of the form definition topic. </li>
# <li> 'section': the template name is defined in a section in the form definition topic. </li>
# <li> 'rules': the template name is defined using the below rule sets in <code>ViewTemplateRules</code>
#      and <code>EditTemplateRules</code> </li>
# </ul>
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Mode} = 'rules, exist';

# **PERL**
# Rule set used to derive the view template name. This is a list of rules of the form
# <code>'pattern' => 'template'</code>. The current topic is matched against each of the
# patterns in the given order. The first matching pattern determines the concrete view template.
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{ViewTemplateRules} = {
  'UserRegistration' => 'UserRegistrationView',
  'WebAtom' => 'WebAtomView',
  'WebChanges' => 'WebChangesView',
  'WebCreateNewTopic' => 'WebCreateNewTopicView',
  'WebRss' => 'WebRssView',
  'WebSearchAdvanced' => 'WebSearchAdvancedView',
  'WebSearch' => 'WebSearchView',
  'WebTopicList' => 'WebTopicListView',
  'WikiGroups' => 'WikiGroupsView',
  'WikiUsers' => 'WikiUsersView',
};

# **PERL**
# Rule set used to derive the edit template name. The format is the same as for the <code>{ViewTempalteRules}</code>
# configuration. This rule set is used during edit.
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{EditTemplateRules} = {
};
