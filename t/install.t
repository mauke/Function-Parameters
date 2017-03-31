#!perl
use strict;
use warnings FATAL => 'all';

use Test::More tests => 20;

use constant MODIFIERS => qw(
    before after around augment override
);

use Function::Parameters qw(:modifiers :std), {
    map +("${_}_c" => { defaults => $_, runtime => 0 }), MODIFIERS
};

my $test_pkg;
{
    package NotMain;
    BEGIN { $test_pkg = __PACKAGE__; }

    my $TRACE;
    fun TRACE($str) {
        $TRACE .= " $str";
    }
    fun getT() {
        my $r = $TRACE;
        $TRACE = '';
        $r
    }

    BEGIN {
        for my $m (::MODIFIERS) {
            my $sym = do { no strict 'refs'; \*$m };
            *$sym = fun ($name, $body) {
                TRACE "$m($name)";
                $body->('A', 'B', 'C');
            };
        }
    }

    BEGIN { ::is getT, undef; }
    ::is getT, '';

    around_c k_1($x) {
        TRACE "k_1($orig, $self, $x | @_)";
    }
    around k_2($x) {
        TRACE "k_2($orig, $self, $x | @_)";
    }
    BEGIN { ::is getT, ' around(k_1) k_1(A, B, C | C)'; }
    ::is getT, ' around(k_2) k_2(A, B, C | C)';

    before_c k_3($x, $y) {
        TRACE "k_3($self, $x, $y | @_)";
    }
    before k_4($x, $y) {
        TRACE "k_4($self, $x, $y | @_)";
    }
    BEGIN { ::is getT, ' before(k_3) k_3(A, B, C | B C)'; }
    ::is getT, ' before(k_4) k_4(A, B, C | B C)';

    after_c k_5($x, $y) {
        TRACE "k_5($self, $x, $y | @_)";
    }
    after k_6($x, $y) {
        TRACE "k_6($self, $x, $y | @_)";
    }
    BEGIN { ::is getT, ' after(k_5) k_5(A, B, C | B C)'; }
    ::is getT, ' after(k_6) k_6(A, B, C | B C)';
}

BEGIN {
    for my $i (1 .. 6) {
        my $m = "k_$i";
        is $test_pkg->can($m), undef, "$test_pkg->can($m) is undef at compile time";
    }
}
for my $i (1 .. 6) {
    my $m = "k_$i";
    is $test_pkg->can($m), undef, "$test_pkg->can($m) is undef at runtime";
}
