#!perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 49;
use Test::Fatal;

use Function::Parameters;

{
    package Foo;

    method new($class : ) {
        return bless {
            x => 1,
            y => 2,
            z => 3,
        }, $class;
    }

    method get_x()       { $self->{x} }
    method get_y($self:) { $self->{y} }
    method get_z($this:) { $this->{z} }

    method set_x($val)        { $self->{x} = $val; }
    method set_y($self:$val)  { $self->{y} = $val; }
    method set_z($this: $val) { $this->{z} = $val; }
}

my $o = Foo->new;
ok $o->isa('Foo'), "Foo->new->isa('Foo')";

is $o->get_x, 1;
is $o->get_y, 2;
is $o->get_z, 3;

$o->set_x("A");
$o->set_y("B");
$o->set_z("C");

is $o->get_x, "A";
is $o->get_y, "B";
is $o->get_z, "C";

is method ($x = $self) { "$self $x [@_]" }->('A'), 'A A []';

is eval { $o->get_z(42) }, undef;
like $@, qr/Too many arguments/;

is eval { $o->set_z }, undef;
like $@, qr/Too few arguments/;

is eval q{fun ($self:) {}}, undef;
like $@, qr/invocant \$self not allowed here/;

is eval q{fun ($x : $y) {}}, undef;
like $@, qr/invocant \$x not allowed here/;

is eval q{method (@x:) {}}, undef;
like $@, qr/invocant \@x can't be an array/;

is eval q{method (%x:) {}}, undef;
like $@, qr/invocant %x can't be a hash/;

is eval q{method ($x, $y:) {}}, undef;
like $@, qr/\Qnumber of invocants in parameter list (2) differs from number of invocants in keyword definition (1)/;

{
    use Function::Parameters {
        def => {
            invocant => 1,
            strict   => 0,
        }
    };

    def foo1($x) { join ' ', $x, @_ }
    def foo2($x: $y) { join ' ', $x, $y, @_ }
    def foo3($x, $y) { join ' ', $x, $y, @_ }

    is foo1("a"), "a a";
    is foo2("a", "b"), "a b b";
    is foo3("a", "b"), "a b a b";
    is foo1("a", "b"), "a a b";
    is foo2("a", "b", "c"), "a b b c";
    is foo3("a", "b", "c"), "a b a b c";
}

use Function::Parameters {
    method2 => {
        defaults => 'method',
        shift    => ['$self1', '$self2' ],
    },
};

method2 m2_a($x) { "$self1 $self2 $x [@_]" }
is m2_a('a', 'b', 'c'), 'a b c [c]';

method2 m2_b($x = $self2, $y = $self1) { "$self1 $self2 $x $y [@_]" }
like exception { m2_b('a', 'b', 'c', 'd', 'e') }, qr/^\QToo many arguments for method2 m2_b (expected 4, got 5)/;
is m2_b('a', 'b', 'c', 'd'), 'a b c d [c d]';
is m2_b('a', 'b', 'c'), 'a b c a [c]';
is m2_b('a', 'b'), 'a b b a []';
like exception { m2_b('a') }, qr/^\QToo few arguments for method2 m2_b (expected 2, got 1)/;

method2 m2_c($t1, $t2:) { "$t1 $t2 [@_]" }
like exception { m2_c('a', 'b', 'c') }, qr/^\QToo many arguments for method2 m2_c (expected 2, got 3)/;
is m2_c('a', 'b'), 'a b []';
like exception { m2_c('a') }, qr/^\QToo few arguments for method2 m2_c (expected 2, got 1)/;

is eval('method2 ($t1, $t2:) { $self1 }'), undef;
like $@, qr/^Global symbol "\$self1" requires explicit package name/;

is eval('method2 ($self1) {}'), undef;
like $@, qr/\$self1 can't appear twice in the same parameter list/;

is eval('method2 ($x, $self2) {}'), undef;
like $@, qr/\$self2 can't appear twice in the same parameter list/;

is eval('method2 m2_z($self: $x) {} 1'), undef;
like $@, qr/^\QIn method2 m2_z: number of invocants in parameter list (1) differs from number of invocants in keyword definition (2)/;
ok !exists &m2_z;

is eval('method2 m2_z($orig, $self, $x: $y) {} 1'), undef;
like $@, qr/^\QIn method2 m2_z: number of invocants in parameter list (3) differs from number of invocants in keyword definition (2)/;
ok !exists &m2_z;
