#!perl

use Test::More tests => 120;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
	method => {
		check_argument_count => 1,
		shift => '$self',
		attrs => ':method',
	},

	cathod => {
		check_argument_count => 0,
		shift => '$self',
		attrs => ':method',
	},

	fun => 'function',
};

fun error_like($re, $body, $name = undef) {
	local $@;
	ok !eval { $body->(); 1 };
	like $@, $re, $name;
}

method foo_any { [@_] }
method foo_any_a(@args) { [@args] }
method foo_any_b($x = undef, @rest) { [@_] }
method foo_0() { [@_] }
method foo_1($x) { [@_] }
method foo_2($x, $y) { [@_] }
method foo_3($x, $y, $z) { [@_] }
method foo_0_1($x = 'D0') { [$x] }
method foo_0_2($x = 'D0', $y = 'D1') { [$x, $y] }
method foo_0_3($x = 'D0', $y, $z = 'D2') { [$x, $y, $z] }
method foo_1_2($x, $y = 'D1') { [$x, $y] }
method foo_1_3($x, $y = 'D1', $z = 'D2') { [$x, $y, $z] }
method foo_2_3($x, $y, $z = 'D2') { [$x, $y, $z] }
method foo_1_($x, @y) { [@_] }

error_like qr/Not enough arguments.*foo_any/, sub { foo_any };
is_deeply foo_any('a'), [];
is_deeply foo_any('a', 'b'), ['b'];
is_deeply foo_any('a', 'b', 'c'), ['b', 'c'];
is_deeply foo_any('a', 'b', 'c', 'd'), ['b', 'c', 'd'];

error_like qr/Not enough arguments.*foo_any_a/, sub { foo_any_a };
is_deeply foo_any_a('a'), [];
is_deeply foo_any_a('a', 'b'), ['b'];
is_deeply foo_any_a('a', 'b', 'c'), ['b', 'c'];
is_deeply foo_any_a('a', 'b', 'c', 'd'), ['b', 'c', 'd'];

error_like qr/Not enough arguments.*foo_any_b/, sub { foo_any_b };
is_deeply foo_any_b('a'), [];
is_deeply foo_any_b('a', 'b'), ['b'];
is_deeply foo_any_b('a', 'b', 'c'), ['b', 'c'];
is_deeply foo_any_b('a', 'b', 'c', 'd'), ['b', 'c', 'd'];

