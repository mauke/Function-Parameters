#!perl
use Test::More
    eval { require threads; threads->import; 1 }
        ? (tests => 1)
        : (skip_all => "threads required for testing threads");

use warnings FATAL => 'all';
use strict;

use threads::shared;

my $nthreads = 5;

my $xvar :shared = 0;

for my $t (1 .. $nthreads) {
    threads->create(sub {
        lock $xvar;
        $xvar++;
        cond_wait $xvar while $xvar >= 0;
        require Function::Parameters;
    });
}

{
    threads->yield;
    lock $xvar;
    if ($xvar < $nthreads) {
        redo;
    }

    $xvar = -1;
    cond_broadcast $xvar;
}

$_->join for threads->list;

pass "we haven't crashed yet";
