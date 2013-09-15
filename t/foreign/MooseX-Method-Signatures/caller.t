use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;

{
    package TestClass;

    use Function::Parameters qw(:strict);

    use Carp ();

    method callstack_inner($class:) {
        return Carp::longmess("Callstack is");
    }

    method callstack($class:) {
        return $class->callstack_inner;
    }
}

my $callstack = TestClass->callstack();

unlike $callstack, qr/Test::Class::.*?__ANON__/, "No anon methods in call chain";
