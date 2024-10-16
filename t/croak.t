#!perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 13;
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

is exception { Crabs::take2 1 }, "Too few arguments for fun take2 (expected 2, got 1) at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worng1 },  "Too few arguments for fun take2 (expected 2, got 1) at ${\__FILE__} line ${\($marker + 5)}.\n";
is exception { Crabs::take2 1, 2, 3, 4 }, "Too many arguments for fun take2 (expected 2, got 4) at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worng4 },           "Too many arguments for fun take2 (expected 2, got 4) at ${\__FILE__} line ${\($marker + 6)}.\n";

is exception { Crabs::takekw "a", "b", "c" }, "Odd number of paired arguments for fun takekw at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worngkw1 },             "Odd number of paired arguments for fun takekw at ${\__FILE__} line ${\($marker + 9)}.\n";
is exception { Crabs::takekw a => 1 }, "In fun takekw: missing named parameter: zomg at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worngkw2 },      "In fun takekw: missing named parameter: zomg at ${\__FILE__} line ${\($marker + 10)}.\n";
is exception { Crabs::takekw zomg => 1, a => 2 }, "In fun takekw: no such named parameter: a at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worngkw4 },                 "In fun takekw: no such named parameter: a at ${\__FILE__} line ${\($marker + 11)}.\n";

is exception { Crabs::taket "X" }, "In fun taket: parameter 1 (\$x): A failure (Cool[Story]) of X at ${\__FILE__} line ${\__LINE__}.\n";
is exception { Crabs::worngt1 },   "In fun taket: parameter 1 (\$x): A failure (Cool[Story]) of X at ${\__FILE__} line ${\($marker + 14)}.\n";

use Function::Parameters {
    fun    => { defaults => 'function_strict', reify_type => \&MyT2::reify_type },
    method => 'method_strict',
};

{
    package MyT2;

    fun reify_type($type) {
        bless [$type], __PACKAGE__
    }

    method check($value) { 0 }

    method get_message($value) {
        "A failure ($self->[0]) of $value.\n"
    }
}

{
    package Crabs2;
    fun taket(Cool[Story] $x) {}
}

is exception { Crabs2::taket "X" }, "In fun taket: parameter 1 (\$x): A failure (Cool[Story]) of X.\n";
