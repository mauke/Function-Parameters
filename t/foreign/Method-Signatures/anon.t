#!perl
use strict;
use warnings FATAL => 'all';

use Test::More 'no_plan';

{
    package Stuff;

    use Test::More;
    use Function::Parameters qw(:strict);

    method echo($arg) {
        return $arg
    }

    my $method = method ($arg) {
        return $self->echo($arg)
    };

    is( Stuff->$method("foo"), "foo" );
}
