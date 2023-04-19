#!perl
use warnings qw(all FATAL uninitialized);
use strict;
use Test::More tests => 14;
use Test::Fatal;
use Function::Parameters;

BEGIN {
    package MyTC;

    method new( $class:
        :$incline = 0,
        :$file = undef,
        :$line = undef,
        :$broken = undef,
    ) {
        bless {
            incline => $incline,
            file    => $file,
            line    => $line,
            broken  => $broken,
        }, $class
    }

    method can_be_inlined() {
        1
    }

    method inline_check($var) {
        my $line = $self->{line};
        my $file = $self->{file};
        if (defined $file) {
            $line //= (caller)[2];
        }
        my $header = defined $line ? qq{#line $line "$file"\n} : "";
        my $garbage = ";\n" x $self->{incline};
        my $error = $self->{broken} ? "]" : "";
        $header . "do { $garbage defined($var) $error }"
    }

    method check($value) {
        die "check() shouldn't be called";
    }

    method get_message($value) {
        "value is not defined"
    }
}

use constant {
    TDef    => MyTC->new,
    TBroken => MyTC->new(broken => 1, incline => 99),
    TDefI7  => MyTC->new(incline => 7),
    TDefX   => MyTC->new(file => "fake-file", line => 666_666),
    TDefXI2 => MyTC->new(file => "fake-file", line => 666_666, incline => 2),
};

is eval(qq|#line 2 "(virtual)"\nfun (TBroken \$bad) {}|), undef, "broken type constraint doesn't compile";
like $@, qr/\binlining type constraint MyTC=HASH\(\w+\) for parameter 1 \(\$bad\) failed at \(virtual\) line 2\b/, "broken type constraint reports correct source location";

#line 62 "t/types_inline.t"
fun foo0(TDef $x) { $x }

is foo0('good'), 'good', "defined value passes inline check";
like exception { foo0(undef) }, qr/\AIn fun foo0: parameter 1 \(\$x\): value is not defined\b/, "undefined value throws";
is __FILE__ . ' ' . __LINE__, "t/types_inline.t 66", "source location OK";

#line 69 "t/types_inline.t"
fun foo1(TDefI7 $x) { $x }

is foo1('good'), 'good', "(+7) defined value passes inline check";
like exception { foo1(undef) }, qr/\AIn fun foo1: parameter 1 \(\$x\): value is not defined\b/, "(+7) undefined value throws";
is __FILE__ . ' ' . __LINE__, "t/types_inline.t 73", "(+7) source location OK";

#line 76 "t/types_inline.t"
fun foo2(TDefX $x) { $x }

is foo2('good'), 'good', "(X) defined value passes inline check";
like exception { foo2(undef) }, qr/\AIn fun foo2: parameter 1 \(\$x\): value is not defined\b/, "(X) undefined value throws";
is __FILE__ . ' ' . __LINE__, "t/types_inline.t 80", "(X) source location OK";

#line 83 "t/types_inline.t"
fun foo3(TDefXI2 $x) { $x }

is foo3('good'), 'good', "(X+2) defined value passes inline check";
like exception { foo3(undef) }, qr/\AIn fun foo3: parameter 1 \(\$x\): value is not defined\b/, "(X+2) undefined value throws";
is __FILE__ . ' ' . __LINE__, "t/types_inline.t 87", "(X+2) source location OK";
