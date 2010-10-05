foswiki.webTopicCreator={_canSubmit:function(inForm,inShouldConvertInput){var inputName=inForm.topic.value;if(inputName.length==0){$(inForm.submit).addClass("foswikiSubmitDisabled")
.attr('disabled',true);$("#webTopicCreatorFeedback").html("");return false;}
var nameFilterRegex=foswiki.getPreference('NAMEFILTER')
var re=new RegExp(nameFilterRegex,"g");var userAllowsNonWikiWord=true;$('#nonwikiword').each(function(index,el){userAllowsNonWikiWord=el.checked;});var cleanName;if(userAllowsNonWikiWord){cleanName=inputName.replace(re,"");finalName=cleanName.substr(0,1).toLocaleUpperCase()
+cleanName.substr(1);}else{cleanName=inputName.replace(re," ");finalName=foswiki.String.capitalize(cleanName);finalName=finalName.replace(/\s+/,'','g');}
if(inShouldConvertInput){inForm.topic.value=finalName;}
if(finalName!=inputName){feedbackHeader="<strong>"+TEXT_FEEDBACK_HEADER+"</strong>";feedbackText=feedbackHeader+finalName;$("#webTopicCreatorFeedback").html(feedbackText);}else{$("#webTopicCreatorFeedback").html("");}
if(foswiki.String.isWikiWord(finalName)||userAllowsNonWikiWord){$(inForm.submit).removeClass("foswikiSubmitDisabled")
.attr('disabled',false);return true;}else{$(inForm.submit).addClass("foswikiSubmitDisabled")
.attr('disabled',true);return false;}},_removeSpacesAndPunctuation:function(inText){return foswiki.String.removePunctuation(foswiki.String.removeSpaces(inText));},_filterSpacesAndPunctuation:function(inText){return foswiki.String.removeSpaces(foswiki.String.filterPunctuation(inText));},_passFormValuesToNewLocation:function(inUrl){var url=inUrl;url=url.split("?")[0];var params="";var newtopic=document.forms.newtopicform.topic.value;params+=";newtopic="+newtopic;var topicparent=document.forms.newtopicform.topicparent.value;params+=";topicparent="+topicparent;var templatetopic=document.forms.newtopicform.templatetopic.value;params+=";templatetopic="+templatetopic;var pickparent=URL_PICK_PARENT;params+=";pickparent="+pickparent;params+=";template="+URL_TEMPLATE;url+="?"+params;document.location.href=url;return false;}};(function($){$(document).ready(function(){$('form#newtopicform').each(function(index,el){foswiki.webTopicCreator._canSubmit(el,false);}).submit(function(){return foswiki.webTopicCreator._canSubmit(this,true);});$('input#topic')
.each(function(index,el){el.focus();})
.keyup(function(e){foswiki.webTopicCreator._canSubmit(this.form,false);})
.change(function(e){foswiki.webTopicCreator._canSubmit(this.form,false);})
.blur(function(e){foswiki.webTopicCreator._canSubmit(this.form,true);});$('input#nonwikiword')
.change(function(){foswiki.webTopicCreator._canSubmit(this.form,false);})
.mouseup(function(){foswiki.webTopicCreator._canSubmit(this.form,false);});$('a#pickparent')
.click(function(){return foswiki.webTopicCreator
._passFormValuesToNewLocation(getQueryUrl());});});})(jQuery);