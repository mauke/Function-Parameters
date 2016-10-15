#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Fatal;

{
    package Foo;
    use Function::Parameters qw(:strict);
    method new($class:) { bless {}, $class }
    method bar(@) { 42 }
}

my $foo = Foo->new;

is(exception {
    $foo->bar
}, undef, 'method without signature succeeds when called without args');

is(exception {
    $foo->bar(42)
}, undef, 'method without signature succeeds when called with args');

done_testing;
