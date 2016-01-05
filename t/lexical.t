#!perl

use Test::More tests => 16;

use warnings FATAL => 'all';
use strict;

sub Burlap::fun (&) { $_[0]->() }

{
    use Function::Parameters;

    is fun { 2 + 2 }->(), 4;

    package Burlap;

    ::ok fun { 0 };
}

{
    package Burlap;

    ::is fun { 'singing' }, 'singing';
}

{
    sub proc (&) { &Burlap::fun }

    use Function::Parameters { proc => 'function' };

    proc add($x, $y) {
        return $x + $y;
    }

    is add(@{[2, 3]}), 5;

    {
        use Function::Parameters;

        is proc () { 'bla' }->(), 'bla';
        is method () { $self }->('der'), 'der';

        {
            no Function::Parameters;

            is proc { 'unk' }, 'unk';

            is eval('fun foo($x) { $x; } 1'), undef;
            like $@, qr/syntax error/;
        }

        is proc () { 'bla' }->(), 'bla';
        is method () { $self }->('der'), 'der';

        no Function::Parameters 'proc';
        is proc { 'unk2' }, 'unk2';
        is method () { $self }->('der2'), 'der2';
    }
    is proc () { 'bla3' }->(), 'bla3';
    is eval('fun foo($x) { $x; } 1'), undef;
    like $@, qr/syntax error/;
}
