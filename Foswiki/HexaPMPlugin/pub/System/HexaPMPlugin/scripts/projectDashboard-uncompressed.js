$(function () {
	foswiki.projectObject = [];
	foswiki.milestones = [];
	foswiki.milestonesUID = [];
	foswiki.todolists = [];
	foswiki.todolistsUID = [];
	foswiki.activities = [];
	foswiki.activitiesUID = [];
	loadOverview(foswiki.web);
});
function loadOverview(web){
	$.ajax({
    	async: true,
        cache: false,
        url: foswiki.scriptUrl + foswiki.scriptSuffix + "/rest/HexaPMPlugin/objects",
        type: 'get',
        dataType: "json",
        data: {
			asobject: 'on',
			web: web	
        },
        success: function (json) {
			foswiki.projectObject = json;        	
			var overviewTable = $('<table>');
           	overviewTable.addClass('objectOverview');
           	overviewTable.attr('width', '100%');
            for(var i = 0; i< json.length;i++){
                var objectType = checkJsonKeys(json[i], 'type');
                var objectCreated = checkJsonKeys(json[i], 'created');
                var objectCreator = checkJsonKeys(json[i], 'creator');
                var objectUid = checkJsonKeys(json[i], 'uid');
                var objectText = checkJsonKeys(json[i], 'text');
                var objectName = checkJsonKeys(json[i], 'name');
                var objectState = checkJsonKeys(json[i], 'state');
				var objectStatus = 'New by ' + objectCreator;  
				if(checkJsonKeys(json[i], 'edited') != 'not defined'){
					objectStatus = 'updated by ' + json[i].edited.split('=')[1] + ' <span class="objectEditedDate">' + json[i].edited.split('=')[0] + '</span>' ;
				}else{
					json[i].edited = "not-defined=notdefiend";
				}
				if (objectType == 'milestone'){
					if (objectState == 'open'){
                		overviewTable.append("<tr><td class='what'><span class='objectType milestoneType'>Milestone</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}else{
						objectStatus = 'closed by ' + json[i].edited.split('=')[1] + ' <span class="objectEditedDate">' + json[i].edited.split('=')[0] + '</span>' ;
                		overviewTable.append("<tr><td class='what'><span class='objectType milestoneType objectClose'>Milestone</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}
					if(foswiki.milestones.length <= 0){
						foswiki.milestonesUID[0] = objectUid;
						foswiki.milestones[0] = json[i];
					}else{
						foswiki.milestonesUID[foswiki.milestones.length] = objectUid;
						foswiki.milestones[foswiki.milestones.length] = json[i];
					}
				}
				if (objectType == 'todolist'){
					if (objectState == 'open'){
                		overviewTable.append("<tr><td class='what'><span class='objectType todolistType objectClose'>todolist</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}else{
						objectStatus = 'closed by ' + json[i].edited.split('=')[1] + ' <span class="objectEditedDate">' + json[i].edited.split('=')[0] + '</span>' ;
                		overviewTable.append("<tr><td class='what'><span class='objectType todolistType objectClose'>todolist</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}
					if(foswiki.todolists.length <= 0){
						foswiki.todolistsUID[0] = objectUid;
						foswiki.todolists[0] = json[i];
					}else{
						foswiki.todolistsUID[foswiki.todolists.length] = objectUid;
						foswiki.todolists[foswiki.todolists.length] = json[i];
					}
				}
				if (objectType == 'activity'){
					var todosTable = $('<table>');
					if (objectState == 'open'){
                		overviewTable.append("<tr><td class='what'><span class='objectType activityType objectClose'>To-Do</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}else{
						objectStatus = 'closed by ' + json[i].edited.split('=')[1] + ' <span class="objectEditedDate">' + json[i].edited.split('=')[0] + '</span>' ;
                		overviewTable.append("<tr><td class='what'><span class='objectType activityType objectClose'>To-Do</span></td><td class='item'><span class='objectItem'>" + objectName + "</span></td><td class='status'><span>" + objectStatus + "</span></td></tr>");
					}
					if(foswiki.activities.length <= 0){
						foswiki.activitiesUID[0] = objectUid;
						foswiki.activities[0] = json[i];
					}else{
						foswiki.activitiesUID[foswiki.activities.length] = objectUid;
						foswiki.activities[foswiki.activities.length] = json[i];
					}
				}
            }
            $('#projectOverview').html(overviewTable);		
			loadMilestones();
			loadTodoLists();
			loadActivities();
        },
        error: function (e) {
        	$('#projectOverview').html('An error occurred during loading projects');
        }	
	});				
}
function loadMilestones (){
	var json = foswiki.milestones;
	for (var i = 0; i < json.length;i++){
        var objectType = checkJsonKeys(json[i], 'type');
        var objectCreated = checkJsonKeys(json[i], 'created');
        var objectCreator = checkJsonKeys(json[i], 'creator');
        var objectUid = checkJsonKeys(json[i], 'uid');
        var objectText = checkJsonKeys(json[i], 'text');
        var objectName = checkJsonKeys(json[i], 'name');
        var objectState = checkJsonKeys(json[i], 'state');
		var objectStatus = 'New by ' + objectCreator;  
		var milestoneDiv = $('<div>');
		milestoneDiv.attr('id', objectUid);
		milestoneDiv.addClass('milestone');
		milestoneDiv.addClass(objectUid);
		if (objectState == 'open'){
			milestoneDiv.addClass('milestoneOpen');
			milestoneDiv.append("<div class='milestoneName'>" + objectName + "</div><div class='milestoneTodolist'><table id='table" + objectUid +"'></table></div>");
			$('#projectMilestones').append(milestoneDiv);
		}else{
			milestoneDiv.addClass('milestoneclose');
			milestoneDiv.append("<div class='milestoneName'>" + objectName + "</div><div class='milestoneTodolistClose'><table id='table" + objectUid +"'></table></div>");
			$('#projectMilestonesClose').append(milestoneDiv);
		}
	}
}
function loadTodoLists (){
	var json = foswiki.todolists;
	for (var i = 0; i < json.length;i++){
        var objectType = checkJsonKeys(json[i], 'type');
        var objectCreated = checkJsonKeys(json[i], 'created');
        var objectCreator = checkJsonKeys(json[i], 'creator');
        var objectUid = checkJsonKeys(json[i], 'uid');
        var objectText = checkJsonKeys(json[i], 'text');
        var objectName = checkJsonKeys(json[i], 'name');
        var objectState = checkJsonKeys(json[i], 'state');
        var objectMilestone = checkJsonKeys(json[i], 'milestone');
		var objectStatus = 'New by ' + objectCreator;  
		var todolistDiv = $('<div>');
		todolistDiv.attr('id', objectUid);
		todolistDiv.addClass('todolist');
		todolistDiv.addClass(objectUid);
        if (objectState == 'open'){	
			todolistDiv.addClass('todolistOpen');
			todolistDiv.append("<div class='todolistName'>" + objectName + "</div><div class='todolistActivities'><table id='table" + objectUid +"'></table></div>");
			$('#projectTodos').append(todolistDiv);
		}else{
			todolistDiv.addClass('todolistClose');
			todolistDiv.append("<div class='todolistName'>" + objectName + "</div><div class='todolistActivities'><table id='table" + objectUid +"'></table></div>");
			$('#projectTodosClose').append(todolistDiv);
		}
		for(var j = 0; j < foswiki.milestonesUID.length; j++){
			if(foswiki.milestonesUID[j] == objectMilestone){
				$('#table' + objectMilestone).append("<tr><td><span class='milestoneTodolist'>" + objectName + "</span></td></tr>");
			}
		}
	}
}
function loadActivities (){	
	var json = foswiki.activities;
	for (var i = 0; i < json.length;i++){
        var objectType = checkJsonKeys(json[i], 'type');
        var objectCreated = checkJsonKeys(json[i], 'created');
        var objectCreator = checkJsonKeys(json[i], 'creator');
        var objectUid = checkJsonKeys(json[i], 'uid');
        var objectText = checkJsonKeys(json[i], 'text');
        var objectName = checkJsonKeys(json[i], 'name');
        var objectState = checkJsonKeys(json[i], 'state');
        var objectTodolist = checkJsonKeys(json[i], 'todolist');
		var objectStatus = 'New by ' + objectCreator; 
	    var activityDiv = $('<div>');	
		activityDiv.addClass(objectUid);
		for(var j = 0; j < foswiki.todolistsUID.length; j++){
			if(foswiki.todolistsUID[j] == objectTodolist){
        		if (objectState == 'open'){	
					activityDiv.addClass('open');
					activityDiv.html("<input type='checkbox' id='" + objectUid + " class='activity open'/>" + objectName);
					$('#table' + objectTodolist).append(activityDiv);
				}else{
					activityDiv.addClass('close');
					activityDiv.html("<input type='checkbox' id='" + objectUid + " class='activity close' CHECKED/>" + objectName);
					$('#table' + objectTodolist).append(activityDiv);
				}
			}
		}
	}
}
function checkJsonKeys(obj, key) {
  if (obj[key] == null){
    return 'not defined';
  }
  obj = obj[key];
  return obj;
}
