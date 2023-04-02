#!perl
use strict;
use warnings;
use Test::More;

use MooseX::Types ();

pass "well, that worked";
diag $_ for @INC;
diag "-" x 120;
diag "$_ => $INC{$_}" for sort keys %INC;

done_testing;
