#!perl

use Test::More tests => 48;

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

	pound foo_1($x, $u) { $x }
	is foo_1(2 + 2), 4;

	no Function::Parameters qw(pound);

	is eval('pound foo() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	use Function::Parameters { pound => 'method' };

	is eval('fun foo () {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_2($u) { $self }
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

	pound foo_3($u) { $class }
	is foo_3(2 + 2), 4;

	no Function::Parameters;

	is eval('pound unfoo :lvalue{}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	use Function::Parameters { pound => 'function_strict' };

	is eval('fun foo :() {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_4($x) { $x }
	is foo_4(2 + 2), 4;

	is eval('foo_4(5, 6)'), undef;
	like $@, qr/Too many arguments/;

	no Function::Parameters qw(pound);

	is eval('pound foo() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	use Function::Parameters { pound => 'method_strict' };

	is eval('fun foo () {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_5() { $self }
	is foo_5(2 + 2), 4;

	is eval('foo_5(5, 6)'), undef;
	like $@, qr/Too many arguments/;

	no Function::Parameters qw(pound);

	is eval('pound unfoo :() {}; 1'), undef;
	like $@, qr/syntax error/;
}

{
	is eval('pound unfoo( ){}; 1'), undef;
	like $@, qr/syntax error/;

	use Function::Parameters { pound => 'classmethod_strict' };

	is eval('fun foo () {}; 1'), undef;
	like $@, qr/syntax error/;

	pound foo_6() { $class }
	is foo_6(2 + 2), 4;

	is eval('foo_6(5, 6)'), undef;
	like $@, qr/Too many arguments/;

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
