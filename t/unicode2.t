#!perl
use utf8;
use Test::More tests => 25;

use warnings FATAL => 'all';
use strict;

use Function::Parameters { pŕöç => 'function_strict' };

pŕöç hörps($x) { $x * 2 }
pŕöç drau($spın̈al_tap) { $spın̈al_tap * 3 }
pŕöç ääää($éééééé) { $éééééé * 4 }

is hörps(10), 20;
is drau(11), 33;
is ääää(12), 48;

is eval('pŕöç á(){} 1'), 1;
is á(), undef;

is eval('pŕöç ́(){} 1'), undef;
like $@, qr/pŕöç.* function body/s;

is eval(q<pŕöç 'hi(){} 1>), undef;
like $@, qr/pŕöç.* function body/s;

is eval('pŕöç ::hi($z){} 1'), 1;
is hi(42), undef;

is eval('pŕöç 123(){} 1'), undef;
like $@, qr/pŕöç.* function body/s;

is eval('pŕöç main::234(){} 1'), undef;
like $@, qr/pŕöç.* function body/s;

is eval('pŕöç m123($z){} 1'), 1;
is m123(42), undef;

is eval('pŕöç ::m234($z){} 1'), 1;
is m234(42), undef;

is eval { ääää }, undef;
like $@, qr/pŕöç.*ääää/s;

SKIP: {
    eval { require Moo } or skip "info requires Moo", 4;

    for my $info (Function::Parameters::info \&ääää) {
        is $info->keyword, 'pŕöç';
        is join(' ', $info->positional_required), '$éééééé';
    }

    for my $info (Function::Parameters::info \&drau) {
        is $info->keyword, 'pŕöç';
        is join(' ', $info->positional_required), '$spın̈al_tap';
    }
}
