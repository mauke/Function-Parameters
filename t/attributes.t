#!perl

use Test::More tests => 10;

use warnings FATAL => 'all';
use strict;

use Function::Parameters {
    fun => 'function',
    method => 'method',
    elrond => {
        attributes => ':lvalue',
    },
};

is eval('use Function::Parameters { fun => { attributes => "nope" } }; 1'), undef;
like $@, qr/nope.*attributes/;

is eval('use Function::Parameters { fun => { attributes => ": in valid {" } }; 1'), undef;
like $@, qr/in valid.*attributes/;

elrond hobbard($ref) { $$ref }
{
    my $x = 1;
    hobbard(\$x) = 'bling';
    is $x, 'bling';

}
$_ = 'fool';
chop hobbard \$_;
is $_, 'foo';

{
    package BatCountry;

    fun join($group, $peer) {
        return "* $peer has joined $group";
    }

    ::is eval('join("left", "right")'), undef;
    ::like $@, qr/Ambiguous.*CORE::/;
}

{
    package CatCountry;

    method join($peer) {
        return "* $peer has joined $self->{name}";
    }

    ::is join('!', 'left', 'right'), 'left!right';

    my $obj = bless {name => 'kittens'};
    ::is $obj->join("twig"), "* twig has joined kittens";
}
