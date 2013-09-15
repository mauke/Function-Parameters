#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 4;

{
    package Optional;
    use Function::Parameters qw(:strict);
    method foo ($class: $arg = undef) {
        $arg;
    }

    method bar ($class: $hr = {}) {
        ++$hr->{bar};
    }
}

is( Optional->foo(), undef);
is( Optional->foo(1), 1);
is( Optional->bar(), 1);
is( Optional->bar({bar=>1}), 2);
