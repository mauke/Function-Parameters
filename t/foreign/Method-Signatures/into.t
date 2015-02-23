#!perl -w

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

# It should be possible to import into another package.

package Foo;

use Test::More 'no_plan';

TODO: {
    local $TODO = 'into is not supported';
    ok eval q[
{ package Bar;
  use Method::Signatures { into => 'Foo' };
}

is( Foo->foo(42), 42 );

method foo ($arg) {
    return $arg;
}

1;
];
}
