#!perl
use strict;
use warnings FATAL => 'all';

use Dir::Self;
use Test::More 'no_plan';

#TODO: {
#    todo_skip "This is still totally hosed", 2;

    is eval {
        local $SIG{ALRM} = sub { die "Alarm!\n"; };

        alarm 5;
        my $ret = qx{$^X "-Ilib" -le "package Foo;  use Function::Parameters;  method foo() { 42 } print Foo->foo()"};
        alarm 0;
        $ret;
    }, "42\n", 'one-liner';
    is $@, '';
#}


is eval {
    local $SIG{ALRM} = sub { die "Alarm!\n"; };

    alarm 5;
    my $ret = qx{$^X "-Ilib" -MFunction::Parameters -le "package Foo;  use Function::Parameters;  method foo() { 42 } print Foo->foo()"};
    alarm 0;
    $ret;
}, "42\n", 'one liner with -MFunction::Parameters';
is $@, '';


is eval {
    local $SIG{ALRM} = sub { die "Alarm!\n"; };
    my $simple_plx = __DIR__ . '/simple.plx';

    local $ENV{PERLDB_OPTS} = 'NonStop';
    alarm 5;
    my $ret = qx{$^X "-Ilib" -dw $simple_plx};
    alarm 0;
    $ret;
}, "42", 'debugger';
is $@, '';
