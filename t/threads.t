#!perl

use Test::More
    eval { require threads; threads->import; 1 }
        ? (tests => 2)
        : (skip_all => "threads required for testing threads");

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

fun concat3($x, $xxx, $xx) {
    my $helper = eval q{
        fun ($x, $y) { $x . $y }
    };
    return $x . $helper->($xxx, $xx);
}

my $thr = threads->create(fun ($val) {
    concat3 'first (', $val, ') last';
}, 'middle');

my $r1 = concat3 'foo', threads->tid, 'bar';
my $r2 = $thr->join;

is $r1, 'foo0bar';
is $r2, 'first (middle) last';
