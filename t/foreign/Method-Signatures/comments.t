#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;
use Test::Fatal;

use Method::Signatures;


is exception
{
    eval q{
        func foo (
            Int :$foo,              # this is foo
            Int :$bar               # this is bar
        )
        {
        }

        1;
    } or die;
}, undef,
'survives comments within the signature itself';


is exception
{
    eval q{
        func bar ( Int :$foo, Int :$bar )       # this is a signature
        {
        }

        1;
    } or die;
}, undef,
'survives comments between signature and open brace';


is exception
{
    eval q{
            func special_comment (
                $foo, # )
                $bar
            )
            { 42 }
            1;
        } or die;
}, undef, 'closing paren in comment';
is eval q[special_comment("this", "that")], 42;


done_testing();
