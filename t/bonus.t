#!perl

use Test::More tests => 13;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
	fun => {
		check_argument_count => 1,
	},
};

fun filter($f = fun ($x) { 1 }, @xs) {
	!@xs
		? ()
		: (($f->($xs[0]) ? $xs[0] : ()), filter $f, @xs[1 .. $#xs])
}

is_deeply [filter], [];
is_deeply [filter fun { 1 }, 2 .. 3], [2 .. 3];
is_deeply [filter fun ($x) { $x % 2 }, 1 .. 10], [1, 3, 5, 7, 9];

fun fact($k, $n) :(&$) {
	$n < 2
		? $k->(1)
		: fact { $k->($n * $_[0]) } $n - 1
}

is +(fact { "~@_~" } 5), "~120~";
is +(fact { $_[0] / 2 } 6), 360;

fun write_to($ref) :(\$) :lvalue { $$ref }

{
	my $x = 2;
	is $x, 2;
	write_to($x) = "hi";
	is $x, "hi";
	write_to($x)++;
	is $x, "hj";
}

{
	my $c = 0;
	fun horf_dorf($ref, $val = $c++) :(\@;$) :lvalue {
		push @$ref, $val;
		$ref->[-1]
	}
}

{
	my @asdf = "A";
	is_deeply \@asdf, ["A"];
	horf_dorf(@asdf) = "b";
	is_deeply \@asdf, ["A", "b"];
	++horf_dorf @asdf;
	is_deeply \@asdf, ["A", "b", 2];
	horf_dorf @asdf, 100;
	is_deeply \@asdf, ["A", "b", 2, 100];
	splice @asdf, 1, 1;
	horf_dorf(@asdf) *= 3;
	is_deeply \@asdf, ["A", 2, 100, 6];
}
