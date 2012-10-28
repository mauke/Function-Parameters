#!perl
use strict;
use warnings;
use Test::More tests => 7;

use vars qw/@warnings/;
BEGIN { $SIG{__WARN__} = sub { push @warnings, @_ } }

BEGIN { is(@warnings, 0, 'no warnings yet') }

use Function::Parameters;

fun with_proto ($x, $y, $z) : ($$$) {
    return $x + $y + $z;
}

{
    my $foo;
    fun with_lvalue () : () lvalue { $foo }
}

is(prototype('with_proto'), '$$$', ':proto attribute');

is(prototype('with_lvalue'), '', ':proto with other attributes');
with_lvalue = 1;
is(with_lvalue, 1, 'other attributes still there');

BEGIN { is(@warnings, 0, 'no warnings with correct :proto declarations') }

fun invalid_proto ($x) : (invalid) { $x }

BEGIN {
    TODO: {
        local $TODO = ':proto checks not yet implemented';
        is(@warnings, 1, 'warning with illegal :proto');
        like(
            $warnings[0],
            qr/Illegal character in prototype for fun invalid_proto : invalid at /,
            'warning looks sane',
        );
    }
}

