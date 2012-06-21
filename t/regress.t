#!perl

use Test::More tests => 21;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

fun mk_counter($i) {
	fun () { $i++ }
}

method nop() {}
fun fnop($x, $y, $z) {
}

is_deeply [nop], [];
is_deeply [main->nop], [];
is_deeply [nop 1], [];
is scalar(nop), undef;
is scalar(nop 2), undef;

is_deeply [fnop], [];
is_deeply [fnop 3, 4], [];
is scalar(fnop), undef;
is scalar(fnop 5, 6), undef;

my $f = mk_counter 0;
my $g = mk_counter 10;
my $h = mk_counter 50;

is $f->(), 0;
is $g->(), 10;
is $h->(), 50;
is $f->(), 1;
is $g->(), 11;
is $h->(), 51;
is $f->(), 2;
is $f->(), 3;
is $f->(), 4;
is $g->(), 12;
is $h->(), 52;
is $g->(), 13;
