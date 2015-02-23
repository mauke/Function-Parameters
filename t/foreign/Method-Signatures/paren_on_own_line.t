#!perl

package Foo;

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Method::Signatures;
use Test::More 'no_plan';

# The problem goes away inside an eval STRING.
method foo(
    $arg
)
{
    return $arg;
}

is $@, '';
is( Foo->foo(42), 42 );
