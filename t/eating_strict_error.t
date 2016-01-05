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
    like $exc, qr{^Global symbol "\$records" requires explicit package name.* at \Q$file\E line \Q$line.\E\n};
    $exc or die "$file: $err";
}
