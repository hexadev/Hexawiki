(function(a){a.fn.masonry=function(c,g){function e(h,m,n,o,l){var k=0;for(i=0;i<m;i++){if(n[i]<n[k]){k=i}}h.css({top:n[k],left:l.colW*k+l.posLeft});for(i=0;i<o;i++){l.colY[k+i]=n[k]+h.outerHeight(true)}}function b(l,k,h){if(h.masoned&&k.appendedContent!=undefined){h.$bricks=k.appendedContent.find(k.itemSelector)}else{h.$bricks=k.itemSelector==undefined?l.children():l.find(k.itemSelector)}h.colW=k.columnWidth==undefined?h.$bricks.outerWidth(true):k.columnWidth;h.colCount=Math.floor(l.width()/h.colW);h.colCount=Math.max(h.colCount,1)}function f(m,l,k){if(!k.masoned){m.css("position","relative")}if(!k.masoned||l.appendedContent!=undefined){k.$bricks.css("position","absolute")}var n=a("<div />");m.prepend(n);k.posTop=Math.round(n.position().top);k.posLeft=Math.round(n.position().left);n.remove();if(k.masoned&&l.appendedContent!=undefined){k.colY=m.data("masonry").colY;for(var h=m.data("masonry").colCount;h<k.colCount;h++){k.colY[h]=k.posTop}}else{k.colY=[];for(h=0;h<k.colCount;h++){k.colY[h]=k.posTop}}if(l.singleMode){k.$bricks.each(function(){var o=a(this);e(o,k.colCount,k.colY,1,k)})}else{k.$bricks.each(function(){var o=a(this);var q=Math.ceil(o.outerWidth(true)/k.colW);q=Math.min(q,k.colCount);if(q==1){e(o,k.colCount,k.colY,1,k)}else{var r=k.colCount+1-q;var p=[0];for(h=0;h<r;h++){p[h]=0;for(j=0;j<q;j++){p[h]=Math.max(p[h],k.colY[h+j])}}e(o,r,p,q,k)}})}k.wallH=0;for(h=0;h<k.colCount;h++){k.wallH=Math.max(k.wallH,k.colY[h])}m.height(k.wallH-k.posTop);g.call(k.$bricks);m.data("masonry",k)}function d(m,l,k){var h=m.data("masonry").colCount;b(m,l,k);if(k.colCount!=h){f(m,l,k)}}return this.each(function(){var n=a(this);var l=a.extend({},a.masonry);l.masoned=n.data("masonry")!=undefined;var k=l.masoned?n.data("masonry").options:{};var m=a.extend({},l.defaults,k,c);l.options=m.saveOptions?m:k;g=g||function(){};if(n.children().length>0){b(n,m,l);f(n,m,l);var h=k.resizeable;if(!h&&m.resizeable){a(window).bind("resize.masonry",function(){d(n,m,l)})}if(h&&!m.resizeable){a(window).unbind("resize.masonry")}}})};a.masonry={defaults:{singleMode:false,columnWidth:undefined,itemSelector:undefined,appendedContent:undefined,saveOptions:true,resizeable:true},colW:undefined,colCount:undefined,colY:undefined,wallH:undefined,masoned:undefined,posTop:0,posLeft:0,options:undefined,$bricks:undefined}})(jQuery);