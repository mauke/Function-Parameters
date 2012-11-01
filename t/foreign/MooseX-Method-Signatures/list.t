#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 23;
use Test::Fatal;
use Function::Parameters qw(:strict);

my $o = bless {} => 'Foo';

{
    my @meths = (
        method ($foo, $bar, @rest) {
            return join q{,}, @rest;
        },
        method ($foo, $bar, %rest) {
            return join q{,}, map { $_ => $rest{$_} } keys %rest;
        },
    );

    for my $meth (@meths) {
        ok(exception { $o->$meth() });
        ok(exception { $o->$meth('foo') });

        is(exception {
            is($o->$meth('foo', 'bar'), q{});
        }, undef);

        is(exception {
            is($o->$meth('foo', 'bar', 1 .. 6), q{1,2,3,4,5,6});
        }, undef);
    }
}

{
    my $meth = method ($foo, $bar, @rest) {
        return join q{,}, @rest;
    };

    is(exception {
        is($o->$meth('foo', 42), q{});
    }, undef);

    is(exception {
        is($o->$meth('foo', 42, 23, 13), q{23,13});
    }, undef);

#    like(exception {
#        $o->$meth('foo', 42, 'moo', 13);
#    }, qr/Validation failed/);
}

{
    my $meth = method (@foo) {
        return join q{,}, map { @{ $_ } } @foo;
    };

    is(exception {
        is($o->$meth([42, 23], [12], [18]), '42,23,12,18');
    }, undef);

#    like(exception {
#        $o->$meth([42, 23], 12, [18]);
#    }, qr/Validation failed/);
}

{
    my $meth = method ($foo, @_rest) {};
    is(exception { $meth->($o, 'foo') }, undef);
    is(exception { $meth->($o, 'foo', 42) }, undef);
    is(exception { $meth->($o, 'foo', 42, 23) }, undef);
}

{
    eval 'my $meth = method (:$foo, :@bar) { }';
    like $@, qr/\bnamed\b.+\bbar\b.+\barray\b/;

    eval 'my $meth = method ($foo, @bar, :$baz) { }';
    like $@, qr/\bbar\b.+\bbaz\b/;
}
