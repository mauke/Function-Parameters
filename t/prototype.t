#!perl
use Test::More tests => 52;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

is eval 'fun :([) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(][[[[[[) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(\;) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\[_;@]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\+) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :(\\\\) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :([$]) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :(\[_$]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

{
    no warnings qw(illegalproto);

    ok eval 'fun :([) {}';
    ok eval 'fun :(][[[[[[) {}';
    ok eval 'fun :(\;) {}';
    ok eval 'fun :(\[_;@]) {}';
    ok eval 'fun :(\+) {}';
    ok eval 'fun :(\\\\) {}';
    ok eval 'fun :([$]) {}';
    ok eval 'fun :(\[_$]) {}';
}

is eval 'fun :prototype([) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :prototype(][[[[[[) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :prototype(\;) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :prototype(\[_;@]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :prototype(\+) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :prototype(\\\\) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

is eval 'fun :prototype([$]) {}', undef;
like $@, qr/Illegal character in prototype/;

is eval 'fun :prototype(\[_$]) {}', undef;
like $@, qr/Illegal character after '\\' in prototype/;

{
    no warnings qw(illegalproto);

    ok eval 'fun :prototype([) {}';
    ok eval 'fun :prototype(][[[[[[) {}';
    ok eval 'fun :prototype(\;) {}';
    ok eval 'fun :prototype(\[_;@]) {}';
    ok eval 'fun :prototype(\+) {}';
    ok eval 'fun :prototype(\\\\) {}';
    ok eval 'fun :prototype([$]) {}';
    ok eval 'fun :prototype(\[_$]) {}';
}

is eval 'fun :($) prototype(@) {}', undef;
like $@, qr/Can't redefine prototype/;

is eval 'fun :prototype($) prototype(@) {}', undef;
like $@, qr/Can't redefine prototype/;
