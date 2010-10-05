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
	my $resourceType = $_[2] || 'all';
    my $resource = $_[3] || '';
    my $authorization = 0;
    Foswiki::Func::writeWarning("$user - $action - $resource");
    my $allowusers = '';
    if ($resourceType eq 'dashboard'){
    	$allowusers = $Foswiki::cfg{Plugins}{HexaPMPlugin}{AllowViewDashboard} || $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} ||$Foswiki::cfg{SuperAdminGroup};
    	Foswiki::Func::writeWarning("$allowusers");
    }elsif ($resourceType eq 'projects') {
    	$allowusers = $Foswiki::cfg{Plugins}{HexaPMPlugin}{AllowViewDashboard} || $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} || $Foswiki::cfg{SuperAdminGroup};
    }elsif ($resourceType eq 'project'){
		### TODO ###
		#Se debe validar crear un campo que le pueda dar un estado de privadasidad al proyecto para que solo los integrantes tenga el acceso.
		#
		unless ($resource ne '') { return 0;}
		my ($projectWeb, $projectTopic) = Foswiki::Func::normalizeWebTopicName('', $resource);
		if ($action eq 'view'){
    		$allowusers = $Foswiki::cfg{Plugins}{HexaPMPlugin}{AllowViewDashboard} || $Foswiki::cfg{Plugins}{HexaPMPlugin}{ProjectManagementGroup} || $Foswiki::cfg{SuperAdminGroup};
		}
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
	my $query = $_[0] || 'json';
	my $format = $query->param('format') || 'json';
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
		my ($meta, $text) = Foswiki::Func::readTopic($item , 'WebHome');
		my $projectForm = $meta->get('FORM');
		my ($webHomeFormWeb, $webHomeFormTopic) = Foswiki::Func::normalizeWebTopicName('', $projectForm->{name});
		my ($projectFormWeb, $projectFormTopic) = Foswiki::Func::normalizeWebTopicName('', $projectsForm);
		if($webHomeFormTopic eq $projectFormTopic && $webHomeFormWeb eq $projectFormWeb){
			my @fields = $meta->find('FIELD');
			my %projectValues = ();
			$projectValues{'home'} = $item . '.WebHome';
			my $filterResult = 0;
			my $discartResult = 0;
			foreach my $projectField (@fields){
				foreach my $filter ($query->param()){
					if ($filter eq $projectField->{'name'}){
							my $projectFieldValue = $projectField->{'value'} || '';
							my $queryFieldValue = $query->param($filter) || '.*';
							if ($projectFieldValue =~ /$queryFieldValue/){
								$filterResult = 1;
							}else {
								$discartResult = 1;
								last;
							}
					}
					if(length($projectField->{'value'}) > 48){
						$projectValues{$projectField->{'name'}} = substr($projectField->{'value'},0,46) . '...';
					}else{
						$projectValues{$projectField->{'name'}} = $projectField->{'value'};
					}
				}
			}
			if (($filterResult == 1 && $discartResult == 0) || ($filterResult == 0 && $discartResult == 0)){
				push(@projectsName, \%projectValues); 
				$filterResult = 0;
				$discartResult = 0;
			}
		}
	}
	if ($format eq 'json'){
		my $projectsJson = new JSON;
		return $projectsJson->encode(\@projectsName);
	}
}

sub loadObjects {
    my ($web, $topic, $query) = @_;
    my $qweb = $query->param('web') || 'Main';
    my @attr = $query->param();
    my $sort = $query->param('sort') || '';
    $query->delete('_');
    my $qattrs = '';
    foreach my $param (@attr){
        unless ($param eq 'asobject' || $param eq 'sort'){
            $qattrs = $qattrs . "$param=\"" . $query->param($param) . "\" ";
        }
    }
    my $attrs = new Foswiki::Attrs($qattrs);
    my $objects = new Foswiki::Plugins::ObjectPlugin::ObjectSet();
    my $sortObjects = new Foswiki::Plugins::ObjectPlugin::ObjectSet();
    my @topics = ('ProjectMilestones','ProjectActivities','ProjectTodolist');
    foreach my $topic ( @topics ) {
        next unless Foswiki::Func::topicExists( $qweb, $topic );
        my ($meta,$text) = Foswiki::Func::readTopic($qweb, $topic);
        next unless Foswiki::Func::checkAccessPermission(
            'VIEW', Foswiki::Func::getWikiName(), $text, $topic, $qweb, $meta);
        my $tobjs = Foswiki::Plugins::ObjectPlugin::ObjectSet::load(
            $qweb, $topic, $text, undef, 0 );
        $tobjs = $tobjs->search( $attrs );
        $objects->concat( $tobjs );
    }
    Foswiki::Func::writeDebug($objects->{OBJECTS}[0]);
    my @sortobject = sort bywhen @{$objects->{OBJECTS}};
    foreach my $object (@sortobject){
        $sortObjects->add($object);
    }
    return $sortObjects;	
}

sub bywhen {
    Foswiki::Time::parseTime($$b{edited}) <=> Foswiki::Time::parseTime($$a{edited});
}


1;
