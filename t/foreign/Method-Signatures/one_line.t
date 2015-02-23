#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More tests => 1;

{
    package Thing;

    use Method::Signatures;
    method foo {"wibble"}

    ::is( Thing->foo, "wibble" );
}
