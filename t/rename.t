use strict;
use warnings;
use Test::More;

use Function::Parameters 'f';

my $add = f ($x, $y) { $x + $y };

is $add->(2, 4), 6;

ok !eval { Function::Parameters->import('g', 'h'); 1 };
like $@, qr/ is not exported /;

for my $kw ('', '42', 'A::B', 'a b') {
	ok !eval{ Function::Parameters->import($kw); 1 };
	like $@, qr/valid identifier /;
}

done_testing;
