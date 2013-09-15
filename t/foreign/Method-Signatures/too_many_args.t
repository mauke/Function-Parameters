#!perl

use strict;
use warnings FATAL => 'all';

use Test::More;

use Function::Parameters qw(:strict);

fun no_sig { return @_ }
fun no_args() { return @_ }
fun one_arg($foo) { return $foo }
fun two_args($foo, $bar) { return ($foo, $bar) }
fun array_at_end($foo, @stuff) { return ($foo, @stuff) }
fun one_named(:$foo) { return $foo; }
fun one_named_one_positional($bar, :$foo) { return($foo, $bar) }

note "too many arguments"; {
    is_deeply [no_sig(42)], [42];


    ok !eval { no_args(42); 1 },                                   "no args";
    like $@, qr{Too many arguments};

    ok !eval { one_arg(23, 42); 1 },                               "one arg";
    like $@, qr{Too many arguments};

    ok !eval { two_args(23, 42, 99); 1 },                          "two args";
    like $@, qr{Too many arguments};

    is_deeply [array_at_end(23, 42, 99)], [23, 42, 99],         "array at end";
}


note "with positionals"; {
    is one_named(foo => 42), 42;
    is one_named(foo => 23, foo => 42), 42;



    is_deeply [one_named_one_positional(23, foo => 42)], [42, 23];
    is_deeply [one_named_one_positional(23, foo => 42, foo => 23)], [23, 23];

}


done_testing;
