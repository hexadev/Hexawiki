TARGET= ecpjavascript.js ecpstyles.css

FOSWIKI_ROOT=~/foswiki/trunk/core

MINIFYCSS=FOSWIKICPAN=$(FOSWIKI_ROOT)/lib/CPAN/lib $(FOSWIKI_ROOT)/tools/minifycss
MINIFYJS=FOSWIKICPAN=$(FOSWIKI_ROOT)/lib/CPAN/lib $(FOSWIKI_ROOT)/tools/minifyjs

GZIP=gzip

.SUFFIXES: .js .css .gz

all: $(TARGET) $(TARGET:.js=.js.gz) $(TARGET:.css=.css.gz)

%.js: %.uncompressed.js
	@echo creating $@ from $<
	@$(MINIFYJS) $< > $@

%.css: %.uncompressed.css
	@echo creating $@ from $<
	@$(MINIFYCSS) $< > $@

%.gz: %
	@echo compressing $< to $@
	@$(GZIP) -c $< > $@


