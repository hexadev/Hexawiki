/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the Foswiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/

// The FoswikiTiny class object
var FoswikiTiny = {

    foswikiVars: null,
    metaTags: null,

    tml2html: new Array(),
    // callbacks, attached in plugins
    html2tml: new Array(),
    // callbacks, attached in plugins
    // Get a Foswiki variable from the set passed
    getFoswikiVar: function(name) {
        if (FoswikiTiny.foswikiVars == null) {
            var sets = tinyMCE.activeEditor.getParam("foswiki_vars", "");
            FoswikiTiny.foswikiVars = eval(sets);
        }
        return FoswikiTiny.foswikiVars[name];
    },

    expandVariables: function(url) {
        for (var i in FoswikiTiny.foswikiVars) {
            url = url.replace('%' + i + '%', FoswikiTiny.foswikiVars[i], 'g');
        }
        return url;
    },

    saveEnabled: 0,
    enableSaveButton: function(enabled) {
        var status = enabled ? null : "disabled";
        FoswikiTiny.saveEnabled = enabled ? 1 : 0;
        var elm = document.getElementById("save");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("quietsave");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("checkpoint");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("preview");
        if (elm) {
            elm.style.display = 'none'; // Item5263: broken preview
            elm.disabled = status;
        }
    },

    transform: function(editor, handler, text, onSuccess, onFail) {
        // Work out the rest URL from the location
        var url = FoswikiTiny.getFoswikiVar("SCRIPTURL");
        var suffix = FoswikiTiny.getFoswikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/" + handler;
        var path = FoswikiTiny.getFoswikiVar("WEB") + '.' + 
            FoswikiTiny.getFoswikiVar("TOPIC");

        tinymce.util.XHR.send({
            url: url,
            content_type: "application/x-www-form-urlencoded",
            type: "POST",
            data: "nocache=" + encodeURIComponent((new Date()).getTime()) +
                  "&topic=" + encodeURIComponent(path) + "&text=" +
                  encodeURIComponent(text),
            async: true,
            scope: editor,
            success: onSuccess,
            error: onFail
        })
    },

    initialisedFromServer: false,

    // Set up content for the initial edit
    setUpContent: function(editor_id, body, doc) {
        // If we haven't done it before, then transform from TML
        // to HTML. We need this test so that pressing the 'back'
        // button from a failed save doesn't banjax the old content.
        if (FoswikiTiny.initialisedFromServer) return;
        var editor = tinyMCE.getInstanceById(editor_id);
        FoswikiTiny.switchToWYSIWYG(editor);
        FoswikiTiny.initialisedFromServer = true;
    },

    cleanBeforeSave: function(eid, buttonId) {
        var el = document.getElementById(buttonId);
        if (el == null) return;
        // SMELL: what if there is already an onclick handler?
        el.onclick = function() {
            var editor = tinyMCE.getInstanceById(eid);
            editor.isNotDirty = true;
            return true;
        }
    },

    onSubmitHandler: false,

    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    switchToRaw: function(editor) {
        var text = editor.getContent();

        // Make the raw-edit help visible (still subject to toggle)
        var el = document.getElementById("foswikiTinyMcePluginWysiwygEditHelp");
        if (el) {
            el.style.display = 'none';
        }
        el = document.getElementById("foswikiTinyMcePluginRawEditHelp");
        if (el) {
            el.style.display = 'block';
        }

        // Evaluate post-processors attached from plugins
        for (var i = 0; i < FoswikiTiny.html2tml.length; i++) {
            var cb = FoswikiTiny.html2tml[i];
            text = cb.apply(editor, [editor, text]);
        }
        FoswikiTiny.enableSaveButton(false);
        editor.getElement().value = "Please wait... retrieving page from server.";
        FoswikiTiny.transform(
        editor, "html2tml", text, function(text, req, o) {
            this.getElement().value = text;
            FoswikiTiny.enableSaveButton(true);
        },
        function(type, req, o) {
            this.setContent("<div class='foswikiAlert'>" + 
                "There was a problem retrieving " + o.url + ": " + type + " " +
                req.status + "</div>");
            //FoswikiTiny.enableSaveButton(true); leave save disabled
        });
        // Add the button for the switch back to WYSIWYG mode
        var eid = editor.id;
        var id = eid + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, unhide it
            el.style.display = "block";
        } else {
            // does not exist, create it
            el = document.createElement('INPUT');
            el.id = id;
            el.type = "button";
            el.value = "WYSIWYG";
            el.className = "foswikiButton";
            el.onclick = function() {
                // Make the wysiwyg help visible (still subject to toggle)
                var el = document.getElementById(
                        "foswikiTinyMcePluginWysiwygEditHelp");
                if (el) {
                    el.style.display = 'block';
                }
                el = document.getElementById("foswikiTinyMcePluginRawEditHelp");
                if (el) {
                    el.style.display = 'none';
                }
                tinyMCE.execCommand("mceToggleEditor", null, eid);
                FoswikiTiny.switchToWYSIWYG(editor);
                return false;
            }
            // Need to insert after to avoid knackering 'back'
            var pel = editor.getElement().parentNode;
            pel.insertBefore(el, editor.getElement());
        }
        // SMELL: what if there is already an onchange handler?
        editor.getElement().onchange = function() {
            var editor = tinyMCE.getInstanceById(eid);
            editor.isNotDirty = false;
            return true;
        },
        // Ooo-err. Stomp on the default submit handler and
        // forcibly disable the editor to prevent a call to
        // the TMCE save. This in turn blocks the getContent
        // that would otherwise wipe out the content of the
        // textarea with the DOM. We'd better make damn sure we
        // remove this handler when we switch back!
        this.onSubmitHandler = function(ed, e) {
            // SMELL: Editor.initialized is undocumented and liable
            // to break when we upgrade TMCE
            editor.initialized = false;
        };
        // SMELL: Event.addToTop() is undocumented and liable
        // to break when we upgrade TMCE
        editor.onSubmit.addToTop(this.onSubmitHandler);
        // Make the save buttons mark the text as not-dirty 
        // to avoid the popup that says "Are you sure? The changes you have
        // made will be lost"
        FoswikiTiny.cleanBeforeSave(eid, "save");
        FoswikiTiny.cleanBeforeSave(eid, "quietsave");
        FoswikiTiny.cleanBeforeSave(eid, "checkpoint");
        // preview shouldn't get the popup either, when preview is enabled one
        // day
        FoswikiTiny.cleanBeforeSave(eid, "preview");
        // cancel shouldn't get the popup because the user just *said* they
        // want to cancel
        FoswikiTiny.cleanBeforeSave(eid, "cancel");
    },

    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    switchToWYSIWYG: function(editor) {
        // Kill the change handler to avoid excess fires
        editor.getElement().onchange = null;

        // Get the textarea content
        var text = editor.getElement().value;

        if (this.onSubmitHandler) {
            editor.onSubmit.remove(this.onSubmitHandler);
            this.onSubmitHandler = null;
        }
        FoswikiTiny.enableSaveButton(false);
        editor.setContent("<span class='foswikiAlert'>" +
                "Please wait... retrieving page from server." + "</span>");
        FoswikiTiny.transform(
        editor, "tml2html", text, function(text, req, o) { // Success
            // Evaluate any registered pre-processors
            for (var i = 0; i < FoswikiTiny.tml2html.length; i++) {
                var cb = FoswikiTiny.tml2html[i];
                text = cb.apply(this, [this, text]);
            }
            /* SMELL: Work-around for Item2270. In future this plugin may
                   be updated so that this needs to be changed. TMCE's wordcount
                   plugin limits itself to a max. of one count per
                   2 seconds, so users always see a wordcount of 6 (Please
                   wait... retrieving page from server) when they first edit a
                   document. So remove lock before setContent() */
            if (this.plugins.wordcount !== undefined && 
                this.plugins.wordcount.block !== undefined) {
                this.plugins.wordcount.block = 0;
            }
            this.setContent(text);
            this.isNotDirty = true;
            FoswikiTiny.enableSaveButton(true);
        },
        function(type, req, o) {
            // Handle a failure
            this.setContent("<div class='foswikiAlert'>" + 
                    "There was a problem retrieving " + o.url + ": " + type + 
                    " " + req.status + "</div>");
            //FoswikiTiny.enableSaveButton(true); leave save disabled
        });

        // Hide the conversion button, if it exists
        var id = editor.id + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, hide it
            el.style.display = "none";
        }
    },

    // Callback on save. Make sure the WYSIWYG flag ID is there.
    saveCallback: function(editor_id, html, body) {
        // Evaluate any registered post-processors
        var editor = tinyMCE.getInstanceById(editor_id);
        for (var i = 0; i < FoswikiTiny.html2tml.length; i++) {
            var cb = FoswikiTiny.html2tml[i];
            html = cb.apply(editor, [editor, html]);
        }
        var secret_id = tinyMCE.activeEditor.getParam('foswiki_secret_id');
        if (secret_id != null && 
                html.indexOf('<!--' + secret_id + '-->') == -1) {
            // Something ate the ID. Probably IE. Add it back.
            html = '<!--' + secret_id + '-->' + html;
        }
        return html;
    },

    // Called 
    // Called on URL insertion, but not on image sources. Expand Foswiki
    // variables in the url.
    convertLink: function(url, node, onSave) {
        if (onSave == null) onSave = false;
        var orig = url;
        var pubUrl = FoswikiTiny.getFoswikiVar("PUBURL");
        var vsu = FoswikiTiny.getFoswikiVar("VIEWSCRIPTURL");
        url = FoswikiTiny.expandVariables(url);
        if (onSave) {
            if ((url.indexOf(pubUrl + '/') != 0) && 
                    (url.indexOf(vsu + '/') == 0)) {
                url = url.substr(vsu.length + 1);
                url = url.replace(/\/+/g, '.');
                if (url.indexOf(FoswikiTiny.getFoswikiVar('WEB') + '.') == 0) {
                    url =
                        url.substr(FoswikiTiny.getFoswikiVar('WEB').length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // if it's a wikiword, make a suitable link
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = FoswikiTiny.getFoswikiVar("WEB");
                    }
                    web = web.replace(/\.+/g, '/');
                    web = web.replace(/\/+$/, '');
                    url = vsu + '/' + web + '/' + topic;
                }
            }
        }
        return url;
    },

    // Called from Insert Image, when the image is inserted. The resultant
    // URL is only used when displaying the image in the picture dialog. It
    // is thrown away (reverts to the typed address) when the image is
    // actually inserted, at which time convertLink is called.
    convertPubURL: function(url) {
        url = FoswikiTiny.expandVariables(url);
        if (url.indexOf('/') == -1) {
            var base = FoswikiTiny.getFoswikiVar("PUBURL") + '/' + 
                FoswikiTiny.getFoswikiVar("WEB") + '/' + 
                FoswikiTiny.getFoswikiVar("TOPIC") + '/';
            url = base + url;
        }
        return url;
    },

    getMetaTag: function(inKey) {
        if (FoswikiTiny.metaTags == null || FoswikiTiny.metaTags.length == 0) {
            // Do this the brute-force way because of the Firefox problem
            // seen sporadically on Bugs where the DOM appears complete, but
            // the META tags are not all found by getElementsByTagName
            var head = document.getElementsByTagName("META");
            head = head[0].parentNode.childNodes;
            FoswikiTiny.metaTags = new Array();
            for (var i = 0; i < head.length; i++) {
                if (head[i].tagName != null && 
                        head[i].tagName.toUpperCase() == 'META') {
                    FoswikiTiny.metaTags[head[i].name] = head[i].content;
                }
            }
        }
        return FoswikiTiny.metaTags[inKey];
    },

    install: function() {
        // find the TINYMCEPLUGIN_INIT_ENCODED preference
        var tmce_init = foswiki.getPreference('TINYMCEPLUGIN_INIT_ENCODED');
        if (tmce_init != null) {
            eval("tinyMCE.init({" + unescape(tmce_init) + "});");
            return;
        }
        alert(
"Unable to install TinyMCE; 'TINYMCEPLUGIN_INIT_ENCODED' preference missing");
    },

    getTopicPath: function() {
        return this.getFoswikiVar("WEB") + '.' + this.getFoswikiVar("TOPIC");
    },

    getScriptURL: function(script) {
        var scripturl = this.getFoswikiVar("SCRIPTURL");
        var suffix = this.getFoswikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        return scripturl + "/" + script + suffix;
    },

    getRESTURL: function(fn) {
        return this.getScriptURL('rest') + "/WysiwygPlugin/" + fn;
    },

    getListOfAttachments: function(onSuccess) {
        var url = this.getRESTURL('attachments');
        var path = this.getTopicPath();
        var params = "nocache=" + 
            encodeURIComponent((new Date()).getTime()) + "&topic=" +
            encodeURIComponent(path);

        tinymce.util.XHR.send({
            url: url + "?" + params,
            type: "POST",
            content_type: "application/x-www-form-urlencoded",
            data: params,
            success: function(atts) {
                if (atts != null) {
                    onSuccess(eval(atts));
                }
            }
        });
    }
};
