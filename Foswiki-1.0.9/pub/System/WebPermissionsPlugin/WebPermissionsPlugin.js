/*
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
*/

//create the Foswiki namespace if needed
if ( typeof( Foswiki ) == "undefined" ) {
    Foswiki = {};
}

/**********************************************************************************/
//create the Foswiki.WebPermissionsPlugin namespace if needed
if ( typeof( Foswiki.WebPermissionsPlugin ) == "undefined" ) {
    Foswiki.WebPermissionsPlugin = {};
}


//moveSelectionTo(event, 'topiceditors', 'allusersandgroups')
Foswiki.WebPermissionsPlugin.moveSelectionTo = function(event, fromSelectName, toSelectName) {
    var buttonTarget = (event.target) ? event.target : event.srcElement;

    var fromSelect = buttonTarget.form.elements.namedItem(fromSelectName);
    var toSelect = buttonTarget.form.elements.namedItem(toSelectName);

     var selList = [];
    for (i=0; i< fromSelect.options.length; i++) {
        var option = fromSelect.options[i];
        if (option.selected) {
            selList.push(option);
        }
    }
    while (selList.length > 0) {
        var option = selList.pop();
        var eachGroup = toSelect.firstChild;
        while (option.parentNode.label != eachGroup.label)
        {
           eachGroup = eachGroup.nextSibling;
        }
        eachGroup.appendChild(option);
        option.changed = 'changed';
    }
}

//the namespace makes Foswiki decide its a web.topic to be rendered as a url
prepareForSave = function(event) {
    return Foswiki.WebPermissionsPlugin.prepareForSave(event);
}

//return false cancels the submit
Foswiki.WebPermissionsPlugin.prepareForSave = function(event) {
//, 'topiceditors', 'topicviewers', 'disallowedusers'
    var buttonTarget = (event.target) ? event.target : event.srcElement;
    
    var userInEditorsList = false;
    var selectObj = buttonTarget.form.elements.namedItem('topiceditors');
    for (i=0; i< selectObj.options.length; i++) {
        if (selectObj.options[i].value == Foswiki.UsersWikiName) {
            userInEditorsList = true;
        }
        if (selectObj.options[i].changed == 'changed') {
            selectObj.options[i].selected=1;
        } else {
            selectObj.options[i].selected=0;
        }
    }
    //make sure the user is still in topiceditors
    if ((!userInEditorsList) && 
        (!confirm('Are you sure you want to prevent yourself from being able to edit this topic?'))) {
        return false;
    }

    var selectObj = buttonTarget.form.elements.namedItem('topicviewers');
    for (i=0; i< selectObj.options.length; i++) {
        if (selectObj.options[i].changed == 'changed') {
            selectObj.options[i].selected=1;
        } else {
            selectObj.options[i].selected=0;
        }
    }
    var selectObj = buttonTarget.form.elements.namedItem('disallowedusers');
    for (i=0; i< selectObj.options.length; i++) {
        if (selectObj.options[i].changed == 'changed') {
            selectObj.options[i].selected=1;
        } else {
            selectObj.options[i].selected=0;
        }
    }
    return true;
}

