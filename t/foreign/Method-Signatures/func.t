#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More tests => 1;

use Method::Signatures;

func echo($arg) {
    return $arg;
}

is echo(42), 42, "basic func";
