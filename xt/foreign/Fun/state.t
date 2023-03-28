#!perl

use strict;
use warnings FATAL => 'all';
use Test::More;

use 5.10.0;
use Function::Parameters;

fun bar ($y) {
    state $x = 10;
    $x * $y;
}

is(bar(3), 30);

done_testing;
