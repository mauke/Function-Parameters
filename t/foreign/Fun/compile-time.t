#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Function::Parameters;

is(foo(), "FOO");

fun foo { "FOO" }

done_testing;
