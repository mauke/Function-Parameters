#!perl

use strict;
use warnings FATAL => 'all';
use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Fatal;


SKIP:
{
    eval { require Moose } or skip "Moose required for testing Moose types", 1;

    require MooseLoadTest;

    my $foobar = Foo::Bar->new;

    # can't check for type module not being loaded here, because Moose will drag it in


    $foobar->check_int(42);

    # now we should have loaded Moose to do our type checking

    like $INC{'Moose/Util/TypeConstraints.pm'}, qr{Moose/Util/TypeConstraints\.pm$}, 'loaded Moose';


    # tests for ScalarRef[X] have to live here, because they only work with Moose

    my $method = 'check_paramized_sref';
    my $bad_ref = \'thing';
    is exception { $foobar->$method(\42) }, undef, 'call with good value for paramized_sref passes';
    like exception { $foobar->$method($bad_ref) },
            qr/\bcheck_paramized_sref\b.+\$bar\b.+ScalarRef\[Num\]/,
            'call with bad value for paramized_sref dies';
}


done_testing;
