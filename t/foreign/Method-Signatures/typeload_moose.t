#!perl

use strict;
use warnings FATAL => 'all';
use Dir::Self;
use lib __DIR__ . '/lib';

use Test::More
	eval { require Moose; 1 }
	? (tests => 2)
	: (skip_all => "Moose required for testing types")
;


require MooseLoadTest;

my $foobar = Foo::Bar->new;

# can't check for type module not being loaded here, because Moose will drag it in


$foobar->check_int(42);

# now we should have loaded Moose, not Mouse, to do our type checking

is $INC{'Mouse/Util/TypeConstraints.pm'}, undef, "didn't load Mouse";
like $INC{'Moose/Util/TypeConstraints.pm'}, qr{Moose/Util/TypeConstraints\.pm$}, 'loaded Moose';
