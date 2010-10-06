jQuery(function(){
    $('#op-weblist').change(function(){
        foswiki.HijaxPlugin.serverAction({
			type: "GET",
			async: true,
			url: foswiki.scriptUrl+'/rest/RenderPlugin/tag', 
			data: {
				name: 'INCLUDE',
				param: foswiki.systemWebName+'/ObjectModules',
				section: 'topiclist',
				web: $(this).val(),
				render: 1
			}, 
			dataType: "html",
			loading: '#explorer',
			success: function(html) {
				$('#explorer').html(html)
   //                                             .treeview({collapsed:true,control:'#treecontrol'})
					.find('a.droponme').droppable({
						greedy: true,
						tolerance: 'pointer',
						accept: 'div.object-container',
						drop: function(event, ui) { 
							var $object = ui.draggable;
							var $controls = $object.find('.object-controls:first');
							foswiki.HijaxPlugin.serverAction({
								url: foswiki.scriptUrl+'/rest/ObjectPlugin/move',
								type: 'GET',
								$object: $object,
								success: function() {
									this.$object.remove();
								},
								data: {
									uid: $object.attr('id'),
									topic: $controls.attr('web')+'.'+$controls.attr('topic'),
									target: $(this).attr('target'),
									asobject: 1
								}
							});
						}
					});

			}
		});
    });
});
