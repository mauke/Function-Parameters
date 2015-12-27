use v5.14;
use warnings;

use Config ();

sub MY::postamble {
    my ($self, %args) = @_;
    $args{text} || ''
}

my $preload_libasan;

my @ccflags;
my @otherldflags;

if (-e '/dev/null') {
    my $good_cc_flag = sub {
        system("echo 'int main(void) { return 0; }' | \Q$Config::Config{cc}\E @_ -xc - -o /dev/null") == 0
    };
    for my $flag (qw(-fsanitize=address -fsanitize=undefined)) {
        if (!$good_cc_flag->($flag)) {
            warn "!! Your C compiler ($Config::Config{cc}) doesn't seem to support '$flag'. Skipping ...\n";
            next;
        }
        push @ccflags,      $flag;
        push @otherldflags, $flag;
    }

    {
        local $ENV{LD_PRELOAD} = 'libasan.so ' . ($ENV{LD_PRELOAD} // '');
        my $out = `"$^X" -e 0 2>&1`;
        if ($out eq '') {
            $preload_libasan = 1;
        } else {
            warn qq{LD_PRELOAD="$ENV{LD_PRELOAD}" "$^X" failed:\n${out}Skipping ...\n};
        }
    }
}

sub {
    my ($opt) = @_;

    $opt->{test}{TESTS} .= ' ' . join(' ', map 'xt' . '/*' x $_ . '.t', 1 .. 4);

    $opt->{postamble}{text} .= <<"__EOT__";
export RELEASE_TESTING=1
export HARNESS_OPTIONS=c

CCFLAGS      += @ccflags -DDEVEL
OTHERLDFLAGS += @otherldflags

__EOT__

    if ($preload_libasan) {
        $opt->{postamble}{text} .= <<'__EOT__';
FULLPERLRUN := LD_PRELOAD="libasan.so $$LD_PRELOAD" $(FULLPERLRUN)

__EOT__
    }

    $opt->{postamble}{text} .= <<'__EOT__';
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
__EOT__
}
