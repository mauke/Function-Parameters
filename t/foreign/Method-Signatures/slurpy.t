#!perl

# Test slurpy parameters

use strict;
use warnings FATAL => 'all';

use Test::More;
#use Test::Exception;

{
    package Stuff;
    use Function::Parameters qw(:strict);
    use Test::More;

    method slurpy(@that) { return \@that }
    method slurpy_required(@that) { return \@that }
    method slurpy_last($this, @that) { return $this, \@that; }

    ok !eval q[fun slurpy_first(@that, $this) { return $this, \@that; }];
    like $@, qr{\$this\b.+\@that\b};
#    TODO: {
#        local $TODO = "error message incorrect inside an eval";

#        like $@, qr{Stuff::};
        like $@, qr{\bslurpy_first\b};
#    }

    ok !eval q[fun slurpy_middle($this, @that, $other) { return $this, \@that, $other }];
    like $@, qr{\$other\b.+\@that\b};
#    TODO: {
#        local $TODO = "error message incorrect inside an eval";

#        like $@, qr{Stuff::};
        like $@, qr{\bslurpy_middle\b};
#    }

    ok !eval q[fun slurpy_positional(:@that) { return \@that; }];
    like $@, qr{\bnamed\b.+\@that\b.+\barray\b};

#    TODO: {
#        local $TODO = "error message incorrect inside an eval";

#        like $@, qr{Stuff::};
        like $@, qr{\bslurpy_positional\b};
#    }

    ok !eval q[fun slurpy_two($this, @that, @other) { return $this, \@that, \@other }];
    like $@, qr{\@other\b.+\@that\b};
}


note "Optional slurpy params accept 0 length list"; {
    is_deeply [Stuff->slurpy()], [[]];
    is_deeply [Stuff->slurpy_last(23)], [23, []];
}

#note "Required slurpy params require an argument"; {
#    throws_ok { Stuff->slurpy_required() }
#      qr{slurpy_required\Q()\E, missing required argument \@that at \Q$0\E line @{[__LINE__ - 1]}};
#}


done_testing;
