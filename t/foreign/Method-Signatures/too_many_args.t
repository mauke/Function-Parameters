#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;

use Method::Signatures { compile_at_BEGIN => 0 };

func no_sig { return @_ }
func no_args() { return @_ }
func one_arg($foo) { return $foo }
func two_args($foo, $bar) { return ($foo, $bar) }
func array_at_end($foo, @stuff) { return ($foo, @stuff) }
func one_named(:$foo) { return $foo; }
func one_named_one_positional($bar, :$foo) { return($foo, $bar) }

note "too many arguments"; {
    ok !eval { no_sig(42); 1 },                                   "no args";
    like $@, qr{Too many arguments for func no_sig \(expected 0, got 1\) };

    ok !eval { no_args(42); 1 },                                   "no args";
    like $@, qr{Too many arguments for func no_args \(expected 0, got 1\)};

    ok !eval { one_arg(23, 42); 1 },                               "one arg";
    like $@, qr{Too many arguments for func one_arg \(expected 1, got 2\)};

    ok !eval { two_args(23, 42, 99); 1 },                          "two args";
    like $@, qr{Too many arguments for func two_args \(expected 2, got 3\)};

    is_deeply [array_at_end(23, 42, 99)], [23, 42, 99],         "array at end";
}


note "with positionals"; {
    is one_named(foo => 42), 42;
    ok !eval { one_named(foo => 23, foo => 42); 1 };
    like $@, qr{one_named\(\), was given too many arguments; it expects 1};


    is_deeply [one_named_one_positional(23, foo => 42)], [42, 23];
    ok !eval { one_named_one_positional(23, foo => 42, foo => 23); 1 };
    like $@, qr{one_named_one_positional\(\), was given too many arguments; it expects 2};
}


done_testing;
