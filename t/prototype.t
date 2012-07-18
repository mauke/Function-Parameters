#!perl
use Test::More tests => 27;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

is eval 'fun :([) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :([) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(][[[[[[) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(\;) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\[_;@]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\+) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\\\\) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :([$]) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(\[_$]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

{
	no warnings qw(illegalproto);

	ok eval 'fun :([) {}';
	ok eval 'fun :([) {}';
	ok eval 'fun :(][[[[[[) {}';
	ok eval 'fun :(\;) {}';
	ok eval 'fun :(\[_;@]) {}';
	ok eval 'fun :(\+) {}';
	ok eval 'fun :(\\\\) {}';
	ok eval 'fun :([$]) {}';
	ok eval 'fun :(\[_$]) {}';
}
