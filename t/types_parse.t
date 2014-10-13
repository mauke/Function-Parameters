#!perl
use warnings FATAL => 'all';
use strict;

use Test::More;

use Function::Parameters qw(:strict);

ok !eval 'fun foo(X[[';
like $@, qr/missing type name/;

done_testing;
