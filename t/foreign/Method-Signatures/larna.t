#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use Function::Parameters qw(:strict);;


ok eval q{ my $a = [ fun () {}, 1 ]; 1 }, 'anonymous function in list is okay'
        or diag "eval error: $@";

ok eval q{ my $a = [ method () {}, 1 ]; 1 }, 'anonymous method in list is okay'
        or diag "eval error: $@";


done_testing;
