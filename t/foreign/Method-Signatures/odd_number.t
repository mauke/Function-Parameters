#!perl

use warnings FATAL => 'all';
use strict;

use Test::More tests => 1;
use Test::Fatal;

use Function::Parameters qw(:strict);

package Foo {
    method foo(:$name, :$value) {
        return $name, $value;
    }
}

like exception { Foo->foo(name => 42, value =>) }, qr/Not enough arguments.+ line 17/;
