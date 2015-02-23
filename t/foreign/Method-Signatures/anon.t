#!perl

use strict;
use warnings FATAL => 'all';

use lib 't/lib';
use Test::More 'no_plan';

{
    package Stuff;

    use Test::More;
    use Method::Signatures;

    method echo($arg) {
        return $arg
    }

    my $method = method ($arg) {
        return $self->echo($arg)
    };

    is( Stuff->$method("foo"), "foo" );
}
