#!perl

use Test::More tests => 4;

use warnings FATAL => 'all';
use strict;

use Dir::Self;

for my $thing (map [__DIR__ . "/eating_strict_error$_->[0].fail", @$_[1 .. $#$_]], ['', 6], ['_2', 9]) {
	my ($file, $line) = @$thing;
	$@ = undef;
	my $done = do $file;
	my $exc = $@;
	my $err = $!;

	is $done, undef, "faulty code doesn't load";
	my $msg = qq{Global symbol "\$records" requires explicit package name at $file line $line.\n};
	like $exc, qr{^\Q$msg};
	$exc or die "$file: $err";
}
