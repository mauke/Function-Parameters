#!perl
use strict;
use warnings FATAL => 'all';

use Dir::Self;
use lib __DIR__ . "/lib";

use Test::More;
use Test::Fatal;

like exception { require BarfyDie },
  qr/requires explicit package name/,
  "F:P doesn't interrupt real compilation error";

done_testing();
