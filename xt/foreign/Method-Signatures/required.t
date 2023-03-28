#!perl

use strict;
use warnings FATAL => 'all';

use Test::More;


{
    package Stuff;

    use Test::More;
    use Test::Fatal;
    use Function::Parameters qw(:strict);

    method whatever($this) {
        return $this;
    }

    is( Stuff->whatever(23),    23 );

    like exception { Stuff->whatever() }, qr/Too few arguments/;

    method some_optional($that, $this = 22) {
        return $that + $this
    }

    is( Stuff->some_optional(18), 18 + 22 );

    like exception { Stuff->some_optional() }, qr/Too few arguments/;
}


done_testing();
