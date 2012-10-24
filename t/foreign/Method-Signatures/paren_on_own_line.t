#!perl

package Foo;

use strict;
use warnings FATAL => 'all';

use Function::Parameters qw(:strict);
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
