#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;

use Function::Parameters;

  fun
   foo
 ($bar, $baz)
       { return q{($bar, $baz) is }.qq{("$bar", "$baz")} }

  my $moo
    =
   fun
 ($bar, $baz)
       { return q{($bar, $baz) is }.qq{("$bar", "$baz")} };

is(foo(qw/affe zomtec/),   '($bar, $baz) is ("affe", "zomtec")');
is($moo->(qw/korv wurst/), '($bar, $baz) is ("korv", "wurst")');

1;
