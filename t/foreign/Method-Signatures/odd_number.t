#!perl

package Foo;

use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Fatal;

use Method::Signatures;

method foo(:$name, :$value) {
    return $name, $value;
}

like exception { Foo->foo(name => 42, value =>) },
  qr/Too few arguments for method foo/;

done_testing;
