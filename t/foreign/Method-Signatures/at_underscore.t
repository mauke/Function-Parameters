#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

{
    package Foo;
    use Function::Parameters qw(:strict);

    fun foo(@) { return @_ }
    method bar(@) { return @_ }
}

is_deeply [Foo::foo()], [];
is_deeply [Foo::foo(23, 42)], [23, 42];
is_deeply [Foo->bar()], [];
is_deeply [Foo->bar(23, 42)], [23, 42];

done_testing;
