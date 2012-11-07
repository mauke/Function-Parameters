#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Function::Parameters;

fun test_array ( $foo, @bar ) {
    return [ $foo, @bar ];
}

fun test_hash ( $foo, %bar ) {
    return { foo => $foo, %bar };
}

is_deeply( test_array( 1, 2 .. 10 ), [ 1, 2 .. 10 ], '... slurpy array worked' );
is_deeply( test_hash( 1, ( two => 2, three => 3 ) ), { foo => 1, two => 2, three => 3 }, '... slurpy hash worked' );

done_testing;
