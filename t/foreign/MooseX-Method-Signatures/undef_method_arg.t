#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Fatal;

{
    package Foo;
    use Function::Parameters qw(:strict);

	method new($class:) { bless {}, $class }

#    method m1(:$bar!) { }
#    method m2(:$bar?) { }
#    method m3(:$bar ) { }

#    method m4( $bar!) { }
    method m5( $bar = undef ) { }
    method m6( $bar ) { }
}

my $foo = Foo->new;

#is(exception { $foo->m1(bar => undef) }, undef, 'Explicitly pass undef to positional required arg');
#is(exception { $foo->m2(bar => undef) }, undef, 'Explicitly pass undef to positional explicit optional arg');
#is(exception { $foo->m3(bar => undef) }, undef, 'Explicitly pass undef to positional implicit optional arg');

#is(exception { $foo->m4(undef) }, undef, 'Explicitly pass undef to required arg');
is(exception { $foo->m5(undef) }, undef, 'Explicitly pass undef to explicit required arg');
is(exception { $foo->m6(undef) }, undef, 'Explicitly pass undef to implicit required arg');

done_testing;
