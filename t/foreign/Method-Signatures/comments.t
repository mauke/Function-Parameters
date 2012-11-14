#!perl
use strict;
use warnings FATAL => 'all';

use Test::More
	eval { require Moose; 1 }
	? (tests => 2)
	: (skip_all => "Moose required for testing types")
;
use Test::Fatal;

use Function::Parameters qw(:strict);


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
#    lives_ok
#    {
#        eval q{
#            use MooseX::Declare;
#            use Method::Signatures::Modifiers;
#
#            class Foo
#            {
#                method bar ( Int :$foo, Int :$bar )     # this is a signature
#                {
#                }
#            }
#
#            1;
#        } or die;
#    }
#    'survives comments between signature and open brace';
#}
#
#
#done_testing();
