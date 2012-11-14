#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Function::Parameters;

fun Foo::foo ($x, $y) {
    $x + $y;
}

ok(!main->can('foo'));
ok(Foo->can('foo'));
is(Foo::foo(1, 2), 3);

done_testing;
