#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    if (!eval { require 5.016; 1 }) {
        plan skip_all => "This test requires 5.16";
    }
}

use 5.016;

use Function::Parameters;

fun fact ($n) {
    if ($n < 2) {
        return 1;
    }
    return $n * __SUB__->($n - 1);
}

is(fact(5), 120);

is(fun ($n = 8) { $n < 2 ? 1 : $n * __SUB__->($n - 1) }->(), 40320);

fun fact2 ($n) {
    if ($n < 2) {
        return 1;
    }
    return $n * fact2($n - 1);
}

is(fact2(5), 120);

done_testing;
