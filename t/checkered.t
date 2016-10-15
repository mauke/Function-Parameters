#!perl

use Test::More tests => 108;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
    fun => {
        strict => 1,
    },

    sad => {
        strict => 0,
    },
};

fun error_like($re, $body, $name = undef) {
    local $@;
    ok !eval { $body->(); 1 };
    like $@, $re, $name;
}

fun foo_any(@) { [@_] }
fun foo_any_a(@args) { [@args] }
fun foo_any_b($x = undef, @rest) { [@_] }
fun foo_0() { [@_] }
fun foo_1($x) { [@_] }
fun foo_2($x, $y) { [@_] }
fun foo_3($x, $y, $z) { [@_] }
fun foo_0_1($x = 'D0') { [$x] }
fun foo_0_2($x = 'D0', $y = 'D1') { [$x, $y] }
fun foo_0_3($x = 'D0', $y = undef, $z = 'D2') { [$x, $y, $z] }
fun foo_1_2($x, $y = 'D1') { [$x, $y] }
fun foo_1_3($x, $y = 'D1', $z = 'D2') { [$x, $y, $z] }
fun foo_2_3($x, $y, $z = 'D2') { [$x, $y, $z] }
fun foo_1_($x, @y) { [@_] }

is_deeply foo_any, [];
is_deeply foo_any('a'), ['a'];
is_deeply foo_any('a', 'b'), ['a', 'b'];
is_deeply foo_any('a', 'b', 'c'), ['a', 'b', 'c'];
is_deeply foo_any('a', 'b', 'c', 'd'), ['a', 'b', 'c', 'd'];

is_deeply foo_any_a, [];
is_deeply foo_any_a('a'), ['a'];
is_deeply foo_any_a('a', 'b'), ['a', 'b'];
is_deeply foo_any_a('a', 'b', 'c'), ['a', 'b', 'c'];
is_deeply foo_any_a('a', 'b', 'c', 'd'), ['a', 'b', 'c', 'd'];

is_deeply foo_any_b, [];
is_deeply foo_any_b('a'), ['a'];
is_deeply foo_any_b('a', 'b'), ['a', 'b'];
is_deeply foo_any_b('a', 'b', 'c'), ['a', 'b', 'c'];
is_deeply foo_any_b('a', 'b', 'c', 'd'), ['a', 'b', 'c', 'd'];

is_deeply foo_0, [];
error_like qr/^Too many arguments.*foo_0/, fun () { foo_0 'a' };
error_like qr/^Too many arguments.*foo_0/, fun () { foo_0 'a', 'b' };
error_like qr/^Too many arguments.*foo_0/, fun () { foo_0 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_0/, fun () { foo_0 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_1/, fun () { foo_1 };
is_deeply foo_1('a'), ['a'];
error_like qr/^Too many arguments.*foo_1/, fun () { foo_1 'a', 'b' };
error_like qr/^Too many arguments.*foo_1/, fun () { foo_1 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_1/, fun () { foo_1 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_2/, fun () { foo_2 };
error_like qr/^Too few arguments.*foo_2/, fun () { foo_2 'a' };
is_deeply foo_2('a', 'b'), ['a', 'b'];
error_like qr/^Too many arguments.*foo_2/, fun () { foo_2 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_2/, fun () { foo_2 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_3/, fun () { foo_3 };
error_like qr/^Too few arguments.*foo_3/, fun () { foo_3 'a' };
error_like qr/^Too few arguments.*foo_3/, fun () { foo_3 'a', 'b' };
is_deeply foo_3('a', 'b', 'c'), ['a', 'b', 'c'];
error_like qr/^Too many arguments.*foo_3/, fun () { foo_3 'a', 'b', 'c', 'd' };

is_deeply foo_0_1, ['D0'];
is_deeply foo_0_1('a'), ['a'];
error_like qr/^Too many arguments.*foo_0_1/, fun () { foo_0_1 'a', 'b' };
error_like qr/^Too many arguments.*foo_0_1/, fun () { foo_0_1 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_0_1/, fun () { foo_0_1 'a', 'b', 'c', 'd' };

is_deeply foo_0_2, ['D0', 'D1'];
is_deeply foo_0_2('a'), ['a', 'D1'];
is_deeply foo_0_2('a', 'b'), ['a', 'b'];
error_like qr/^Too many arguments.*foo_0_2/, fun () { foo_0_2 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_0_2/, fun () { foo_0_2 'a', 'b', 'c', 'd' };

is_deeply foo_0_3, ['D0', undef, 'D2'];
is_deeply foo_0_3('a'), ['a', undef, 'D2'];
is_deeply foo_0_3('a', 'b'), ['a', 'b', 'D2'];
is_deeply foo_0_3('a', 'b', 'c'), ['a', 'b', 'c'];
error_like qr/^Too many arguments.*foo_0_3/, fun () { foo_0_3 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_1_2/, fun () { foo_1_2 };
is_deeply foo_1_2('a'), ['a', 'D1'];
is_deeply foo_1_2('a', 'b'), ['a', 'b'];
error_like qr/^Too many arguments.*foo_1_2/, fun () { foo_1_2 'a', 'b', 'c' };
error_like qr/^Too many arguments.*foo_1_2/, fun () { foo_1_2 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_1_3/, fun () { foo_1_3 };
is_deeply foo_1_3('a'), ['a', 'D1', 'D2'];
is_deeply foo_1_3('a', 'b'), ['a', 'b', 'D2'];
is_deeply foo_1_3('a', 'b', 'c'), ['a', 'b', 'c'];
error_like qr/^Too many arguments.*foo_1_3/, fun () { foo_1_3 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_2_3/, fun () { foo_2_3 };
error_like qr/^Too few arguments.*foo_2_3/, fun () { foo_2_3 'a' };
is_deeply foo_2_3('a', 'b'), ['a', 'b', 'D2'];
is_deeply foo_2_3('a', 'b', 'c'), ['a', 'b', 'c'];
error_like qr/^Too many arguments.*foo_2_3/, fun () { foo_2_3 'a', 'b', 'c', 'd' };

error_like qr/^Too few arguments.*foo_1_/, fun () { foo_1_ };
is_deeply foo_1_('a'), ['a'];
is_deeply foo_1_('a', 'b'), ['a', 'b'];
is_deeply foo_1_('a', 'b', 'c'), ['a', 'b', 'c'];
is_deeply foo_1_('a', 'b', 'c', 'd'), ['a', 'b', 'c', 'd'];


sad puppy($eyes) { [@_] }
sad frog($will, $never) { $will * 3 + (pop) - $never }

is_deeply puppy, [];
is_deeply puppy('a'), ['a'];
is_deeply puppy('a', 'b'), ['a', 'b'];
is_deeply puppy('a', 'b', 'c'), ['a', 'b', 'c'];
is_deeply puppy('a', 'b', 'c', 'd'), ['a', 'b', 'c', 'd'];

is frog(7, 4, 1), 18;
is frog(7, 4), 21;
