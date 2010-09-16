$(function() {
	    $(".column").sortable({
			connectWith: '.column'
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
             },
             success: function (json) {                    
					for(var i; i< json.length;i++){
						var project = $('<div>');
						project.addClass('activeProject');
						project.html("<div class='activeProjectName'><span>" + json[i].name + "</span></div><div class='activeProjectDescription'><span>" + json[i].description + "</span></div><div class='activeProjectStartDate'><span>" + json[i].startDate + "</span></div><div class='activeProjectManager'>" + json[i].manager + "</span></div>" );
					}	
             },
             error: function (e) {
                    alert('dano');
             }					
		});
});
