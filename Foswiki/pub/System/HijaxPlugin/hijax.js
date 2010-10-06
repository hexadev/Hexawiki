// from Rick Strahl's Web Log, http://www.west-wind.com/weblog/posts/459873.aspx
// corrected to use .offset() instead of .scrollLeft() and .scrollTop() when the container is not the window
jQuery.fn.centerInClient = function(options) {
    /// <summary>Centers the selected items in the browser window. Takes into account scroll position.
    /// Ideally the selected set should only match a single element.
    /// </summary>    
    /// <param name="fn" type="Function">Optional function called when centering is complete. Passed DOM element as parameter</param>    
    /// <param name="forceAbsolute" type="Boolean">if true forces the element to be removed from the document flow 
    ///  and attached to the body element to ensure proper absolute positioning. 
    /// Be aware that this may cause ID hierachy for CSS styles to be affected.
    /// </param>
    /// <returns type="jQuery" />
    var opt = { forceAbsolute: false,
                container: window,    // selector of element to center in
                completeHandler: null,
				minX: 0,
				minY: 0
              };
    $.extend(opt, options);
   
    return this.each(function(i) {
        var el = $(this);
        var jWin = $(opt.container);
        var isWin = opt.container == window;

        // force to the top of document to ENSURE that 
        // document absolute positioning is available
        if (opt.forceAbsolute) {
            if (isWin)
                el.appendTo("body");
            else
                el.appendTo(jWin.get(0));
        }

        // have to make absolute
        el.css("position", "absolute");

        // height is off a bit so fudge it
        var heightFudge = isWin ? 2.0 : 1.8;

        var x = (isWin ? jWin.width() : jWin.outerWidth()) / 2 - el.outerWidth() / 2;
        var y = (isWin ? jWin.height() : jWin.outerHeight()) / heightFudge - el.outerHeight() / 2;

        // el.css("left", x < opt.minX ? opt.minX + jWin.scrollLeft() : x + jWin.scrollLeft());
        // el.css("top", y < opt.minY ? opt.minY + jWin.scrollTop() : y + jWin.scrollTop());
		var pos = isWin ? {left:jWin.scrollLeft(),top:jWin.scrollTop()} : jWin.offset();
        el.css("left", x < opt.minX ? opt.minX + pos.left : x + pos.left);
        el.css("top", y < opt.minY ? opt.minY + pos.top : y + pos.top);

        // if specified make callback and pass element
        if (opt.completeHandler)
            opt.completeHandler(this);
    });
};
// Here is my customisation of the jQuery Supersleight plugin.
// You can see the line I've commented out to allow more a fine grained selection of DOM elements,
// e.g. $('#officetoolbar *,#MenuBar *,.patternContent *').not('.nossleight')
//	.hpsupersleight({shim: '%PUBURL%/%SYSTEMWEB%/DocumentGraphics/empty.gif'});
// ...and I've commented out the if statement checking for IE5.5/6, we wouldn't be here otherwise
jQuery.fn.hpsupersleight = function(settings) {
	settings = jQuery.extend({
		imgs: true,
		backgrounds: true,
		shim: 'x.gif',
		apply_positioning: true
	}, settings);
	
	return this.each(function(){
		// if (jQuery.browser.msie && parseInt(jQuery.browser.version, 10) < 7 && parseInt(jQuery.browser.version, 10) > 4) {
			jQuery(this)
//			.find('*').andSelf()
			  .each(function(i,obj) {
				var self = jQuery(obj);
				// background pngs
				if (settings.backgrounds && self.css('background-image').match(/\.png/i) !== null) {
					var bg = self.css('background-image');
					var src = bg.substring(5,bg.length-2);
					var mode = (self.css('background-repeat') == 'no-repeat' ? 'crop' : 'scale');
					var styles = {
						'filter': "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + src + "', sizingMethod='" + mode + "')",
						'background-image': 'url('+settings.shim+')'
					};
					self.css(styles);
				};
				// image elements
				if (settings.imgs && self.is('img[src$=png]')){
					var styles = {
						'width': self.width() + 'px',
						'height': self.height() + 'px',
						'filter': "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + self.attr('src') + "', sizingMethod='scale')"
					};
					self.css(styles).attr('src', settings.shim);
				};
				// apply position to 'active' elements
				if (settings.apply_positioning && self.is('a, input') && (self.css('position') === '' || self.css('position') == 'static')){
					self.css('position', 'relative');
				};
			});
		// };
	});
}; 
jQuery.fn.foswikiHijax = function(){
	return this.each(function(){
		foswiki.HijaxPlugin.hijax(this);
	});
};
jQuery.fn.sort = Array.prototype.sort;

