#!perl

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;

use Dir::Self;
use lib __DIR__ . '/lib';

ok !eval { require Bad };
like $@, qr{^Global symbol "\$info" requires explicit package name}ms;

done_testing();
