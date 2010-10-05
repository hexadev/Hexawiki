var foswiki;if(!foswiki)foswiki={};(function($){foswiki.TwistyPlugin=new function(){var self=this;this._getName=function(inId){var re=new RegExp('(.*)(hide|show|toggle)','g');var m=re.exec(inId);var name=(m&&m[1])?m[1]:'';return name;};this._getType=function(inId){var re=new RegExp('(.*)(hide|show|toggle)','g');var m=re.exec(inId);var type=(m&&m[2])?m[2]:'';return type;}
this._toggleTwisty=function(ref){if(!ref)return;ref.state=(ref.state==foswiki.TwistyPlugin.CONTENT_HIDDEN)?foswiki.TwistyPlugin.CONTENT_SHOWN:foswiki.TwistyPlugin.CONTENT_HIDDEN;self._update(ref,true);}
this._update=function(ref,inMaySave){var showControl=ref.show;var hideControl=ref.hide;var contentElem=ref.toggle;if(ref.state==foswiki.TwistyPlugin.CONTENT_SHOWN){if(inMaySave&&ref.speed!=0){foswiki.TwistyPlugin.showAnimation(contentElem,ref);}else{foswiki.TwistyPlugin.show(contentElem,ref);}
$(showControl).hide();$(hideControl).show();}else{if(inMaySave&&ref.speed!=0){foswiki.TwistyPlugin.hideAnimation(contentElem,ref);}else{foswiki.TwistyPlugin.hide(contentElem,ref);}
$(showControl).show();$(hideControl).hide();}
if(inMaySave&&ref.saveSetting){foswiki.Pref.setPref(foswiki.TwistyPlugin.COOKIE_PREFIX
+ref.name,ref.state);}
if(ref.clearSetting){foswiki.Pref.setPref(foswiki.TwistyPlugin.COOKIE_PREFIX
+ref.name,'');}}
this._register=function(e){if(!e)return;var name=self._getName(e.id);var ref=self._storage[name];if(!ref){ref=new foswiki.TwistyPlugin.Storage();}
if($(e).hasClass('twistyRememberSetting'))
ref.saveSetting=true;if($(e).hasClass('twistyForgetSetting'))
ref.clearSetting=true;if($(e).hasClass('twistyStartShow'))
ref.startShown=true;if($(e).hasClass('twistyStartHide'))
ref.startHidden=true;if($(e).hasClass('twistyFirstStartShow'))
ref.firstStartShown=true;if($(e).hasClass('twistyFirstStartHide'))
ref.firstStartHidden=true;ref.name=name;var type=self._getType(e.id);ref[type]=e;self._storage[name]=ref;switch(type){case'show':case'hide':e.onclick=function(){self._toggleTwisty(ref);return false;}
break;}
return ref;}
this._storage={};};foswiki.TwistyPlugin.show=function(elem,ref){var $elem=$(elem);$elem.removeClass('foswikiHidden');$elem.css({opacity:1,marginTop:ref.marginTop,marginBottom:ref.marginBottom,paddingTop:ref.paddingTop,paddingBottom:ref.paddingBottom});elem.style.height='';}
foswiki.TwistyPlugin.hide=function(elem,ref){var $elem=$(elem);$elem.addClass('foswikiHidden');$elem.css({opacity:0,height:0,marginTop:0,marginBottom:0,paddingTop:0,paddingBottom:0});}
foswiki.TwistyPlugin.showAnimation=function(elem,ref){var $elem=$(elem);$elem.animate({height:ref.height,opacity:1,marginTop:ref.marginTop,marginBottom:ref.marginBottom,paddingTop:ref.paddingTop,paddingBottom:ref.paddingBottom},ref.speed,function(){elem.style.height='';});};foswiki.TwistyPlugin.hideAnimation=function(elem,ref){var $elem=$(elem);$elem.animate({height:0,opacity:0,marginTop:0,marginBottom:0,paddingTop:0,paddingBottom:0},ref.speed,function(){$elem.hide();});};foswiki.TwistyPlugin.CONTENT_HIDDEN=0;foswiki.TwistyPlugin.CONTENT_SHOWN=1;foswiki.TwistyPlugin.COOKIE_PREFIX='TwistyPlugin_';foswiki.TwistyPlugin.prefList;foswiki.TwistyPlugin.init=function(e){if(!e)
return;var name=this._getName(e.id);var ref=this._storage[name];if(ref&&ref.show&&ref.hide&&ref.toggle)
return ref;ref=this._register(e);if(ref.show&&ref.hide&&ref.toggle){if($(e).hasClass('twistyInited1')){ref.state=foswiki.TwistyPlugin.CONTENT_SHOWN;this._update(ref,false);return ref;}
if($(e).hasClass('twistyInited0')){ref.state=foswiki.TwistyPlugin.CONTENT_HIDDEN;this._update(ref,false);return ref;}
if(foswiki.TwistyPlugin.prefList==null){foswiki.TwistyPlugin.prefList=foswiki.Pref.getPrefList();}
var cookie=foswiki.Pref.getPrefValueFromPrefList(foswiki.TwistyPlugin.COOKIE_PREFIX+ref.name,foswiki.TwistyPlugin.prefList);if(ref.firstStartHidden)
ref.state=foswiki.TwistyPlugin.CONTENT_HIDDEN;if(ref.firstStartShown)
ref.state=foswiki.TwistyPlugin.CONTENT_SHOWN;if(cookie&&cookie=='0')
ref.state=foswiki.TwistyPlugin.CONTENT_HIDDEN;if(cookie&&cookie=='1')
ref.state=foswiki.TwistyPlugin.CONTENT_SHOWN;if(ref.startHidden)
ref.state=foswiki.TwistyPlugin.CONTENT_HIDDEN;if(ref.startShown)
ref.state=foswiki.TwistyPlugin.CONTENT_SHOWN;this._update(ref,false);}
return ref;}
foswiki.TwistyPlugin.toggleAll=function(inState){for(var i in this._storage){var e=this._storage[i];e.state=inState;this._update(e,true);}}
foswiki.TwistyPlugin.Storage=function(){this.name;this.state=foswiki.TwistyPlugin.CONTENT_HIDDEN;this.hide;this.show;this.toggle;this.saveSetting=false;this.clearSetting=false;this.startShown;this.startHidden;this.firstStartShown;this.firstStartHidden;this.marginTop;this.marginBottom;this.paddingTop;this.paddingBottom;this.speed;}
$(function(){$('.twistyStartHide').livequery(function(){$(this).hide();});$('.foswikiMakeVisible').livequery(function(){$(this).removeClass('foswikiMakeVisible');});$('.twistyContent').livequery(function(){var ref=foswiki.TwistyPlugin.init(this);var $this=$(this);var speed;if($this.get(0).tagName=='SPAN'){speed=0;}else{speed=foswiki.getPreference('TWISTYANIMATIONSPEED')||0;if(RegExp(/^\d+$/).test(speed)){speed=parseInt(speed);}}
ref.speed=speed;if(speed!=0){ref.height=$this.height()||'toggle';ref.marginTop=$this.css('margin-top');ref.marginBottom=$this.css('margin-bottom');ref.paddingTop=$this.css('padding-top');ref.paddingBottom=$this.css('padding-bottom');}});$('.twistyTrigger').livequery(function(){foswiki.TwistyPlugin.init(this);});$('.twistyExpandAll').livequery(function(){$(this).click(function(){foswiki.TwistyPlugin.toggleAll(foswiki.TwistyPlugin.CONTENT_SHOWN);});});$('.twistyCollapseAll').livequery(function(){$(this).click(function(){foswiki.TwistyPlugin.toggleAll(foswiki.TwistyPlugin.CONTENT_HIDDEN);});});});})(jQuery);