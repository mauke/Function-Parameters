#!perl
use strict;
use warnings FATAL => 'all';

use Dir::Self;
use lib __DIR__ . "/lib";

use Test::More do {
    # Trying to load modules (for parameter types) after a syntax error can
    # fail, hiding the real error message. To properly test this, we need to
    # know Moose is available but we can't load it up front.
    my $have_moose;
    for my $dir (@INC) {
        if (-r "$dir/Moose/Util/TypeConstraints.pm") {
            $have_moose = 1;
            last;
        }
    }
    $have_moose
    ? ()
    : (skip_all => "Moose required for testing types")
};
use Test::Fatal;

like exception { require BarfyDie },
  qr/requires explicit package name/,
  "F:P doesn't interrupt real compilation error";

done_testing();
