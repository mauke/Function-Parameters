#!perl
use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;

use Function::Parameters;

is eval 'fun {}', undef;
like $@, qr/\A\QIn fun (anon): I was expecting a parameter list, not "{"/;

is eval 'fun () :() {}', undef;
like $@, qr/\A\QIn fun (anon): I was expecting a function body, not "("/;
