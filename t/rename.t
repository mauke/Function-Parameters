use strict;
use warnings;
use Test::More;

use Function::Parameters 'f';

my $add = f ($x, $y) { $x + $y };

is $add->(2, 4), 6;

done_testing;
