#!perl
use strict;
use warnings FATAL => 'all';
use Test::More
    eval { require Moose; require aliased }
    ? (tests => 2)
    : (skip_all => "Moose, aliased required for testing types")
;
use Test::Fatal;

use Dir::Self;
use lib __DIR__ . '/lib';

{
    package TestClass;
    use Moose;
    use Function::Parameters qw(:strict);

    use aliased 'My::Annoyingly::Long::Name::Space', 'Shortcut';

    ::is(::exception { method alias_sig ((Shortcut) $affe) { } },
        undef, 'method with aliased type constraint compiles');
}

my $o = TestClass->new;
my $affe = My::Annoyingly::Long::Name::Space->new;

is(exception {
    $o->alias_sig($affe);
}, undef, 'calling method with aliased type constraint');

