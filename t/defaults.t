#!perl

use Test::More tests => 46;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
	fun => {
		default_arguments => 1,
	},

	nofun => {
		default_arguments => 0,
	},
};

fun foo0($x, $y = 1, $z = 3) { $x * 5 + $y * 2 + $z }

is foo0(10), 55;
is foo0(5, -2), 24;
is foo0(6, 10, 1), 51;

is fun ($answer = 42) { $answer }->(), 42;

fun sharingan($input, $x = [], $y = {}) {
	push @$x, $input;
	$y->{$#$x} = $input;
	$x, $y
}

{
	is_deeply [sharingan 'e'], [['e'], {0 => 'e'}];
	my $sneaky = ['ants'];
	is_deeply [sharingan $sneaky], [[['ants']], {0 => ['ants']}];
	unshift @$sneaky, 'thanks';
	is_deeply [sharingan $sneaky], [[['thanks', 'ants']], {0 => ['thanks', 'ants']}];
	@$sneaky = 'thants';
	is_deeply [sharingan $sneaky], [[['thants']], {0 => ['thants']}];
}

is eval('fun ($x, $y = $powersauce) {}'), undef;
like $@, qr/^Global symbol.*explicit package name/;

{
	my $d = 'outer';
	my $f;
	{
		my $d = 'herp';
		fun guy($d = $d, $x = $d . '2') {
			return [$d, $x];
		}

		is_deeply guy('a', 'b'), ['a', 'b'];
		is_deeply guy('c'), ['c', 'c2'];
		is_deeply guy, ['herp', 'herp2'];

		$d = 'ort';
		is_deeply guy('a', 'b'), ['a', 'b'];
		is_deeply guy('c'), ['c', 'c2'];
		is_deeply guy, ['ort', 'ort2'];

		my $g = fun ($alarum = $d) { "[$alarum]" };
		is $g->(""), "[]";
		is $g->(), "[ort]";

		$d = 'flowerpot';
		is_deeply guy('bloodstain'), ['bloodstain', 'bloodstain2'];
		is $g->(), "[flowerpot]";

		$f = $g;
	}

	is $f->(), "[flowerpot]";
	is $f->("Q"), "[Q]";
}

{
	my $c = 0;
	fun edelweiss($x = $c++) :(;$) { $x }
}

is edelweiss "AAAAA", "AAAAA";
is_deeply edelweiss [], [];
is edelweiss, 0;
is edelweiss, 1;
is_deeply edelweiss {}, {};
is edelweiss 0, 0;
is edelweiss, 2;

for my $f (fun ($wtf = return 'ohi') { "~$wtf" }) {
	is $f->(""), "~";
	is $f->("a"), "~a";
	is $f->(), "ohi";
}

is eval('fun (@x = 42) {}'), undef;
like $@, qr/default value/;

is eval('fun ($x, %y = ()) {}'), undef;
like $@, qr/default value/;

is eval('nofun ($x = 42) {}'), undef;
like $@, qr/nofun.*unexpected.*=.*parameter/;


{
	my $var = "outer";

	fun scope_check(
		$var,  # inner
		$snd = "${var}2",  # initialized from $var)
		$both = "$var and $snd",
	) {
		return $var, $snd, $both;
	}

	is_deeply [scope_check 'A'],      ['A', 'A2', 'A and A2'];
	is_deeply [scope_check 'B', 'C'], ['B', 'C', 'B and C'];
	is_deeply [scope_check 4, 5, 6],  [4, 5, 6];

	is eval('fun ($QQQ = $QQQ) {}; 1'), undef;
	like $@, qr/Global symbol.*\$QQQ.*explicit package name/;


	use Function::Parameters { method => 'method' };

	method mscope_check(
		$var,  # inner
		$snd = "${var}2",  # initialized from $var
		$both = "($self) $var and $snd",  # and $self!
	) {
		return $self, $var, $snd, $both;
	}

	is_deeply [mscope_check '$x', 'A'],      ['$x', 'A', 'A2', '($x) A and A2'];
	is_deeply [mscope_check '$x', 'B', 'C'], ['$x', 'B', 'C', '($x) B and C'];
	is_deeply [mscope_check '$x', 4, 5, 6],  ['$x', 4, 5, 6];
}
