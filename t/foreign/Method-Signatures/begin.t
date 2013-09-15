#!perl

package Foo;

use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Fatal;

use Function::Parameters { method => { defaults => 'method', runtime => 0 } };


our $phase;
BEGIN { $phase = 'compile-time' }
INIT  { $phase = 'run-time'     }


sub method_defined
{
    my ($method) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is exception { Foo->$method }, undef, "method $method is defined at $phase";
}

sub method_undefined
{
    my ($method) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like exception { Foo->$method }, qr/Can't locate object method/, "method $method is undefined at $phase";
}


# The default configuration with compile at BEGIN on.
method top_level_default() {}

# Turn it off.
use Function::Parameters { method => { defaults => 'method', runtime => 1 } };
method top_level_off() {}

# And on again.
use Function::Parameters { method => { defaults => 'method', runtime => 0 } };
method top_level_on() {}

# Now turn it off inside a lexical scope
{
    use Function::Parameters { method => { defaults => 'method', runtime => 1 } };
    method inner_scope_off() {}
}

# And it's restored.
method outer_scope_on() {}


# at compile-time, some should be defined and others shouldn't be
BEGIN {
    method_defined('top_level_default');
    method_undefined('top_level_off');
    method_defined('top_level_on');
    method_undefined('inner_scope_off');
    method_defined('outer_scope_on');
}

# by run-time, they should _all_ be defined
method_defined('top_level_default');
method_defined('top_level_off');
method_defined('top_level_on');
method_defined('inner_scope_off');
method_defined('outer_scope_on');


done_testing;
