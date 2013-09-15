package Foo;

use strict;
use warnings;

use Function::Parameters;

method echo($msg) {
    return $msg
}

print Foo->echo(42);
