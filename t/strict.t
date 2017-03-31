use warnings;
use strict;

use Test::More tests => 10;

use Dir::Self;

for my $fail (
    map [__DIR__ . "/strict_$_->[0].fail", @$_[1 .. $#$_]],
    ['1', qr/"\$z" can't appear after slurpy parameter "\@y\"/],
    ['2', qr/"\$y" can't appear after slurpy parameter "\@x\"/],
    ['3', qr/"\$z" can't appear after slurpy parameter "%y\"/],
    ['4', qr/"\@z" can't appear after slurpy parameter "\@y\"/],
    ['5', qr/Invalid.*rarity/],
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
