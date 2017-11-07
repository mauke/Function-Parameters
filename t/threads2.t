#!perl
use Test::More
    eval { require threads; threads->import; 1 }
        ? (tests => 1)
        : (skip_all => "threads required for testing threads");

use warnings FATAL => 'all';
use strict;

for my $t (1 .. 2) {
    threads->create(sub {
        require Function::Parameters;
    });
}

pass "we didn't crash yet";

$_->join for threads->list;
