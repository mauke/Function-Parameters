#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 26;

use Function::Parameters qw(:strict);

fun foo_r($depth, $fst, $snd) {
	return [$fst, $snd, $snd - $fst] if $depth <= 0;
	$fst++;
	my $thd = foo_r $depth - 1, $fst + $snd, $fst * $snd;
	$snd++;
	return [$fst, $snd, $thd];
}

fun foo_o($depth, $fst = 1, $snd = 2) {
	return [$fst, $snd, $snd - $fst] if $depth <= 0;
	$fst++;
	my $thd = foo_o $depth - 1, $fst + $snd, $fst * $snd;
	$snd++;
	return [$fst, $snd, $thd];
}

fun foo_nr(:$depth, :$fst, :$snd) {
	return [$fst, $snd, $snd - $fst] if $depth <= 0;
	$fst++;
	my $thd = foo_nr snd => $fst * $snd, depth => $depth - 1, fst => $fst + $snd;
	$snd++;
	return [$fst, $snd, $thd];
}

fun foo_no(:$depth, :$fst = 1, :$snd = 2) {
	return [$fst, $snd, $snd - $fst] if $depth <= 0;
	$fst++;
	my $thd = foo_no snd => $fst * $snd, depth => $depth - 1, fst => $fst + $snd;
	$snd++;
	return [$fst, $snd, $thd];
}

for my $f (
	\&foo_r, \&foo_o,
	map { my $f = $_; fun ($d, $x, $y) { $f->(depth => $d, snd => $y, fst => $x) } }
	\&foo_nr, \&foo_no
) {
	is_deeply $f->(0, 3, 5), [3, 5, 2];
	is_deeply $f->(1, 3, 5), [4, 6, [9, 20, 11]];
	is_deeply $f->(2, 3, 5), [4, 6, [10, 21, [30, 200, 170]]];
}

fun slurpy(:$n, %rest) { [$n, \%rest] }

{
	is_deeply slurpy(a => 1, b => 2, n => 9), [9, {a => 1, b => 2}];
	my $sav1 = slurpy(n => 5);
	is_deeply $sav1, [5, {}];
	my $sav2 = slurpy(n => 6, a => 3);
	is_deeply $sav2, [6, {a => 3}];
	is_deeply $sav1, [5, {}];
	is_deeply slurpy(b => 4, n => 7, hello => "world"), [7, {hello => "world", b => 4}];
	is_deeply $sav1, [5, {}];
	is_deeply $sav2, [6, {a => 3}];
}

{
	{
		package TimelyDestruction;

		method new($class: $f) {
			bless {on_destroy => $f}, $class
		}

		method DESTROY {
			$self->{on_destroy}();
		}
	}

	use Function::Parameters; # lax

	fun bar(:$n) { defined $n ? $n + 1 : "nope" }

	is bar(n => undef), "nope";
	is bar(n => 2), 3;
	is bar, "nope";

	my $dead = 0;
	{
		my $o = TimelyDestruction->new(fun () { $dead++ });
		is bar(n => $o), $o + 1, "this juice is bangin yo";
	}
	is $dead, 1;
	$dead = 999;
	is bar(n => 3), 4;
	is $dead, 999;
}
