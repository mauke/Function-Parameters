use strict;
use warnings;
use Test::More;

use Function::Parameters { f => 'function' };

my $add = f ($x, $y) { $x + $y };

is $add->(2, 4), 6;

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
