#!perl

use Test::More tests => 2;

use warnings FATAL => 'all';
use strict;

use Dir::Self;

#use Test::Fatal;

my $file = __DIR__ . "/eating_strict_error.fail";
my $done = do $file;
my $exc = $@;
my $err = $!;

is $done, undef, "faulty code doesn't load";
is $exc, qq{Global symbol "\$records" requires explicit package name at $file line 5.\nBEGIN not safe after errors--compilation aborted at $file line 9.\n};
$exc or die "$file: $err";
