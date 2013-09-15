#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

{
    package Foo;

    use Function::Parameters qw(:strict);

    method new($class:) { bless {}, $class }
    method bar (:$baz = 42) { $baz }
}

my $o = Foo->new;
is($o->bar, 42);
is($o->bar(baz => 0xaffe), 0xaffe);

done_testing;
