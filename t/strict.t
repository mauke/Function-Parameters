use warnings;
use strict;

use Test::More tests => 8;

use Dir::Self;

for my $fail (
	map [__DIR__ . "/strict_$_->[0].fail", @$_[1 .. $#$_]],
	['1', qr/expect.*\).*after.*"\@y".*"\$z"/],
	['2', qr/expect.*\).*after.*"\@x".*"\$y"/],
	['3', qr/expect.*\).*after.*"%y".*"\$z"/],
	['4', qr/expect.*\).*after.*"\@y".*"\@z"/],
) {
	my ($file, $pat) = @$fail;
	$@ = undef;
	my $done = do $file;
	my $exc = $@;
	my $err = $!;

	is $done, undef, "faulty code doesn't load";
	$exc or die "$file: $err" if $err;
	like $exc, $pat;
}
