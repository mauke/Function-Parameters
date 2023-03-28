#!perl
use warnings FATAL => 'all';
use strict;
use Test::More tests => 1;

{
    package Thing;

    use Function::Parameters qw(:strict);
    method foo() {"wibble"}

    ::is( Thing->foo, "wibble" );
}
