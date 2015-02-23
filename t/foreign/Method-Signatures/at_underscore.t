#!/usr/bin/env perl

# Test the @_ signature

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;

BEGIN {
    TODO: {
        local $TODO = '# F::P currently does not support the @_ signature.';
        use Method::Signatures;

        if( !ok( eval q[ func (@_){}; ] ) ) {
            done_testing;
            exit;
        }
    }
}

{
    package Foo;
    use Method::Signatures;
    
    func foo(@_) { return @_ }
    method bar(@_) { return @_ }
}

is_deeply [Foo::foo()], [];
is_deeply [Foo::foo(23, 42)], [23, 42];
is_deeply [Foo->bar()], [];
is_deeply [Foo->bar(23, 42)], [23, 42];

done_testing;
