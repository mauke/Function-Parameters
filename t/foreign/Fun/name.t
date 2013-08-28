#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Carp;

my $file = __FILE__;
my $line = __LINE__;

{
    package Foo;
    use Function::Parameters;
    fun foo ($x, $y) {
        Carp::confess "$x $y";
    }

    eval {
        foo("abc", "123");
    };

    my $line_confess = $line + 6;
    my $line_foo = $line + 10;

    ::like($@, qr/^abc 123 at $file line $line_confess\.?\n\tFoo::foo\((["'])abc\1, 123\) called at $file line $line_foo/);
}

SKIP: { skip "Sub::Name required", 1 unless eval { require Sub::Name };

{
    package Bar;
    use Function::Parameters;
    *bar = Sub::Name::subname(bar => fun ($a, $b) { Carp::confess($a + $b) });

    eval {
        bar(4, 5);
    };

    my $line_confess = $line + 24;
    my $line_bar = $line + 27;

    ::like($@, qr/^9 at $file line $line_confess\.?\n\tBar::bar\(4, 5\) called at $file line $line_bar/);
}

}

done_testing;
