#!perl

# Test the $arg! required syntax

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;


{
    package Stuff;

    use Test::More;
    use Test::Fatal;
    use Method::Signatures;

    method whatever($this!) {
        return $this;
    }

    is( Stuff->whatever(23),    23 );

#line 23
    like exception { Stuff->whatever() },
      qr{Too few arguments for method whatever},
      'simple required param error okay';

    method some_optional($that!, $this = 22) {
        return $that + $this
    }

    is( Stuff->some_optional(18), 18 + 22 );

#line 33
    like exception { Stuff->some_optional() },
      qr{Too few arguments for method some_optional},
      'some required/some not required param error okay';
}


done_testing();
