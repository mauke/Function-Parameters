#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 13;
use Test::Fatal;

use Function::Parameters qw(:std :modifiers);

{
    package DefinedType;

    method new($class:) { bless {}, $class }

    method check($x) { defined $x }

    method get_message($ ) { "UNDEFINED" }
}

use constant Defined => DefinedType->new;

my %stash;
fun around($name, $coderef) {
    $stash{$name} = $coderef;
}

fun foo(Defined $x, $whatevs, Defined $y, Defined @z) {}
like exception { foo(undef, undef, undef, undef) }, qr{\A\QIn fun foo: parameter 1 (\E\$x\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { foo('def', undef, undef, undef) }, qr{\A\QIn fun foo: parameter 3 (\E\$y\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { foo('def', undef, 'def', undef) }, qr{\A\QIn fun foo: parameter 4 (\E\@z\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { foo('def', undef, 'def', 'def', undef) }, qr{\A\QIn fun foo: parameter 4 (\E\@z\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
is exception { foo('def', undef, 'def') }, undef;

method bar(Defined $this: Defined $x) {}
like exception { bar(undef, undef) }, qr{\A\QIn method bar: invocant (\E\$this\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { bar('def', undef) }, qr{\A\QIn method bar: parameter 1 (\E\$x\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
is exception { bar('def', 'def') }, undef;

around baz(Defined $self, Defined $orig: Defined $x, Defined $y) {}
like exception { $stash{baz}(undef, undef, undef, undef) }, qr{\A\QIn around baz: invocant 1 (\E\$self\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { $stash{baz}('def', undef, undef, undef) }, qr{\A\QIn around baz: invocant 2 (\E\$orig\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { $stash{baz}('def', 'def', undef, undef) }, qr{\A\QIn around baz: parameter 1 (\E\$x\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
like exception { $stash{baz}('def', 'def', 'def', undef) }, qr{\A\QIn around baz: parameter 2 (\E\$y\Q): UNDEFINED at ${\__FILE__} line ${\__LINE__}.};
is exception { $stash{baz}('def', 'def', 'def', 'def') }, undef;
