#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

package Foo;

use Test::More "no_plan";
use Method::Signatures;

method foo(
    $arg
) 
{
    return $arg
}

is( Foo->foo(23), 23 );
