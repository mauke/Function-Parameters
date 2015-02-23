package Foo;

use strict;
use warnings;
use lib 't/lib';

use Method::Signatures;

method echo($msg) {
    return $msg
}

print Foo->echo(42);
