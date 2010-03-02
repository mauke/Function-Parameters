use strict;
use warnings;
use Test::More;

use Function::Parameters ();

BEGIN { Function::Parameters::import_into __PACKAGE__; }

ok fun ($x) { $x }->(1);

BEGIN { Function::Parameters::import_into 'Cu::Ba', 'gorn'; }

{
	package Cu::Ba;

	gorn wooden ($gorn) { !$gorn }
}

ok Cu::Ba::wooden;

done_testing;
