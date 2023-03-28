#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;

use Function::Parameters;

my $foo = fun ($bar, $baz) { return "${bar}-${baz}" };

is($foo->(qw/bar baz/), 'bar-baz');
