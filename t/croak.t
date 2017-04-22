#!perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;
use Test::Fatal;

use Function::Parameters {
    fun    => { defaults => 'function_strict', reify_type => \&MyT::reify_type },
    method => 'method_strict',
};

{
    package MyT;

    fun reify_type($type) {
        bless [$type], __PACKAGE__
    }

    method check($value) { 0 }

    method get_message($value) {
        "A failure ($self->[0]) of $value"
    }
}

my $marker = __LINE__;
{
    package Crabs;

    fun take2($x, $y) {}
    fun worng1() { take2 1 }
    fun worng4() { take2 1, 2, 3, 4 }

    fun takekw(:$zomg) {}
    fun worngkw1() { takekw "a", "b", "c" }
    fun worngkw2() { takekw a => 1 }
    fun worngkw4() { takekw zomg => 1, a => 2 }

    fun taket(Cool[Story] $x) {}
    fun worngt1() { taket "X" }
}

like exception { Crabs::take2 1 }, qr/Too few arguments for fun take2 \(expected 2, got 1\)/;
like exception { Crabs::worng1 },  qr/Too few arguments for fun take2 \(expected 2, got 1\)/;
like exception { Crabs::take2 1, 2, 3, 4 }, qr/Too many arguments for fun take2 \(expected 2, got 4\)/;
like exception { Crabs::worng4 },           qr/Too many arguments for fun take2 \(expected 2, got 4\)/;

like exception { Crabs::takekw "a", "b", "c" }, qr/Odd number of paired arguments for fun takekw/;
like exception { Crabs::worngkw1 },             qr/Odd number of paired arguments for fun takekw/;
like exception { Crabs::takekw a => 1 }, qr/In fun takekw: missing named parameter: zomg/;
like exception { Crabs::worngkw2 },      qr/In fun takekw: missing named parameter: zomg/;
like exception { Crabs::takekw zomg => 1, a => 2 }, qr/In fun takekw: no such named parameter: a/;
like exception { Crabs::worngkw4 },                 qr/In fun takekw: no such named parameter: a/;

like exception { Crabs::taket "X" }, qr/In fun taket: parameter 1 \(\$x\): A failure \(Cool\[Story\]\) of X/;
like exception { Crabs::worngt1 },   qr/In fun taket: parameter 1 \(\$x\): A failure \(Cool\[Story\]\) of X/;
