#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Dir::Self;
use lib __DIR__ . "/lib";

use Test::More;
use Test::Fatal;

ok !eval { require BarfyDie };
TODO: {
    local $TODO = 'Types obscure earlier compilation errors';

    like $@, qr/requires explicit package name/,
      "MS doesn't interrupt real compilation error";
}

done_testing();
