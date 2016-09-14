#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 12;

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

my @reify_caller;
use Function::Parameters {
    fun => {
        defaults   => 'function_strict',
        reify_type => sub {
            @_ == 1 or die "WTF: (@_)";
            @reify_caller = caller;
            MyTC->new
        },
    },
};

{
    my @c;
    BEGIN { @c = splice @reify_caller; }
    is @c, 0;
}

{
    package SineWeave;
#line 666 "abc.def"
    fun foo(Any $x) {}
#line 46 "t/types_caller.t"
}

{
    my @c;
    BEGIN { @c = splice @reify_caller; }
    TODO: {
        #local $TODO = "calling package is wrong";
        is $c[0], 'SineWeave';
    }
    is $c[1], 'abc.def';
    is $c[2], 666;
}

{
    {
        package SineWeave::InEvalOutside;
        eval q{#line 500 "abc2.def"
            fun foo2(Any $x) {}
        };
    }
    is $@, '';
    my @c = splice @reify_caller;
    TODO: {
        #local $TODO = "calling package is wrong";
        is $c[0], 'SineWeave::InEvalOutside';
    }
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
    my @c = splice @reify_caller;
    TODO: {
        #local $TODO = "calling package is wrong";
        is $c[0], 'SineWeave::InEvalInside';
    }
    is $c[1], 'abc3.def';
    is $c[2], 501;
}
