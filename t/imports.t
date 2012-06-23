#!perl

use Test::More tests => 25;

use warnings FATAL => 'all';
use strict;

{
	use Function::Parameters {};  # ZERO BABIES

	is eval('fun foo :() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	use Function::Parameters { pound => 'function' };

	is eval('fun foo :() {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_1($x) { $x }
	is foo_1(2 + 2), 4;

	no Function::Parameters qw(pound);

	is eval('pound foo() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	use Function::Parameters { pound => 'method' };

	is eval('fun foo () {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_2() { $self }
	is foo_2(2 + 2), 4;

	no Function::Parameters qw(pound);

	is eval('pound unfoo :() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	is eval('pound unfoo( ){}; 1'), undef;
	like $@, qr/syntax error/;

	use Function::Parameters { pound => 'classmethod' };

	is eval('fun foo () {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_3() { $class }
	is foo_3(2 + 2), 4;

	no Function::Parameters;

	is eval('pound unfoo :lvalue{}; 1'), undef;
	like $@, qr/syntax error/;
}

is eval('Function::Parameters->import(":QQQQ"); 1'), undef;
like $@, qr/valid identifier/;

is eval('Function::Parameters->import({":QQQQ" => "function"}); 1'), undef;
like $@, qr/valid identifier/;

is eval('Function::Parameters->import({"jetsam" => "QQQQ"}); 1'), undef;
like $@, qr/valid type/;
