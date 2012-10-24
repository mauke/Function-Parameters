#!perl

use strict;
use warnings FATAL => 'all';

package Foo;

use Test::More "no_plan";
use Function::Parameters qw(:strict);

method foo(
    $arg
) 
{
    return $arg
}

is( Foo->foo(23), 23 );
