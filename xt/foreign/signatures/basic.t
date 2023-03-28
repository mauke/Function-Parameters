#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 5;

use Function::Parameters;

fun foo ($bar) { $bar }

fun korv ($wurst, $_unused, $birne) {
    return "${wurst}-${birne}";
}

fun array ($scalar, @array) {
    return $scalar + @array;
}

fun hash (%hash) {
    return keys %hash;
}

fun Name::space ($moo) { $moo }

is(foo('baz'), 'baz');
is(korv(qw/a b c/), 'a-c');
is(array(10, 1..10), 20);
is_deeply(
    [sort(hash(foo => 1, bar => 2))],
    [sort(qw/foo bar/)],
);

is(Name::space('kooh'), 'kooh');
