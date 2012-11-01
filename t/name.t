use warnings;
use strict;

use Test::More tests => 12;

use Dir::Self;

use Function::Parameters {
	func => {
		name => 'required',
	},

	f => {
		name => 'prohibited',
	},

	method => {
		name => 'required',
		shift => '$this',
	},
};

func foo($x, $y, $z) {
	$x .= $z;
	return $y . $x . $y;
}

method bar($k, $d) {
	$d = $k . $d;
	return $d . $this->{$k} . $d;
}

is foo('a', 'b', 'c'), 'bacb';
is bar({ab => 'cd'}, 'ab', 'e'), 'abecdabe';

my $baz = f ($x) { $x * 2 + 1 };
is $baz->(11), 23;
is $baz->(-0.5), 0;

for my $fail (
	map [__DIR__ . "/name_$_->[0].fail", @$_[1 .. $#$_]],
	['1', qr/expect.*function.*name/],
	['2', qr/expect.*function.*body/],
	['3', qr/expect.*function.*name/],
	['4', qr/Global symbol "\$self" requires explicit package name/]
) {
	my ($file, $pat) = @$fail;
	my $done = do $file;
	my $exc = $@;
	my $err = $!;

	is $done, undef, "faulty code doesn't load";
	$exc or die "$file: $err";
	like $exc, $pat;
}
