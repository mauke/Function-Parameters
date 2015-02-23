#!perl

# Make sure we allow a trailing comma.

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;

use Method::Signatures;

func foo($foo, $bar,) {
    return [$foo, $bar];
}

is_deeply foo(23, 42), [23, 42];

done_testing;
