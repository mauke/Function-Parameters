#!perl

use Test::More tests => 3;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
	fun => {
		default_arguments => 1,
	},
};

{
	my ($d0, $d1, $d2, $d3);
	my $default = 'aaa';

	fun padness($x = $default++) {
		return $x;
	}

	is padness('unrelated'), 'unrelated';
	is &padness(), 'aaa';
	is padness, 'aab';
}
