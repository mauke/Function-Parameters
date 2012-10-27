#!perl

# Test the $arg = undef optional syntax.

use strict;
use warnings FATAL => 'all';

use Test::More;

{
    package Stuff;

    use Test::More;
    use Test::Fatal;
    use Function::Parameters qw(:strict);

    method whatever($this = undef) {
        return $this;
    }

    is( Stuff->whatever(23),    23 );

    method things($this = 99) {
        return $this;
    }

    is( Stuff->things(),        99 );

    method some_optional($that, $this = undef) {
        return $that + ($this || 0);
    }

    is( Stuff->some_optional(18, 22), 18 + 22 );
    is( Stuff->some_optional(18), 18 );


    method named_params(:$this = undef, :$that = undef) {}

    is exception { Stuff->named_params(this => 0) }, undef, 'can leave out some named params';
    is exception { Stuff->named_params(         ) }, undef, 'can leave out all named params';


    # are slurpy parameters optional by default?
    # (throwing in a default just for a little feature interaction test)
    method slurpy_param($this, $that = 0, @other) {}

    my @a = ();
    is exception { Stuff->slurpy_param(0, 0, @a) }, undef, 'can pass empty array to slurpy param';
    is exception { Stuff->slurpy_param(0, 0    ) }, undef, 'can omit slurpy param altogether';
    is exception { Stuff->slurpy_param(0       ) }, undef, 'can omit other optional params as well as slurpy param';
}


done_testing;
