function beforeSubmitHandler(script, action) {
  //alert("called beforeSubmitHandler");
  var before = jQuery('#beforetext');
  var after = jQuery('#aftertext');
  var chapter = jQuery('#topic');

  if (!before.length || !after.length || !chapter.length) 
    return;

  var chapterText = chapter.val();
  var lastChar = chapterText.substr(chapterText.length-1, 1);
  if (lastChar != '\n') {
    chapterText += '\n';
  }
  jQuery("#text").val(before.val()+chapterText+after.val());
}

(function($) {
/* init gui */
if (true) {
  $(function() {
    $('.ecpHeading').each(function(){
      var $ecpEdit = $('.ecpEdit', this);
      if ($ecpEdit.length) {
        $(this).hover(
          function(event) {
            $(this).addClass('ecpHeadingHover');
            $ecpEdit.css('visibility','visible');
            event.stopPropagation();
          },
          function(event) {
            $(this).removeClass('ecpHeadingHover');
            $ecpEdit.css('visibility','hidden');
            event.stopPropagation();
          }
        ); 
      }
    });
  });
}
})(jQuery);
