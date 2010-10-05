var EDITBOX_FONTSTYLE_MONO_CLASSNAME="patternButtonFontSelectorMonospace";var EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME="patternButtonFontSelectorProportional";(function($){foswiki.Edit.toggleFontStateControl=function(jel,buttonState){var pref=foswiki.Edit.getFontStyle();var newPref;var prefCssClassName;var toggleCssClassName;if(pref==EDITBOX_FONTSTYLE_PROPORTIONAL){newPref=EDITBOX_FONTSTYLE_MONO;prefCssClassName=EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;toggleCssClassName=EDITBOX_FONTSTYLE_MONO_CLASSNAME;}else{newPref=EDITBOX_FONTSTYLE_PROPORTIONAL;prefCssClassName=EDITBOX_FONTSTYLE_MONO_CLASSNAME;toggleCssClassName=EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;}
if(buttonState=='over'){jel.removeClass(prefCssClassName)
.addClass(toggleCssClassName);}else if(buttonState=='out'){jel.removeClass(toggleCssClassName)
.addClass(prefCssClassName);}
return newPref;}
$(document).ready(function($){$('span.patternButtonFontSelector')
.hide()
.click(function(e){var newPref=foswiki.Edit.toggleFontStateControl($(this),'');foswiki.Edit.setFontStyle(newPref);return false;})
.mouseover(function(e){foswiki.Edit.toggleFontStateControl($(this),'over');return false;})
.mouseout(function(e){foswiki.Edit.toggleFontStateControl($(this),'out');return false;})
.each(function(index,el){foswiki.Edit.toggleFontStateControl($(el),'out');});$('span.patternButtonEnlarge')
.hide()
.click(function(){return foswiki.Edit.changeEditBox(1);});$('span.patternButtonShrink')
.hide()
.click(function(){return foswiki.Edit.changeEditBox(-1);});$('span.patternButtonShrink').show();$('span.patternButtonEnlarge').show();$('span.patternButtonFontSelector').show();});})(jQuery);