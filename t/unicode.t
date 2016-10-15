#!perl
use utf8;
use Test::More tests => 19;

use warnings FATAL => 'all';
use strict;

use Function::Parameters qw(:lax);

fun hörps($x) { $x * 2 }
fun drau($spın̈al_tap) { $spın̈al_tap * 3 }
fun ääää($éééééé) { $éééééé * 4 }

is hörps(10), 20;
is drau(11), 33;
is ääää(12), 48;

is eval('fun á(){} 1'), 1;
is á(42), undef;

is eval('fun ́(){} 1'), undef;
like $@, qr/ parameter list/;

is eval(q<fun 'hi(){} 1>), undef;
like $@, qr/ parameter list/;

is eval('fun ::hi(){} 1'), 1;
is hi(42), undef;

is eval('fun 123(){} 1'), undef;
like $@, qr/ parameter list/;

is eval('fun main::234(){} 1'), undef;
like $@, qr/ parameter list/;

is eval('fun m123(){} 1'), 1;
is m123(42), undef;

is eval('fun ::m234(){} 1'), 1;
is m234(42), undef;
