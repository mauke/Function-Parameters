#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 8;

{
    package TX;

    sub check { 1 }

    our $obj;
    BEGIN { $obj = bless {}, 'TX'; }
}

use Function::Parameters {
    fun => {
        strict => 1,
        reify_type => sub {
            my ($type) = @_;
            my $package = caller;
            if ($package ne $type) {
                my (undef, $file, $line) = @_;
                diag "";
                diag "! $file : $line";
            }
            is $package, $type;
            $TX::obj
        },
    },
};

fun f1(main $x) {}
fun Asdf::f1(main $x) {}

{
    package Foo::Bar::Baz;

    fun f1(Foo::Bar::Baz $x) {}
    fun Ghjk::f1(Foo::Bar::Baz $x) {}

    package AAA;
    fun f1(AAA $x) {}
    fun main::f2(AAA $x) {}
}

fun f3(main $x) {}
fun Ghjk::f2(main $x) {}
