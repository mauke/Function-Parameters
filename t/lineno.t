use warnings;
use strict;

use Test::More tests => 8;

use Function::Parameters;

fun actual_location_of_line_with($marker) {
	seek DATA, 0, 0 or die "seek DATA: $!";
	my $loc = 0;
	while (my $line = readline DATA) {
		$loc++;
		index($line, $marker) >= 0
			and return $loc;
	}
	undef
}

fun test_loc($marker) {
	my $expected = actual_location_of_line_with $marker;
	defined $expected or die "$marker: something done fucked up";
	my $got = (caller)[2];
	is $got, $expected, "location of '$marker'";
}

fun () {
	test_loc 'LX simple';
}->();

test_loc 'LX -- 1';

fun 
 (
   )
     {
	test_loc 'LX creative formatting'; }
->
(
 );

test_loc 'LX -- 2';

fun () {
	fun () {
		test_loc 'LX nested';
	}->()
}->();

test_loc 'LX -- 3';

TODO: {
	local $TODO = 'expressions break line numbers???';

	0
	, fun {
			test_loc 'LX assign';
		}->()
	;

	test_loc 'LX -- 4';
}

__DATA__