foswiki.HijaxPlugin = function($){
var blocked = 0;
var validate = 0;
var $spinner, $overlay, $rC, $rcDialog, $oopsC, $oopsDialog;
var $hpmenu, $hpanchor;
var nohijax, $hpssleight;
var appended = [];
var $menuTarget = null,
	menuTimer = null,
	hideTimeout = 750;
var back = [],
	forward = [];
var currentURL;
var dialogButtons = {
	Ok: function() {
		$(this).dialog('close');
		back = [];
		forward = [];
	},
	Launch: function() {
		window.open(currentURL.source);
	},
	Forward: function() {
		var url = forward.pop();
		back.push(currentURL);
		currentURL = null;
		foswiki.HijaxPlugin.serverAction({
			url: url.source,
			type: 'GET',
			data: url.params,
			success: function(json){
				foswiki.HijaxPlugin.showResponse(json);
			}
		});
	},
	Back: function() {
		var url = back.pop();
		forward.push(currentURL);
		currentURL = null;
		foswiki.HijaxPlugin.serverAction({
			url: url.source,
			type: 'GET',
			data: url.params,
			success: function(json){
				foswiki.HijaxPlugin.showResponse(json);
			}
		});
	}
};

function grep(str) {
	var ar = [];
	var arSub = 0;
	for (var i in this) {
		if (typeof this[i] == "string" && this[i].search(str) !== -1) {
			ar[arSub] = this[i];
			arSub++;
		}
	}
	return ar;
}
Array.prototype.grep = grep;

function positionMenu(el){
	var pos = $(el).offset();
	if ($menuTarget) foswiki.HijaxPlugin.hideMenu();
	$menuTarget = $(el).addClass('hasMenu');
	$hpanchor.css({"top": pos.top,"left": pos.left - 20});
	$hpmenu.css({"top": pos.top - 4,"left": pos.left - 24});
	$hpanchor.fadeIn("1000");
	clearTimeout(menuTimer);
}
function appendTo(zone,content){
	// parking: see below, this.innerHTML
	// ##
	// var existing = JSON.stringify($(zone).html());
	var existing = $(zone).html();
	var src, text, href, name;
	$('<div>'+content+'</div>').find('script,style').each(function(){
		if (this.src) {
			src = this.src.replace(foswiki.pubUrl+'/','');
			if (existing.search(src) === -1 &&
					appended.grep(src).length == 0) { // not there
				appended.push(src);
				src = 0;
			} else src = 1;
		} else {
			src = 0;
		}
		// if there's no src there must be innerHTML and vice versa but we'll program for it anyway
		if (this.innerHTML) {
			// parking this because I can't get it to work so no point in stringifying it etc.
			// proceed with the assumption that on-the-page scripts should always be executed when loaded
			// let's see what happens
			// ##
			// text = JSON.stringify(this.innerHTML);
			// console.log(text);
			// if (existing.search(text) === -1 &&
					// appended.grep(text).length == 0) { // not there
				// appended.push(text);
				text = 0;
			// } else text = 1;
		} else {
			text = 0;
		}
		if (!src && !text) $(zone).append(this);
	}).end().find('link').each(function(){
		if (this.href) {
			href = this.href.replace(foswiki.pubUrl+'/','');
			if (existing.search(href) === -1 &&
					appended.grep(href).length == 0) { // not there
				appended.push(href);
				href = 0;
			} else href = 1;
		} else {
			href = 0;
		}
		if (!href) $(zone).append(this);
	}).end().find('meta').each(function(){
		if (this.name) {
			name = this.name;
			if (existing.search(name) === -1 &&
					appended.grep(name).length == 0) { // not there
				appended.push(name);
				name = 0;
			} else name = 1;
		} else {
			name = 0;
		}
		if (!name) $(zone).append(this);
	});
}
function objectifyQuery(str){
	var ret = {},
		seg = str.split(/[;&]/),
		len = seg.length, i = 0, s;
	for (;i<len;i++) {
		if (!seg[i]) { continue; }
		s = seg[i].split('=');
		if (ret[s[0]]) {
			if (typeof ret[s[0]] != 'array') ret[s[0]] = [ret[s[0]]];
			ret[s[0]].push(s[1]);
		} else ret[s[0]] = s[1];
	}
	return ret;
}
function stringifyQuery(query){
	var str = '';
	for (var x in query) {
		if (typeof x == 'array') str += x + '=' + query[x].join(',');
		else str += x + '=' + query[x];
		str += '&';
	}
	str = str.replace(/&$/,'');
	return str;
}
function ajaxError(xhr,s,params){
	switch (xhr.status) {
		case 419:
			validate += 1;
			if (validate > 1) {
				validate = 0;
				alert("There is an error in the HijaxPlugin strikeone support over AJAX. \n"+
					"Please contact your wiki administrator.");
				return;
			}
		default:
			var json;
			try {
				json = JSON.parse(xhr.responseText);
				if (typeof json === 'object' && json.context) {
					foswiki.HijaxPlugin.handleResponse(json,foswiki.HijaxPlugin.serverAction,params);
					// return;
				}
			} catch (e) {
				// console.log(xhr.responseText);
			}
			if (json) return;
			alert("readyState: "+xhr.readyState+"\nstatus: "+xhr.status+"\nbut "+s);
			foswiki.HijaxPlugin.showOops(xhr.responseText);
	}
}

return {
hideMenu : function(){
	$($hpmenu).add($hpanchor).stop(true,true).hide();
	if ($menuTarget) {
		$menuTarget.removeClass('hasMenu');
		$menuTarget = null;
	}
},
hijax : function(el){	
	var $el = $(el);
	if ($el.is('a[href]')) {
		$el.not('.hpmenulink').not(nohijax).hoverIntent(function(){
			if ($el.hasClass('hasMenu')) {
				clearTimeout(menuTimer);
				return;
			}
			var myURL = foswiki.HijaxPlugin.parseURL(el.href);
			if (myURL.hostname != foswiki.HijaxPlugin.pageURL.hostname) return;
			switch (myURL.script) {
				case 'edit':
					if (!myURL.params.nowysiwyg) break;
					// we can't support wysiwyg editing over ajax yet
				case ''||'view':
					if (myURL.query == '') {
						// get the link's position and show the menu
						$hpmenu.find('li').show().end()
							.find('a').each(function(){
								this.href = $(this).attr('url')
									.replace(/\$web/g,myURL.web)
										.replace(/\$topic/g,myURL.topic);
							});
						positionMenu(el);
						break;
					}		
				case 'oops':
					if (myURL.params.cover && myURL.params.cover.search('print') !== -1) break;
				// case 'attach':
					// not ready to handle upload over ajax yet, need to look at the jQuery Form Plugin
				case 'compare': 
				case 'manage':
				case 'rename':
				// case 'rest':  
					// for now, assume that it already has an associated js eventHandler from its FW plugin
					$hpmenu.find('li').not('#hppreviewli').hide();
					$('#hppreviewli a').attr('href',el.href);
					positionMenu(el);
					break;
			}
		}, function(){
			menuTimer = setTimeout("foswiki.HijaxPlugin.hideMenu()",hideTimeout);
		});
	} else if ($el.is('form')) {
		var $form = $el;
		var url = $form.attr('action');
		$form.find('input[type="submit"]').click(function(){
			var data = foswiki.HijaxPlugin.asObject($form
													.find('input,select,textarea')
													.not('[type="submit"]')
													.add('<input name="'+this.name+'" value="'+this.value+'">'));
			// console.log(data);
			foswiki.HijaxPlugin.serverAction({
				url: url,
				data: data,
				success: function(json){
					foswiki.HijaxPlugin.showResponse(json);
				}
			});
			return false;
		});
		$form.submit(function(){
			var data = $form.find('input,select,textarea').add('<input name="cover" value="ajax">').serialize();
			// console.log(data);
			foswiki.HijaxPlugin.serverAction({
				url: url,
				data: data,
				success: function(json){
					foswiki.HijaxPlugin.showResponse(json);
				}
			});
			return false;
		});
	}
},
pageURL : {},
// parseURL courtesy of James Padolsey, http://james.padolsey.com/javascript/parsing-urls-with-the-dom/
// with some minor changes: host=host, hostname=hostname, params function extracted and corrected to 
// add multiple values to an array, and some FW specific parsing to extract web, topic and script from the url
parseURL : function(url) {
    var a =  document.createElement('a');
    a.href = url;
	var path = a.pathname.replace(/^([^\/])/,'/$1');
	var file = (a.pathname.match(/\/([^\/?#]+)$/i) || [,''])[1];
	var webtopic = path.replace(/^.*\/bin\/[a-z]+\//,'');
	var web = webtopic.replace('/'+file,'');
	var topic = file;
	var script = path.replace(/^.*\/bin\//,'').replace('/'+web+'/'+topic,'');
	var params = objectifyQuery(a.search.replace(/^\?/,''));
	if (params.topic) {
		// TODO: redefine the web and topic values accordingly
	}
    return {
        source: url,
        protocol: a.protocol.replace(':',''),
        hostname: a.hostname,
        host: a.host,
        port: a.port,
        query: a.search,
        params: params,
        file: file,
        hash: a.hash.replace('#',''),
        path: path,
        relative: (a.href.match(/tps?:\/\/[^\/]+(.+)/) || [,''])[1],
        segments: a.pathname.replace(/^\//,'').split('/'),
		webtopic: webtopic,
		web: web,
		topic: topic,
		script: script
    };
},
closeForm : function() {
    $("#newFormClone").fadeOut("fast").remove();
    blocked = 0;
},
openForm : function(name,client) {
    blocked = 1;
    var $form = $(name).clone(true).attr("id","newFormClone").css("z-index","2000");
    $form.centerInClient({container:client,forceAbsolute:true}).fadeIn("slow");
    return $form;
},
loadContent : function(response, $target, method) {
	if (!method) method = 'html';
	var content, head, body;
	// very basic check, json is the default return format and 'content' the content parameter
	// otherwise, the response is html
	if (typeof response === 'object') {
		content = response.content;
		head = response.head;
		body = response.body;
	} else content = response;
	switch (method) {
		case 'replaceWith':
			var $div = $('<div>'+content+'</div>');
			$target.replaceWith($div);
			$target = $div;
			break;
		case 'append':
			$target.append(content);
			break;
		case 'prepend':
			$target.prepend(content);
			break;
		default:
			$target.html(content);
	}
	if (head) appendTo('head',head);
	if (body) appendTo('body',body);
	return $target;
},
showResponse : function(response,url) {
	this.hideMenu();
	foswiki.HijaxPlugin.loadContent(response,$rC);
	$rC.find('a,form').foswikiHijax();
	if (currentURL) {
		back.push(currentURL);
		// console.log(back);
	}
	currentURL = url ? url : response.location ? response.location : null;
	if (currentURL) {
		var myURL = this.parseURL(currentURL);
		if (myURL.params._) delete myURL.params._; // the nocache param from $.ajax()
		// console.log(myURL.params.cover);
		if (myURL.params.cover && myURL.params.cover.search('ajax') != -1) {
			myURL.params.cover = myURL.params.cover.replace(/,?ajax,?/,'');
			// console.log(myURL.params.cover);
			if (myURL.params.cover == '') delete myURL.params.cover;
		}
		var query = stringifyQuery(myURL.params);
		query = query ? '?' + query : '';
		myURL.source = myURL.source.replace(myURL.query,query);
		currentURL = myURL;
		$rcDialog.dialog("option","title",currentURL.topic+' &lt; '+currentURL.web);
	}
	var buttons = $.extend(true,{},dialogButtons);
	if (!back.length) delete buttons.Back;
	if (!forward.length) delete buttons.Forward;
	$rcDialog.dialog("option","buttons",buttons);
	$rcDialog.dialog('open');
	return $rC;
},
showOops : function(response) {
	this.hideMenu();
	foswiki.HijaxPlugin.loadContent(response,$oopsC);
	$oopsC.find('a,form').foswikiHijax();
	$oopsDialog.dialog('open');
	return $oopsC;
},
asObject : function($set) {
	var array = $set.serializeArray();
	var json = {}, i;
	for (i in array) {
		if (json[array[i].name]) {
			if (typeof json[array[i].name] != 'array') json[array[i].name] = [json[array[i].name]];
			json[array[i].name].push(array[i].value);
		} else json[array[i].name] = array[i].value;
	}
	return json;
},
handleResponse : function(json,func,params) {
	var ret = false;
	// console.log(json.context);
	switch (json.context) {
		case 'oops':
			this.showOops(json);
			// tidy up what needs to be tidied up -
			// use with caution as confirm messages are also sent via oops:
			// password_changed, email_changed, confirm (registration), upload_name_changed,
			// remove_user_done, created_web, merge_notice,
			// plus the oopsleaseconflict warning
			if (params.error && typeof params.error === 'function') params.error(json); 
			break;
		case 'login':
			var $formDialog = $('<div>'+json.content+'</div>').dialog({width:'auto'});
			var $form = $formDialog.find('form:first');
			$form.submit(function(){
				// SMELL: assumes that all authenticated users have view access to Main/WebHome,
				// should redirectto a rest tag that confirms authentication.
				// We don't want to get an oops response because of access denied, we want a view response to 
				// be sure that the login has succeeded. So, authenticating against (implied) Main/WebHome 
				// as everyone *should* be able to view this.
				// The original request is executed if the login succeeds
				var ldata = $form.find('input').not('[name="origurl"]')
					.add('<input type="hidden" name="cover" value="ajax">')
					.add('<input type="hidden" name="returntemplate" value="nocontent">')
					.serialize();
				var lurl = foswiki.scriptUrl + "/login";
				$.ajax({
					type: 'POST',
					cache: false,
					async: true,
					dataType: 'json',
					url: lurl,
					data: ldata,
					success: function(object) {
						// console.log('in login:success : '+object.context);
						$formDialog.remove();
						if (object.context == 'view') {
							func(params);  // restart now that we're logged in
							var reload = confirm("You are now logged in.\n"+
								"Would you like to reload the page with your new authenticated status?");
							if (reload) location.reload(true); 
							// because being logged in could mean a different UX for the user
						} else {
							foswiki.HijaxPlugin.handleResponse(object,func,params);
						}
					},
					error: function(xhr,s,err){
						ajaxError(xhr,s,params);
					}
				});
				return false;  // this is the submit return to prevent form submission
			});
			break;
		case 'validate':
			var strikeone = foswiki.pubUrl+'/'+foswiki.systemWebName+'/JavascriptFiles/strikeone.js';
			appendTo('head','<script src="'+strikeone+'"></script>');
			$('<div class="hidden">'+json.content+'</div>')
				.appendTo('body')
				.find('form:first').each(function(){
					foswikiStrikeOne(this);
					params.data = foswiki.HijaxPlugin.asObject($(this)
						.find('input').not('input[type="submit"]')
						.add('<input name="response" value="OK">'));
					params.url = $(this).attr('action');
				}).end().remove();
			validate = 0;
			ret = func(params);
			break;
		default:  // response is either not an error or not provided via HijaxPlugin
			if (params.target) {
				foswiki.HijaxPlugin.loadContent(json,params.target,params.targetmethod);
			}
			if (params.success && typeof params.success === 'function') params.success(json);  // continue 
			ret = json;
			break;
	}
	return ret;
},
serverAction : function(params) {
	var p = $.extend(true, {
				url: foswiki.scriptUrl+'/rest/HijaxPlugin/missing',
				type: 'POST',
				async: false,
				dataType: 'json',
				cache: false,
				data: {
					cover: 'ajax'
				},
				// success: null,
				// error: null,
				// target: null,
				loading: window,
				nooverlay: false
			}, params);
			
	// This is the HijaxPlugin js framework so it's only fair to expect that we'll be
	// guaranteeing that the HijaxPlugin is triggered on the server through /cover=~ajax/.
	if (p.data.cover) {
		if (p.data.cover.search('ajax') == -1) p.data.cover = 'ajax,' + p.data.cover;
	} else if (p.data.search(/cover=[^;&]?ajax/) == -1) {
		// SMELL: assumes p.data is a string and that it has been created by .serialize()
		// which would mean that it has also been URL encoded.
		// p.data is a string (hopefully) created by .serialize()
		// convert it back into an object
		p.data = objectifyQuery(p.data);
		// add 'ajax' to cover
		p.data.cover = p.data.cover ? 'ajax,' + p.data.cover : 'ajax';
		// and rejoin into a URL query string.
		// If we leave it as an object, $.ajax will re-encode what has already been
		// encoded by .serialize()
		p.data = stringifyQuery(p.data);
	}
	
	// note that if passing p instead of params as the last 
	// arguement to serverAction in the $.ajax success function,
	// then if a login or validate needs handling, there is the error 
	// "setting a property that has only a getter" somewhere
	// at or after func(params);
	// ## parked code - to record what I've already tried ##
	// params.success ||= null
	// params.error ||= null
	// params.target ||= null
	// if (!params.dataType) params.dataType = p.dataType;
	// ###
	
	// if the url has a hash, $.ajax() will put all the serialised data after this
	// which won't be recognised on the server
	if (p.url.search('#') != -1) {
		var hash = p.url.replace(/^[^#]+/,'');
		p.url = p.url.replace(hash,'');
		if (typeof p.data === 'object') p.data = $.param(p.data); // serialise it
		p.data += hash;
	}
	var ret = false;
	$.ajax({
		type: p.type,
		async: p.async,
		url: p.url,
		data: p.data,
		dataType: p.dataType,
		cache: p.cache, 
		success: function(json){
			ret = foswiki.HijaxPlugin.handleResponse(json,foswiki.HijaxPlugin.serverAction,params);
		},
		error: function(xhr,s,err){
			ajaxError(xhr,s,params);
		},
		beforeSend: function(){
			if (p.loading) {
				var $container = $(p.loading);
				if (!p.nooverlay) $overlay.css({"width":$container.width(),"height":$container.height()})
					.centerInClient({container:p.loading}).show();
				$spinner.centerInClient({container:p.loading,forceAbsolute:false}).fadeIn('fast');
			}
		},
		complete: function(){
			if (p.loading) {
				$spinner.fadeOut('fast');
				$overlay.hide();
			}
		}
	});
    return ret;
},
sortUserlists : function() {
	$('.userlist').each(function(){
		var selected = $(this).val();
		var arr = $(this).find('option').sort(function(a,b){
			if ($(a).val() < $(b).val()) return -1;
			if ($(a).val() > $(b).val()) return 1;
			return 0;
		});
		$(arr).appendTo(this);
		$(this).val(selected);
	});
},
init : function(holder) {
	nohijax = holder.nohijax, $hpssleight = holder.hps;
	$(
		'<div id="spinner" class="foswikiFormSteps hidden"><img src="'+
		foswiki.pubUrl+'/'+foswiki.systemWebName+'/DocumentGraphics/processing-32-bg.gif" /></div>'+
		'<div id="overlay" class="hidden"></div>'
	).appendTo('body');
	$overlay = $('#overlay');
	$spinner = $('#spinner');
	$.ajaxSetup ({
		error: function(xhr,s,err){
			alert("readyState: "+xhr.readyState+"\nstatus: "+xhr.status+"\nbut "+s);
			alert("responseText: "+xhr.responseText);
		}
	});
	this.sortUserlists();
	this.pageURL = this.parseURL(window.location.href);
	$hpmenu = $('#hpmenu');
	$hpanchor = $('#hpanchor');
	if ($hpmenu && $hpanchor) {
		$hpmenu.find('ul').hover(function(){
			clearTimeout(menuTimer);
		}, function(){
			menuTimer = setTimeout("foswiki.HijaxPlugin.hideMenu()",hideTimeout);
		});
		$hpmenu.find('a').click(function(){
			var url = this.href;
			foswiki.HijaxPlugin.serverAction({
				url: this.href,
				type: 'GET',
				success: function(json){
					forward = [];  // reset forward history buffer
					foswiki.HijaxPlugin.showResponse(json);
				}
			});
			return false;
		});
		$hpanchor.hoverIntent(function(){
			clearTimeout(menuTimer);
			$(this).hide();
			$hpmenu.show();
		}, function(){
		});
		$('a').foswikiHijax();
	}
	// IE5.5/6 png fix
	if (/MSIE ((5\.5)|6)/.test(navigator.userAgent) && navigator.platform == "Win32" && $hpssleight) {
		$hpssleight
			.hpsupersleight({shim: foswiki.pubUrl+'/'+foswiki.systemWebName+'/HijaxPlugin/blank.gif'});
	}
	var dialogDefaults = {
		bgiframe: true,
		autoOpen: false,
		show: 'blind',
		height: 'auto',
		width: '960px',
		maxWidth: '960'
	};
	$rcDialog = $('<div id="rC"></div>').dialog(dialogDefaults);
	$rcDialog.find('div.ui-dialog-buttonpane').insertAfter('#ui-dialog-title-rC');
	$rC = $('#rC');
	$oopsDialog = $('<div id="oopsC"></div>').dialog(dialogDefaults);
	$oopsDialog.dialog("option","buttons",{OK: function(){$(this).dialog('close');}});
	$oopsC = $('#oopsC');
}
};
}(jQuery);

jQuery(function(){
	foswiki.HijaxPlugin.init(foswiki.HijaxPluginConfigurableInit());
});