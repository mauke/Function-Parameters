#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Function::Parameters;

{
    eval 'fun ( $foo, @bar, $baz ) { return [] }';
    ok $@, '... got an error';
}

{
    eval 'fun ( $foo, %bar, $baz ) { return {} }';
    ok $@, '... got an error';
}

{
    eval 'fun ( $foo, @bar, %baz ) { return [] }';
    ok $@, '... got an error';
}

{
    eval 'fun ( $foo, %bar, @baz ) { return {} }';
    ok $@, '... got an error';
}

done_testing;
