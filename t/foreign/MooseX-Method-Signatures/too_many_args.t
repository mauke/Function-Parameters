#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Fatal;

{
    package Foo;
    use Function::Parameters qw(:strict);

	method new($class:) { bless {}, $class }
    method foo ($bar) { $bar }
}

my $o = Foo->new;
is(exception { $o->foo(42) }, undef);
like(exception { $o->foo(42, 23) }, qr/Too many arguments/);

done_testing;
