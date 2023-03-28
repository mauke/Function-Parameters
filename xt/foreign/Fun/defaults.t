#!perl
use strict;
use warnings;
use Test::More;

use Function::Parameters qw(:lax);

fun foo ($x, $y = 5) {
    return $x + $y;
}

is(foo(3, 4), 7);
is(foo(3), 8);
{
    my $warning;
    local $SIG{__WARN__} = sub { $warning = $_[0] };
    is(foo, 5);
    like($warning, qr/Use of uninitialized value \$x in addition \(\+\)/);
}

fun bar ($baz, $quux = foo(1) * 2, $blorg = sub { return "ran sub, got " . $_[0] }) {
    $blorg->($baz + $quux);
}

is(bar(3, 4, sub { $_[0] }), 7);
is(bar(5, 6), "ran sub, got 11");
is(bar(7), "ran sub, got 19");
{
    my $warning;
    local $SIG{__WARN__} = sub { $warning = $_[0] };
    is(bar, "ran sub, got 12");
    like($warning, qr/Use of uninitialized value \$baz in addition \(\+\)/);
}

fun baz ($a, $b = our $FOO) {
    return "$a $b";
}

{
    no warnings 'misc'; # 'not imported' warning because we use $FOO later
    eval '$FOO';
    like($@, qr/Global symbol "\$FOO" requires explicit package name/, "doesn't leak scope");
}

our $FOO = "abc";
is(baz("123"), "123 abc");

fun goorch ($x, $y = []) {
    return $y
}

my $goorch_y_1 = goorch( 10 );
my $goorch_y_2 = goorch( 10 );

isnt($goorch_y_1, $goorch_y_2, '... not the same reference');

done_testing;