error_like qr/Not enough arguments.*foo_0/, sub { foo_0 };
is_deeply foo_0('a'), [];
error_like qr/Too many arguments.*foo_0/, sub { foo_0 'a', 'b' };
error_like qr/Too many arguments.*foo_0/, sub { foo_0 'a', 'b', 'c' };
error_like qr/Too many arguments.*foo_0/, sub { foo_0 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_1/, sub { foo_1 };
error_like qr/Not enough arguments.*foo_1/, sub { foo_1 'a' };
is_deeply foo_1('a', 'b'), ['b'];
error_like qr/Too many arguments.*foo_1/, sub { foo_1 'a', 'b', 'c' };
error_like qr/Too many arguments.*foo_1/, sub { foo_1 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_2/, sub { foo_2 };
error_like qr/Not enough arguments.*foo_2/, sub { foo_2 'a' };
error_like qr/Not enough arguments.*foo_2/, sub { foo_2 'a', 'b' };
is_deeply foo_2('a', 'b', 'c'), ['b', 'c'];
error_like qr/Too many arguments.*foo_2/, sub { foo_2 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_3/, sub { foo_3 };
error_like qr/Not enough arguments.*foo_3/, sub { foo_3 'a' };
error_like qr/Not enough arguments.*foo_3/, sub { foo_3 'a', 'b' };
error_like qr/Not enough arguments.*foo_3/, sub { foo_3 'a', 'b', 'c' };
is_deeply foo_3('a', 'b', 'c', 'd'), ['b', 'c', 'd'];
error_like qr/Too many arguments.*foo_3/, sub { foo_3 'a', 'b', 'c', 'd', 'e' };

error_like qr/Not enough arguments.*foo_0_1/, sub { foo_0_1 };
is_deeply foo_0_1('a'), ['D0'];
is_deeply foo_0_1('a', 'b'), ['b'];
error_like qr/Too many arguments.*foo_0_1/, sub { foo_0_1 'a', 'b', 'c' };
error_like qr/Too many arguments.*foo_0_1/, sub { foo_0_1 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_0_2/, sub { foo_0_2 };
is_deeply foo_0_2('a'), ['D0', 'D1'];
is_deeply foo_0_2('a', 'b'), ['b', 'D1'];
is_deeply foo_0_2('a', 'b', 'c'), ['b', 'c'];
error_like qr/Too many arguments.*foo_0_2/, sub { foo_0_2 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_0_3/, sub { foo_0_3 };
is_deeply foo_0_3('a'), ['D0', undef, 'D2'];
is_deeply foo_0_3('a', 'b'), ['b', undef, 'D2'];
is_deeply foo_0_3('a', 'b', 'c'), ['b', 'c', 'D2'];
is_deeply foo_0_3('a', 'b', 'c', 'd'), ['b', 'c', 'd'];
error_like qr/Too many arguments.*foo_0_3/, sub { foo_0_3 'a', 'b', 'c', 'd', 'e' };

error_like qr/Not enough arguments.*foo_1_2/, sub { foo_1_2 };
error_like qr/Not enough arguments.*foo_1_2/, sub { foo_1_2 'a' };
is_deeply foo_1_2('a', 'b'), ['b', 'D1'];
is_deeply foo_1_2('a', 'b', 'c'), ['b', 'c'];
error_like qr/Too many arguments.*foo_1_2/, sub { foo_1_2 'a', 'b', 'c', 'd' };

error_like qr/Not enough arguments.*foo_1_3/, sub { foo_1_3 };
error_like qr/Not enough arguments.*foo_1_3/, sub { foo_1_3 'a' };
is_deeply foo_1_3('a', 'b'), ['b', 'D1', 'D2'];
is_deeply foo_1_3('a', 'b', 'c'), ['b', 'c', 'D2'];
is_deeply foo_1_3('a', 'b', 'c', 'd'), ['b', 'c', 'd'];
error_like qr/Too many arguments.*foo_1_3/, sub { foo_1_3 'a', 'b', 'c', 'd', 'e' };

error_like qr/Not enough arguments.*foo_2_3/, sub { foo_2_3 };
error_like qr/Not enough arguments.*foo_2_3/, sub { foo_2_3 'a' };
error_like qr/Not enough arguments.*foo_2_3/, sub { foo_2_3 'a', 'b' };
is_deeply foo_2_3('a', 'b', 'c'), ['b', 'c', 'D2'];
is_deeply foo_2_3('a', 'b', 'c', 'd'), ['b', 'c', 'd'];
error_like qr/Too many arguments.*foo_2_3/, sub { foo_2_3 'a', 'b', 'c', 'd', 'e' };

error_like qr/Not enough arguments.*foo_1_/, sub { foo_1_ };
error_like qr/Not enough arguments.*foo_1_/, sub { foo_1_ 'a' };
is_deeply foo_1_('a', 'b'), ['b'];
is_deeply foo_1_('a', 'b', 'c'), ['b', 'c'];
is_deeply foo_1_('a', 'b', 'c', 'd'), ['b', 'c', 'd'];


cathod puppy($eyes) { [@_] }
cathod frog($will, $never) { $will * 3 + (pop) - $never }

is_deeply puppy, [];
is_deeply puppy('a'), [];
is_deeply puppy('a', 'b'), ['b'];
is_deeply puppy('a', 'b', 'c'), ['b', 'c'];
is_deeply puppy('a', 'b', 'c', 'd'), ['b', 'c', 'd'];

is +main->frog(7, 4, 1), 18;
is +main->frog(7, 4), 21;
