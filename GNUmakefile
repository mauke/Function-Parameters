include ./Makefile

CCFLAGS := -DDEVEL $(CCFLAGS)

.PHONY: multitest
multitest:
	f=''; \
	for i in ~/perl5/perlbrew/perls/perl-5.1[468]*/bin/perl perl; do \
	    echo "Trying $$i ..."; \
	    $$i Makefile.PL && make && make test; \
	    [ $$? = 0 ] || f="$$f $$i"; \
	    echo "... done (trying $$i)"; \
	done; \
	[ -z "$$f" ] || { echo "Failed:$$f" >&2; exit 1; }
