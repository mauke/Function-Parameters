#!perl
use strict;
use warnings FATAL => 'all';

# Importing always affects the currently compiling scope.

package Foo;

use Test::More 'no_plan';

BEGIN {
    package Bar;
    require Function::Parameters;
    Function::Parameters->import;
}

is( Foo->foo(42), 42 );

method foo ($arg) {
    return $arg;
}
