$(function() {
	    $(".column").sortable({
			connectWith: '.column',
			handle: '.portlet-header'
		});
		$(".portlet").addClass("ui-widget ui-widget-content ui-helper-clearfix ui-corner-all")
			.find(".portlet-header")
				.addClass("ui-widget-header ui-corner-all")
				.prepend('<span class="ui-icon ui-icon-minusthick"></span>')
				.end()
			.find(".portlet-content");

		$(".portlet-header .ui-icon").click(function() {
			$(this).toggleClass("ui-icon-minusthick").toggleClass("ui-icon-plusthick");
			$(this).parents(".portlet:first").find(".portlet-content").toggle();
		});

		$(".column").disableSelection();

		$.ajax({
             async: true,
             cache: false,
             url: foswiki.scriptUrl + foswiki.scriptSuffix + "/rest/HexaPMPlugin/getProjectList",
             type: 'get',
             dataType: "json", 
             data: {
                    skin: 'text',
					State: '(New|Inprocess|Active)'
             },
             success: function (json) {                    
					if(json.length > 4){
						$('#hexapm-projects').addClass('activeProjectOverflow');
					}	
					for(var i = 0; i< json.length;i++){
						var projectDiv = $('<div>');
						var projectHome = checkJsonKeys(json[i], 'home');
						var projectName = checkJsonKeys(json[i], 'Name');
						var projectDescription = checkJsonKeys(json[i], 'Description');
						var projectStartDate = checkJsonKeys(json[i], 'StartDate');
						var projectManager = checkJsonKeys(json[i], 'ProjectManager');
						projectDiv.addClass('activeProject');
						projectDiv.html("<table class='projectTable'><tr><td valign='top' align='left'><div class='activeProjectName'><span><a href='" + foswiki.scriptUrl + "/view/" + projectHome + "'>" + projectName + "</a></span></div></td></tr><tr><td valign='top' align='left'><span class='activeProjectLabel'>Manager: </span><span class='activeProjectManager'>" + projectManager + " </span><span class='activeProjectLabel'>Start: </span><span class='activeProjectStartDate'>" + projectStartDate + "</span></td></tr><tr><td valign='top' align='left'><div class='activeProjectDescription'><span>" + projectDescription + " <a href='" + foswiki.scriptUrl + "/view/" + projectHome + "'>more</a></span></div></td></tr></table><hr />" );
						$('#hexapm-projects').append(projectDiv);
					}	
             },
             error: function (e) {
                    $('#hexapm-projects').html('An error occurred during loading projects');
             }					
		});
});
function checkJsonKeys(obj, key) {
  if (obj[key] == null){
    return 'not defined';
  }
  obj = obj[key];
  return obj;
}
