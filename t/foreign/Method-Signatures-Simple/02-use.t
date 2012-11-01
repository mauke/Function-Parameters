#!perl
use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
BEGIN { use_ok 'Function::Parameters' }

{
    package My::Obj;
    use Function::Parameters qw(:strict);

    method make($class: %opts) {
        bless {%opts}, $class;
    }
    method first : lvalue {
        $self->{first};
    }
    method second {
        $self->first + 1;
    }
    method nth($inc) {
        $self->first + $inc;
    }
}

my $o = My::Obj->make(first => 1);
is $o->first, 1;
is $o->second, 2;
is $o->nth(10), 11;

$o->first = 10;

is $o->first, 10;
is $o->second, 11;
is $o->nth(10), 20;

