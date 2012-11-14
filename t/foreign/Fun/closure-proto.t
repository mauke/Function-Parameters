#!perl

use strict;
use warnings FATAL => 'all';
use Test::More;

use Function::Parameters;

{
    my $x = 10;

    fun bar ($y) {
        $x * $y
    }
}

is(bar(3), 30);

done_testing;
