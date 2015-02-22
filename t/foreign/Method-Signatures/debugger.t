#!perl

use strict;
use warnings FATAL => 'all';

use Dir::Self;
use Test::More 'no_plan';

# So all the calls to $^X can find Function::Parameters and Method::Signatures
$ENV{PERL5OPT} .= q[ -Mblib -It/lib ];

is eval {
    local $SIG{ALRM} = sub { die "Alarm!\n"; };

    alarm 5;
    my $ret = qx{$^X -le "package Foo;  use Method::Signatures;  method foo() { 42 } print Foo->foo()"};
    alarm 0;
    $ret;
}, "42\n", 'one-liner';
is $@, '';


is eval {
    local $SIG{ALRM} = sub { die "Alarm!\n"; };

    alarm 5;
    my $ret = qx{$^X -MMethod::Signatures -le "package Foo;  use Method::Signatures;  method foo() { 42 } print Foo->foo()"};
    alarm 0;
    $ret;
}, "42\n", 'one liner with -MMethod::Signatures';
is $@, '';


is eval {
    local $SIG{ALRM} = sub { die "Alarm!\n"; };

    my $simple_plx = __DIR__ . '/simple.plx';
    
    local $ENV{PERLDB_OPTS} = 'NonStop';
    alarm 5;
    my $ret = qx{$^X -dw $simple_plx};
    alarm 0;
    $ret;
}, "42", 'debugger';
is $@, '';
