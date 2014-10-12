#!perl

use Test::More tests => 13;

use warnings FATAL => 'all';
use strict;

use Function::Parameters qw(:strict);

fun foo_1($x = ) { [ $x ] }
fun foo_2($x=)   { [ $x ] }
fun foo_3($x =, $y =)      { [ $x, $y ] }
fun foo_4($x = 'hi', $y= ) { [ $x, $y ] }
fun foo_5($x= , $y='hi')   { [ $x, $y ] }

is_deeply foo_1(),     [ undef ];
is_deeply foo_1('aa'), [ 'aa' ];
is_deeply foo_2(),     [ undef ];
is_deeply foo_2('aa'), [ 'aa' ];
is_deeply foo_3(),           [ undef, undef ];
is_deeply foo_3('aa'),       [ 'aa', undef ];
is_deeply foo_3('aa', 'bb'), [ 'aa', 'bb' ];
is_deeply foo_4(),           [ 'hi', undef ];
is_deeply foo_4('aa'),       [ 'aa', undef ];
is_deeply foo_4('aa', 'bb'), [ 'aa', 'bb' ];
is_deeply foo_5(),           [ undef, 'hi' ];
is_deeply foo_5('aa'),       [ 'aa', 'hi' ];
is_deeply foo_5('aa', 'bb'), [ 'aa', 'bb' ];
