#!perl
use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;

use Function::Parameters qw(:strict);

fun echo($arg) {
    return $arg;
}

is echo(42), 42, "basic func";
