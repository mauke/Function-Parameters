#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 29;

use Function::Parameters {
	fun    => 'function_strict',
	method => { defaults => 'method_strict', runtime => 1 },
};

{
	package Foo;

	::ok !defined &f1;
	method f1() {}
	::ok defined &f1;

	::ok !defined &f2;
	::ok !defined &Bar::f2;
	method Bar::f2() {}
	::ok !defined &f2;
	::ok defined &Bar::f2;

	::ok !defined &f3;
	if (@ARGV < 0) { method f3() {} }
	::ok !defined &f3;
}

fun    g1() { (caller 0)[3] }
method g2() { (caller 0)[3] }
fun    Bar::g1() { (caller 0)[3] }
method Bar::g2() { (caller 0)[3] }

is g1,         'main::g1';
is 'main'->g2, 'main::g2';
is Bar::g1,    'Bar::g1';
is 'Bar'->g2,  'Bar::g2';

use Function::Parameters { fun_r => { defaults => 'function_strict', runtime => 1 } };

{
	package Foo_r;

	::ok !defined &f1;
	fun_r f1() {}
	::ok defined &f1;

	::ok !defined &f2;
	::ok !defined &Bar_r::f2;
	fun_r Bar_r::f2() {}
	::ok !defined &f2;
	::ok defined &Bar_r::f2;

	::ok !defined &f3;
	if (@ARGV < 0) { fun_r f3() {} }
	::ok !defined &f3;
}

fun   h1() { (caller 0)[3] }
fun_r h2() { (caller 0)[3] }
fun   Bar::h1() { (caller 0)[3] }
fun_r Bar::h2() { (caller 0)[3] }

is h1,        'main::h1';
is h2(),      'main::h2';
is Bar::h1,   'Bar::h1';
is Bar::h2(), 'Bar::h2';

fun_r p1($x, $y) :($$) {}
is prototype(\&p1), '$$';
is prototype('p1'), '$$';
is prototype('main::p1'), '$$';

fun_r Bar::p2($x, $y = 0) :($;$) {}
is prototype(\&Bar::p2), '$;$';
is prototype('Bar::p2'), '$;$';
