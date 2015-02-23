#!perl

# Test slurpy parameters

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;
use Test::Fatal;

{
    package Stuff;
    use Method::Signatures;
    use Test::More;

    method slurpy(@that) { return \@that }
    method slurpy_required(@that!) { return \@that }
    method slurpy_last($this, @that) { return $this, \@that; }

    ok !eval q[func slurpy_first(@that, $this) { return $this, \@that; }];
    like $@, qr{In func slurpy_first: I was expecting "\)" after "\@that", not "\$this"};

    ok !eval q[func slurpy_middle($this, @that, $other) { return $this, \@that, $other }];
    like $@, qr{In func slurpy_middle: I was expecting "\)" after "\@that", not "\$other"}i;
    ok !eval q[func slurpy_positional(:@that) { return \@that; }];
    like $@, qr{In func slurpy_positional: named parameter \@that can't be an array}i;


    ok !eval q[func slurpy_two($this, @that, @other) { return $this, \@that, \@other }];
    like $@, qr{In func slurpy_two: I was expecting "\)" after "\@that", not "\@other"};
}


note "Optional slurpy params accept 0 length list"; {
    is_deeply [Stuff->slurpy()], [[]];
    is_deeply [Stuff->slurpy_last(23)], [23, []];
}

note "Required slurpy params require an argument"; {
    ok !eval { Stuff->slurpy_required() };
    like $@, qr{slurpy_required\Q()\E, missing required argument \@that at \Q$0\E line @{[__LINE__ - 1]}};
}


done_testing;
