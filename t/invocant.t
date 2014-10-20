#!perl

use Test::More tests => 25;

use warnings FATAL => 'all';
use strict;

use Function::Parameters { fun => 'function_strict', method => 'method_strict' };

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

is eval { $o->get_z(42) }, undef;
like $@, qr/Too many arguments/;

is eval { $o->set_z }, undef;
like $@, qr/Too few arguments/;

is eval q{fun ($self:) {}}, undef;
like $@, qr/invocant/;

is eval q{fun ($x : $y) {}}, undef;
like $@, qr/invocant/;

is eval q{method (@x:) {}}, undef;
like $@, qr/invocant/;

is eval q{method (%x:) {}}, undef;
like $@, qr/invocant/;

{
	use Function::Parameters {
		def => {
			invocant => 1,
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
