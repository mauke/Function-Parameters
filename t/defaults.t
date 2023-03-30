#!perl
use strict;
use warnings qw(all FATAL uninitialized);
use Test::More tests => 106;

use Function::Parameters {
    fun => {
        default_arguments => 1,
    },

    nofun => {
        default_arguments => 0,
    },
};

fun foo0($x, $y = 1, $z = 3) { $x * 5 + $y * 2 + $z }

is foo0(10), 55;
is foo0(5, -2), 24;
is foo0(6, 10, 1), 51;

fun foo1($x, $y //= 1, $z //= 3) { $x * 5 + $y * 2 + $z }
is foo1(10), 55;
is foo1(10, undef), 55;
is foo1(10, undef, undef), 55;
is foo1(5, -2), 24;
is foo1(5, -2, undef), 24;
is foo1(6, 10, 1), 51;

is fun ($answer = 42) { $answer }->(), 42;
is fun ($answer //= 42) { $answer }->(), 42;
is fun ($answer //= 42) { $answer }->(undef), 42;

fun sharingan0($input, $x = [], $y = {}) {
    push @$x, $input;
    $y->{$#$x} = $input;
    $x, $y
}

{
    is_deeply [sharingan0 'e'], [['e'], {0 => 'e'}];
    my $sneaky = ['ants'];
    is_deeply [sharingan0 $sneaky], [[['ants']], {0 => ['ants']}];
    unshift @$sneaky, 'thanks';
    is_deeply [sharingan0 $sneaky], [[['thanks', 'ants']], {0 => ['thanks', 'ants']}];
    @$sneaky = 'thants';
    is_deeply [sharingan0 $sneaky], [[['thants']], {0 => ['thants']}];
}

fun sharingan1($input, $x //= [], $y //= {}) {
    push @$x, $input;
    $y->{$#$x} = $input;
    $x, $y
}

{
    is_deeply [sharingan1 'e', undef, undef], [['e'], {0 => 'e'}];
    my $sneaky = ['ants'];
    is_deeply [sharingan1 $sneaky, undef], [[['ants']], {0 => ['ants']}];
    unshift @$sneaky, 'thanks';
    is_deeply [sharingan1 $sneaky], [[['thanks', 'ants']], {0 => ['thanks', 'ants']}];
    @$sneaky = 'thants';
    is_deeply [sharingan1 $sneaky, undef, undef], [[['thants']], {0 => ['thants']}];
}

is eval('fun ($x, $y = $powersauce) {}'), undef;
like $@, qr/^Global symbol.*explicit package name/;
is eval('fun ($x, $y //= $powersauce) {}'), undef;
like $@, qr/^Global symbol.*explicit package name/;

{
    my $d = 'outer';
    my $f;
    {
        my $d = 'herp';
        fun guy($d = $d, $x = $d . '2') {
            return [$d, $x];
        }

        is_deeply guy('a', 'b'), ['a', 'b'];
        is_deeply guy('c'), ['c', 'c2'];
        is_deeply guy, ['herp', 'herp2'];

        $d = 'ort';
        is_deeply guy('a', 'b'), ['a', 'b'];
        is_deeply guy('c'), ['c', 'c2'];
        is_deeply guy, ['ort', 'ort2'];

        my $g = fun ($alarum = $d) { "[$alarum]" };
        is $g->(""), "[]";
        is $g->(), "[ort]";

        $d = 'flowerpot';
        is_deeply guy('bloodstain'), ['bloodstain', 'bloodstain2'];
        is $g->(), "[flowerpot]";

        $f = $g;
    }

    is $f->(), "[flowerpot]";
    is $f->("Q"), "[Q]";
}

{
    my $c = 0;
    fun edelweiss($x = $c++) :prototype(;$) { $x }
}

is edelweiss "AAAAA", "AAAAA";
is_deeply edelweiss [], [];
is edelweiss, 0;
is edelweiss, 1;
is_deeply edelweiss {}, {};
is edelweiss 0, 0;
is edelweiss, 2;

for my $f (fun ($wtf = return 'ohi') { "~$wtf" }) {
    is $f->(""), "~";
    is $f->("a"), "~a";
    is $f->(), "ohi";
}

for my $f (fun ($wtf //= return 'ohi') { "~$wtf" }) {
    is $f->(""), "~";
    is $f->("a"), "~a";
    is $f->(undef), "ohi";
    is $f->(), "ohi";
}

is eval('fun (@x = 42) {}'), undef;
like $@, qr/default value/;

is eval('fun ($x, %y = ()) {}'), undef;
like $@, qr/default value/;

is eval('nofun ($x = 42) {}'), undef;
like $@, qr/nofun.*default argument/;

is eval('fun (@x //= 42) {}'), undef;
like $@, qr/default value/;

is eval('fun ($x, %y //= ()) {}'), undef;
like $@, qr/default value/;

is eval('nofun ($x //= 42) {}'), undef;
like $@, qr/nofun.*default argument/;


{
    my $var = "outer";

    fun scope_check(
        $var,  # inner
        $snd = "${var}2",  # initialized from $var)
        $both = "$var and $snd",
    ) {
        return $var, $snd, $both;
    }

    is_deeply [scope_check 'A'],      ['A', 'A2', 'A and A2'];
    is_deeply [scope_check 'B', 'C'], ['B', 'C', 'B and C'];
    is_deeply [scope_check 4, 5, 6],  [4, 5, 6];

    is eval('fun ($QQQ = $QQQ) {}; 1'), undef;
    like $@, qr/Global symbol.*\$QQQ.*explicit package name/;

    is eval('fun ($QQQ //= $QQQ) {}; 1'), undef;
    like $@, qr/Global symbol.*\$QQQ.*explicit package name/;


    use Function::Parameters { method => 'method' };

    method mscope_check(
        $var,  # inner
        $snd = "${var}2",  # initialized from $var
        $both = "($self) $var and $snd",  # and $self!
    ) {
        return $self, $var, $snd, $both;
    }

    is_deeply [mscope_check '$x', 'A'],      ['$x', 'A', 'A2', '($x) A and A2'];
    is_deeply [mscope_check '$x', 'B', 'C'], ['$x', 'B', 'C', '($x) B and C'];
    is_deeply [mscope_check '$x', 4, 5, 6],  ['$x', 4, 5, 6];
}

{
    my @extra;
    my $f = fun (
        $p0,
        $p1 //= 'd1',
        $p2 = 'd2',
        $p3 = 'd3',
        $p4 = (push(@extra, 'x4'), 'd4'),
        $p5 //= 'd5',
        $p6 = 'd6',
        $ = push(@extra, 'x7'),
        $p8 = 'd8',
        $ //= push(@extra, 'x9'),
    ) {
        [ $p0, $p1, $p2, $p3, $p4, $p5, $p6, $p8 ]
    };

    is_deeply [$f->(undef), [splice @extra]], [[undef, 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0'), [splice @extra]], [['a0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', undef), [splice @extra]], [['a0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1'), [splice @extra]], [['a0', 'a1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1', undef), [splice @extra]], [['a0', 'a1', undef, 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2'), [splice @extra]], [['a0', 'a1', 'a2', 'd3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', undef), [splice @extra]], [['a0', 'a1', 'a2', undef, 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'd4', 'd5', 'd6', 'd8'], ['x4', 'x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', undef, 'd5', 'd6', 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'd5', 'd6', 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'd5', 'd6', 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'd6', 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', undef, 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'd8'], ['x7', 'x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'd8'], ['x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'd8'], ['x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', undef], ['x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a8'], ['x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a8'], ['x9']];
    is_deeply [$f->('a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a8'], []];
    is_deeply [$f->(undef, 'a1', undef, 'a3', undef, 'a5', undef, 'a7', undef, 'a9'), [splice @extra]], [[undef, 'a1', undef, 'a3', undef, 'a5', undef, undef], []];
    is_deeply [$f->('a0', undef, 'a2', undef, 'a4', undef, 'a6', undef, 'a8', undef), [splice @extra]], [['a0', 'd1', 'a2', undef, 'a4', 'd5', 'a6', 'a8'], ['x9']];
}

{
    my @extra;
    my $f = fun (
        :$p0,
        :$p1 //= 'd1',
        :$p2 = 'd2',
        :$p3 //= (push(@extra, 'x3'), 'd3'),
        :$p4 = (push(@extra, 'x4'), 'd4'),
    ) {
        [ $p0, $p1, $p2, $p3, $p4 ]
    };

    is_deeply [$f->(p0 => undef), [splice @extra]], [[undef, 'd1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0'), [splice @extra]], [['a0', 'd1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0', p1 => undef), [splice @extra]], [['a0', 'd1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p1 => 'a1', p0 => 'a0'), [splice @extra]], [['a0', 'a1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p1 => undef, p0 => 'a0', p1 => 'a1'), [splice @extra]], [['a0', 'a1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p1 => 'a1', p0 => 'a0', p1 => undef), [splice @extra]], [['a0', 'd1', 'd2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => undef), [splice @extra]], [['a0', 'a1', undef, 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => 'a2'), [splice @extra]], [['a0', 'a1', 'a2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => 'a2', p3 => undef), [splice @extra]], [['a0', 'a1', 'a2', 'd3', 'd4'], ['x3', 'x4']];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => 'a2', p3 => 'a3'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'd4'], ['x4']];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => 'a2', p3 => 'a3', p4 => undef), [splice @extra]], [['a0', 'a1', 'a2', 'a3', undef], []];
    is_deeply [$f->(p0 => 'a0', p1 => 'a1', p2 => 'a2', p3 => 'a3', p4 => 'a4'), [splice @extra]], [['a0', 'a1', 'a2', 'a3', 'a4'], []];
}
