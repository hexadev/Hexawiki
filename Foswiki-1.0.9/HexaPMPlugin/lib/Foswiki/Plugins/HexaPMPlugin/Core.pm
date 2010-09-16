package Foswiki::Plugins::HexaPMPlugin::Core;

use strict;
use CGI (':all');
use JSON;
use strict;
use Error qw( :try );
require Foswiki::OopsException;
require Foswiki::AccessControlException;


sub checkAccessControll {
    my $user = $_[0];
    my $action = $_[1] || 'view';
    my $resource = $_[2] || 'all';
    my $authorization = 0;
    Foswiki::Func::writeWarning("$user - $action - $resource");
    my $allowusers = '';
    if ($resource eq 'dashboard'){
    	$allowusers = $Foswiki::cfg{Plugins}{HexaPMPlugin}{AllowViewDashboard} || $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} ||$Foswiki::cfg{SuperAdminGroup};
    	Foswiki::Func::writeWarning("$allowusers");
    }elsif ($resource eq 'projects') {
    	$allowusers = $Foswiki::cfg{Plugins}{HexaPMPlugin}{AllowViewDashboard} || $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} || $Foswiki::cfg{SuperAdminGroup};
    }elsif ($resource eq 'project') {
	return 1;
    }else{
	return 0;	
    }
    if ($allowusers) {
        my @userorgroup = split(',', $allowusers);
        foreach my $val (@userorgroup) {
            if ($val =~ /.*Group$/)
            {
                if(Foswiki::Func::isGroupMember( $val, $user )){
                    $authorization = 1;
                }
            }else{
                if( $user eq $val || Foswiki::Func::wikiToUserName($user) eq Foswiki::Func::wikiToUserName($val) || Foswiki::Func::userToWikiName($user) eq Foswiki::Func::userToWikiName($val)){
                    $authorization = 1;
                }
            }
        }
    }
    if ($authorization){
        return 1;
    }else{
        return 0;
    }
}
sub createProject {
	my $name = $_[0] || '';
	my $description = $_[1] || '';
	my $startDate = $_[2] || '';
	my $projectManager = $_[3] || '';
	my $session = $_[4];
	my $createdBy = Foswiki::Func::getCanonicalUserID();
	my $isequal;
	my $webname;
	my $PMwebname = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectsWeb} || '';
	if(Foswiki::Func::getWikiName($createdBy) eq $projectManager || Foswiki::Func::getWikiUserName($createdBy) eq $projectManager || Foswiki::Func::getWikiUserName($createdBy) eq 'Main' . $projectManager){
		$isequal = 1;
	}else{
		$isequal = 0;
	}
	my $PMgroup = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} || $Foswiki::cfg{SuperAdminGroup}; 
	my $projectAccessControl = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} || $Foswiki::cfg{SuperAdminGroup};
	if ($isequal == 1 && Foswiki::Func::getWikiName($createdBy) eq Foswiki::Func::getWikiName($projectManager)){
		$projectAccessControl = $projectAccessControl . ',' . $projectManager;
	}
	my $webPreferences = {
			DENYWEBVIEW => $Foswiki::cfg{DefaultUserWikiName}, 
			DENYWEBCHANGE => $Foswiki::cfg{DefaultUserWikiName}, 
			DENYWEBRENAME => $Foswiki::cfg{DefaultUserWikiName}, 
			ALLOWWEBVIEW =>  $projectAccessControl,
			ALLOWWEBCHANGE => $projectAccessControl,
			ALLOWWEBRENAME => $projectAccessControl,
			ALLOWTOPICCHANGE => $projectAccessControl,
			ALLOWTOPICRENAME => $Foswiki::cfg{SuperAdminGroup},
			SITEMAPUSETO => $description,
	};
	try {
		$webname = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectNamePrefix} || 'Project';
		$webname = $PMwebname . '/' .$webname . $name;
    	Foswiki::Func::createWeb($webname, '_Project', $webPreferences);
		setProjectForm($name, $description, $startDate, $projectManager,$webname,$session);
		return "{\"status\": \"ok\"}";
	} catch Error::Simple with {
    	my $e = shift;
        my $mess = $e->stringify();
        return "{\"status\": \"error\", \"error\": \"$mess\", \"number\": \"000\"}";
    } catch Foswiki::AccessControlException with {
        my $e = shift;
        return "{\"status\": \"error\", \"error\": \"You don't have permision to create projects, to be able to create project you must be part of the $PMgroup, and the $PMgroup must have change permissions in the Project Web.\", \"number\": \"998\"}";
   	} otherwise {
        return '{"status": "error", "error": "Error creating the project", "number": "999"}';
    };
}
sub setProjectForm {
    my $name = $_[0] || '';
    my $description = $_[1] || '';
    my $startDate = $_[2] || '';
    my $projectManager = $_[3] || '';
    my $state = 'Inprocess';
	my $webname = $_[4];
	my $session = $_[5];
	my ($meta, $text) = Foswiki::Func::readTopic($webname, 'WebHome');
	my $projectFormWebTopic = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectFormTopic} || 'System.HexaPMPluginProjectForm';
	Foswiki::Func::writeDebug($projectFormWebTopic);	
	my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName( '', $projectFormWebTopic);
	Foswiki::Func::writeDebug($formWeb . " - " . $formTopic);
	if(Foswiki::Func::topicExists($formWeb, $formTopic)){
		my $formDefinition = new Foswiki::Form($session, $formWeb, $formTopic);
		unless ($formDefinition){
			die "Error: there are no DataForm definition in the $projectFormWebTopic topic, read System.DataForms";
		}
		my $formFields = $formDefinition->{fields};
		$meta->put('FORM', { name => $formWeb . '.' . $formTopic});
		my $defaultvalue = '';
    	foreach my $field (@{$formFields}){
            Foswiki::Func::writeWarning($field->{name});
			if ($field->{name} eq 'Description'){
            	$meta->putKeyed( 'FIELD', { name => 'Description', title => 'Description', value => $description});
			}elsif ($field->{name} eq 'Name'){
            	$meta->putKeyed( 'FIELD', { name => 'Name', title => 'Name', value => $name});
			}elsif ($field->{name} eq 'StartDate'){
            	$meta->putKeyed( 'FIELD', { name => 'StartDate', title => 'Startdate', value => $startDate});			
			}elsif ($field->{name} eq 'ProjectManager'){
            	$meta->putKeyed( 'FIELD', { name => 'ProjectManager', title => 'ProjectManager', value => $projectManager});
			}elsif ($field->{name} eq 'State'){
				my @stateValues = split(',',$field->{value} );
            	$meta->putKeyed( 'FIELD', { name => 'State', title => 'State', value => $stateValues[0]});	
			}			
    	}
		unless (scalar($meta->find('FIELD'))){	
			die "Error: there are no DataForm definition in the $projectFormWebTopic topic, read System.DataForms";
		}
    	Foswiki::Func::saveTopic( $webname, 'WebHome', $meta, $text, { forcenewrevision => 1 } );
	}else{
		Foswiki::Func::writeWarning("The topic $projectFormWebTopic does't exits, plaese check that the topic exist. Be default this plugin used System.System.HexaPMPluginProjectForm so clear the {Plugins}{HexaPMPlugin}{ProjectFormTopic} to used it");
		die "Error: the formtopic $projectFormWebTopic does't exits.";
	}
}
sub getProjectList {
	my $format = $_[0] || 'json';
	my $projectsWeb = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectsWeb} || '';
	my $projectsNamePrefix = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectNamePrefix} || 'Project';
	my $projectsForm = $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectFormTopic} || 'System.HexaPMPluginProjectForm';
	my @projectsName;
	my @subWebs;
	my $name;
	my $description;
	my $state;
	my $startdate;
	my $manager;
	if (Foswiki::Func::webExists($projectsWeb)){
		@subWebs = Foswiki::Func::getListOfWebs( "user,public", $projectsWeb);
	}else{
		Foswiki::Func::writeWarning('The {Plugins}{HexaPMPlugin}{ProjectsWeb} is not set in the configure. The action getProjects was aborted.');
		#return 0;
	}
	foreach my $item (@subWebs){
		my $projectname = '';
		Foswiki::Func::writeDebug('Prefix: ' . $projectsNamePrefix);
		my ($meta, $text) = Foswiki::Func::readTopic($item , 'WebHome');
		my $projectForm = $meta->get('FORM');
		Foswiki::Func::writeDebug('entro ' . $projectForm->{name});
		my ($webHomeFormWeb, $webHomeFormTopic) = Foswiki::Func::normalizeWebTopicName('', $projectForm->{name});
		my ($projectFormWeb, $projectFormTopic) = Foswiki::Func::normalizeWebTopicName('', $projectsForm);
		if($webHomeFormTopic eq $projectFormTopic && $webHomeFormWeb eq $projectFormWeb){
			Foswiki::Func::writeDebug('entro - crear item' . $meta->get('FIELD', 'Name')->{value});
			my @fields = $meta->find('FIELD');
    		#while ( my ($key, $value) = each(%campos))  {
			#Foswiki::Func::writeDebug($key . ' - ' . $value );
			my %projectValues = ();
			$projectValues{'home'} = $item . '.WebHome';
			foreach my $projectField (@fields){
				$projectValues{$projectField->{'name'}} = $projectField->{'value'};
			}
			push(@projectsName, \%projectValues); 
		}
	}
	if ($format eq 'json'){
		my $projectsJson = new JSON;
		return $projectsJson->encode(\@projectsName);
	}
}

1;
