use strict;
use warnings;
use Test::More;

use Function::Parameters 'f';

my $add = f ($x, $y) { $x + $y };

is $add->(2, 4), 6;

ok !eval { Function::Parameters->import('g', 'h', 'i'); 1 };

for my $kw ('', '42', 'A::B', 'a b') {
	ok !eval{ Function::Parameters->import($kw); 1 };
	like $@, qr/valid identifier /;
}

use Function::Parameters 'func_a', 'meth_a';

func_a cat_a($x, $y) {
	$x . $y
}

meth_a tac_a($x) {
	$x . $self
}

is cat_a('ab', 'cde'), 'abcde';
is tac_a('ab', 'cde'), 'cdeab';

use Function::Parameters {
	meth_b => 'method',
	func_b => 'function',
};

func_b cat_b($x, $y) {
	$x . $y
}

meth_b tac_b($x) {
	$x . $self
}

is cat_b('ab', 'cde'), 'abcde';
is tac_b('ab', 'cde'), 'cdeab';

done_testing;
