#!perl
use strict;
use warnings FATAL => 'all';

use Test::More
    eval { require Moose }
    ? (tests    => 5)
    : (skip_all => "Moose required for testing types")
;
use Test::Fatal;

use Function::Parameters qw(:moose);


is exception
{
    eval q{
        fun foo (
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
        fun bar ( Int :$foo, Int :$bar )       # this is a signature
        {
        }

        1;
    } or die;
}, undef,
'survives comments between signature and open brace';

#SKIP:
#{
#    eval { require MooseX::Declare } or skip "MooseX::Declare required for this test", 1;
#
    is exception
    {
        eval q{
#            use MooseX::Declare;
#            use Method::Signatures::Modifiers;

            package Foo
            {
                method bar ( Int :$foo, Int :$bar )     # this is a signature
                {
                }
            }

            1;
        } or die;
    }, undef,
    'survives comments between signature and open brace';
#}


#TODO: {
#    local $TODO = "closing paren in comment: rt.cpan.org 81364";

    is exception
    {
#        # When this fails, it produces 'Variable "$bar" is not imported'
#        # This is expected to fail, don't bother the user.
#        no warnings;
        eval q{
            fun special_comment (
                $foo, # )
                $bar
            )
            { 42 }
            1;
        } or die;
    }, undef,
    'closing paren in comment';
    is eval q[special_comment("this", "that")], 42;
#}

#done_testing();
