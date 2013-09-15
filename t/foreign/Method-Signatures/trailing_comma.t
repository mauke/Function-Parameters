#!perl

# Make sure we allow a trailing comma.

use strict;
use warnings FATAL => 'all';

use Test::More;

use Function::Parameters qw(:strict);

fun foo($foo, $bar,) {
    return [$foo, $bar];
}

is_deeply foo(23, 42), [23, 42];

done_testing;
