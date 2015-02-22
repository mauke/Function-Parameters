use strict;
use warnings;

sub {
    my ($opt) = @_;

    $opt->{postamble}{text} = <<'EOT';
export RELEASE_TESTING=1
export HARNESS_OPTIONS=c

CCFLAGS += -DDEVEL -fsanitize=address -fsanitize=undefined
OTHERLDFLAGS +=    -fsanitize=address -fsanitize=undefined

.PHONY: multitest
multitest:
	f=''; k=''; \
	for i in "$$PERLBREW_ROOT"/perls/*5.{1[46789],2}*/bin/perl perl; do \
	    echo "Trying $$i ..."; \
	    if $$i Makefile.PL && make && make test; then \
	        k="$$k $$i"; \
	    else \
	        f="$$f $$i"; \
	    fi; \
	    echo "... done (trying $$i)"; \
	done; \
	[ -z "$$k" ] || { echo "OK:    $$k" >&2; } ; \
	[ -z "$$f" ] || { echo "Failed:$$f" >&2; exit 1; }
EOT
}
