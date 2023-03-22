#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 20;

{
    package MyTC;

    sub new {
        my $class = shift;
        bless {}, $class
    }

    sub check {
        1
    }

    sub get_message {
        die "Internal error: get_message";
    }
}

my ($reify_arg, @reify_caller);
sub take_em {
    my $t = $reify_arg;
    $reify_arg = undef;
    $t, splice @reify_caller
}

use Function::Parameters {
    fun => {
        defaults   => 'function_strict',
        reify_type => sub {
            @_ == 1 or die "WTF: (@_)";
            $_[0] =~ /\ADie\[(.*)\]\z/s and die "$1\n";
            $reify_arg = $_[0];
            @reify_caller = caller;
            MyTC->new
        },
    },
};

{
    my ($t, @c);
    BEGIN { ($t, @c) = take_em; }
    is $t, undef;
    is @c, 0;
}

{
    package SineWeave;
#line 666 "abc.def"
    fun foo(time [ time [ time ] ] $x) {}
#line 56 "t/types_caller.t"
}

{
    my ($t, @c);
    BEGIN { ($t, @c) = take_em; }
    is $t, 'time[time[time]]';
    is $c[0], 'SineWeave';
    is $c[1], 'abc.def';
    is $c[2], 666;
}

{
    {
        package SineWeave::InEvalOutside;
        eval q{#line 500 "abc2.def"
            fun foo2(A[B] | C::D | E::F [ G, H::I, J | K[L], M::N::O [ P::Q, R ] | S::T ] $x) {}
        };
    }
    is $@, '';
    my ($t, @c) = take_em;
    is $t, 'A[B]|C::D|E::F[G,H::I,J|K[L],M::N::O[P::Q,R]|S::T]';
    is $c[0], 'SineWeave::InEvalOutside';
    is $c[1], 'abc2.def';
    is $c[2], 500;
}

{
    {
        eval q{#line 500 "abc3.def"
            package SineWeave::InEvalInside;
            fun foo3(Any $x) {}
        };
    }
    is $@, '';
    my ($t, @c) = take_em;
    is $t, 'Any';
    is $c[0], 'SineWeave::InEvalInside';
    is $c[1], 'abc3.def';
    is $c[2], 501;
}

{
    is eval q{ fun foo4(Die[blaue[Blume]] $x) {} 1 }, undef;
    is $@, "blaue[Blume]\n";
    my ($t, @c) = take_em;
    is $t, undef;
    is @c, 0;
}
