#!perl
use warnings FATAL => 'all';
no warnings qw(once redefine);
use strict;

use Test::More tests => 2;

use Function::Parameters {
	method => { defaults => 'method_strict', runtime => 1 },
};

# See commit 978a498e17ec54b6f1fc65f3375a62a68f321f99 in perl

method Y::b() { 'b' }
*X::b = *Y::b;
@Z::ISA = 'X';
is +Z->b, 'b';

method Y::b() { 'c' }
is +Z->b, 'c';
