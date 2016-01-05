#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 134;
use Test::Fatal;

use Function::Parameters qw(:strict);

sub compile_fail {
    my ($src, $re, $name) = @_;
    is eval $src, undef;
    like $@, $re, $name || ();
}


compile_fail 'fun (:$n1, $p1) {}', qr/\bpositional\b.+\bnamed\b/;
compile_fail 'fun (@rest, :$n1) {}', qr/\@rest\b.+\$n1\b/;
compile_fail 'fun (:$n1, :$n1) {}', qr/\$n1\b.+\btwice\b/;
compile_fail 'method (:$ni:) {}', qr/\binvocant\b.+\$ni\b.+\bnamed\b/;


fun name_1(:$n1) { [$n1, @_] }

like exception { name_1 }, qr/Too few arguments/;
like exception { name_1 'n1' }, qr/Too few arguments/;
like exception { name_1 'asdf' }, qr/Too few arguments/;
like exception { name_1 n1 => 0, huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_1(n1 => undef), [undef, n1 => undef];
is_deeply name_1(n1 => 'a'), ['a', n1 => 'a'];
is_deeply name_1(n1 => 'a', n1 => 'b'), ['b', n1 => 'a', n1 => 'b'];
is_deeply name_1(n1 => 'a', n1 => undef), [undef, n1 => 'a', n1 => undef];


fun name_0_1(:$n1 = 'd') { [$n1, @_] }

is_deeply name_0_1, ['d'];
like exception { name_0_1 'n1' }, qr/Odd number/;
like exception { name_0_1 'asdf' }, qr/Odd number/;
like exception { name_0_1 huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_0_1(n1 => 'a'), ['a', n1 => 'a'];
is_deeply name_0_1(n1 => 'a', n1 => 'b'), ['b', n1 => 'a', n1 => 'b'];
is_deeply name_0_1(n1 => 'a', n1 => undef), [undef, n1 => 'a', n1 => undef];


fun pos_1_name_1($p1, :$n1) { [$p1, $n1, @_] }

like exception { pos_1_name_1 }, qr/Too few arguments/;
like exception { pos_1_name_1 42 }, qr/Too few arguments/;
like exception { pos_1_name_1 42, 'n1' }, qr/Too few arguments/;
like exception { pos_1_name_1 42, 'asdf' }, qr/Too few arguments/;
like exception { pos_1_name_1 42, n1 => 0, huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply pos_1_name_1(42, n1 => undef), [42, undef, 42, n1 => undef];
is_deeply pos_1_name_1(42, n1 => 'a'), [42, 'a', 42, n1 => 'a'];
is_deeply pos_1_name_1(42, n1 => 'a', n1 => 'b'), [42, 'b', 42, n1 => 'a', n1 => 'b'];
is_deeply pos_1_name_1(42, n1 => 'a', n1 => undef), [42, undef, 42, n1 => 'a', n1 => undef];


compile_fail 'fun pos_0_1_name_1($p1 = "e", :$n1) { [$p1, $n1, @_] }', qr/\boptional positional\b.+\brequired named\b/;


fun pos_1_name_0_1($p1, :$n1 = 'd') { [$p1, $n1, @_] }

like exception { pos_1_name_0_1 }, qr/Too few arguments/;
is_deeply pos_1_name_0_1(42), [42, 'd', 42];
like exception { pos_1_name_0_1 42, 'n1' }, qr/Odd number/;
like exception { pos_1_name_0_1 42, 'asdf' }, qr/Odd number/;
like exception { pos_1_name_0_1 42, huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply pos_1_name_0_1(42, n1 => undef), [42, undef, 42, n1 => undef];
is_deeply pos_1_name_0_1(42, n1 => 'a'), [42, 'a', 42, n1 => 'a'];
is_deeply pos_1_name_0_1(42, n1 => 'a', n1 => 'b'), [42, 'b', 42, n1 => 'a', n1 => 'b'];
is_deeply pos_1_name_0_1(42, n1 => 'a', n1 => undef), [42, undef, 42, n1 => 'a', n1 => undef];


fun pos_0_1_name_0_1($p1 = 'e', :$n1 = 'd') { [$p1, $n1, @_] }

is_deeply pos_0_1_name_0_1, ['e', 'd'];
is_deeply pos_0_1_name_0_1(42), [42, 'd', 42];
like exception { pos_0_1_name_0_1 42, 'n1' }, qr/Odd number/;
like exception { pos_0_1_name_0_1 42, 'asdf' }, qr/Odd number/;
like exception { pos_0_1_name_0_1 42, huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply pos_0_1_name_0_1(42, n1 => undef), [42, undef, 42, n1 => undef];
is_deeply pos_0_1_name_0_1(42, n1 => 'a'), [42, 'a', 42, n1 => 'a'];
is_deeply pos_0_1_name_0_1(42, n1 => 'a', n1 => 'b'), [42, 'b', 42, n1 => 'a', n1 => 'b'];
is_deeply pos_0_1_name_0_1(42, n1 => 'a', n1 => undef), [42, undef, 42, n1 => 'a', n1 => undef];


fun name_1_slurp(:$n1, @rest) { [$n1, \@rest, @_] }

like exception { name_1_slurp }, qr/Too few arguments/;
like exception { name_1_slurp 'n1' }, qr/Too few arguments/;
like exception { name_1_slurp 'asdf' }, qr/Too few arguments/;
like exception { name_1_slurp huh => 1 }, qr/missing named\b.+\bn1\b/;
is_deeply name_1_slurp(n1 => 'a'), ['a', [], n1 => 'a'];
like exception { name_1_slurp n1 => 'a', 'n1' }, qr/Odd number/;
is_deeply name_1_slurp(n1 => 'a', foo => 'bar'), ['a', [foo => 'bar'], n1 => 'a', foo => 'bar'];
is_deeply name_1_slurp(foo => 'bar', n1 => 'a', foo => 'quux'), ['a', [foo => 'quux'], foo => 'bar', n1 => 'a', foo => 'quux'];


fun name_0_1_slurp(:$n1 = 'd', @rest) { [$n1, \@rest, @_] }

is_deeply name_0_1_slurp, ['d', []];
like exception { name_0_1_slurp 'n1' }, qr/Odd number/;
like exception { name_0_1_slurp 'asdf' }, qr/Odd number/;
is_deeply name_0_1_slurp(n1 => 'a'), ['a', [], n1 => 'a'];
like exception { name_0_1_slurp n1 => 'a', 'n1' }, qr/Odd number/;
is_deeply name_0_1_slurp(a => 'b'), ['d', [a => 'b'], a => 'b'];
is_deeply name_0_1_slurp(n1 => 'a', foo => 'bar'), ['a', [foo => 'bar'], n1 => 'a', foo => 'bar'];
is_deeply name_0_1_slurp(foo => 'bar', n1 => 'a', foo => 'quux'), ['a', [foo => 'quux'], foo => 'bar', n1 => 'a', foo => 'quux'];


fun name_2(:$n1, :$n2) { [$n1, $n2, @_] }

like exception { name_2 }, qr/Too few arguments/;
like exception { name_2 'n1' }, qr/Too few arguments/;
like exception { name_2 'asdf' }, qr/Too few arguments/;
like exception { name_2 huh => 1 }, qr/Too few arguments/;
like exception { name_2 n1 => 'a' }, qr/Too few arguments/;
like exception { name_2 n1 => 'a', n1 => 'b' }, qr/missing named\b.+\bn2\b/;
like exception { name_2 n2 => 'a' }, qr/Too few arguments/;
like exception { name_2 n2 => 'a', n2 => 'b' }, qr/missing named\b.+\bn1\b/;
like exception { name_2 n1 => 'a', 'n2' }, qr/Too few arguments/;
like exception { name_2 n1 => 'a', 'asdf' }, qr/Too few arguments/;
like exception { name_2 n2 => 'b', n1 => 'a', huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_2(n2 => 42, n1 => undef), [undef, 42, n2 => 42, n1 => undef];
is_deeply name_2(n2 => 42, n1 => 'a'), ['a', 42, n2 => 42, n1 => 'a'];
is_deeply name_2(n2 => 42, n1 => 'a', n1 => 'b'), ['b', 42, n2 => 42, n1 => 'a', n1 => 'b'];
is_deeply name_2(n2 => 42, n1 => 'a', n1 => undef), [undef, 42, n2 => 42, n1 => 'a', n1 => undef];
is_deeply name_2(n1 => undef, n2 => 42), [undef, 42, n1 => undef, n2 => 42];
is_deeply name_2(n1 => 'a', n2 => 42), ['a', 42, n1 => 'a', n2 => 42];
is_deeply name_2(n1 => 'a', n1 => 'b', n2 => 42), ['b', 42, n1 => 'a', n1 => 'b', n2 => 42];
is_deeply name_2(n1 => 'a', n2 => 42, n1 => undef), [undef, 42, n1 => 'a', n2 => 42, n1 => undef];


fun name_1_2(:$n1, :$n2 = 'f') { [$n1, $n2, @_] }

like exception { name_1_2 }, qr/Too few arguments/;
like exception { name_1_2 'n1' }, qr/Too few arguments/;
like exception { name_1_2 'asdf' }, qr/Too few arguments/;
like exception { name_1_2 n1 => 0, huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_1_2(n1 => 'a'), ['a', 'f', n1 => 'a'];
is_deeply name_1_2(n1 => 'a', n1 => 'b'), ['b', 'f', n1 => 'a', n1 => 'b'];
like exception { name_1_2 n2 => 'a' }, qr/missing named\b.+\bn1\b/;
like exception { name_1_2 n2 => 'a', n2 => 'b' }, qr/missing named\b.+\bn1\b/;
like exception { name_1_2 n1 => 'a', 'n2' }, qr/Odd number/;
like exception { name_1_2 n1 => 'a', 'asdf' }, qr/Odd number/;
like exception { name_1_2 n2 => 'b', n1 => 'a', huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_1_2(n2 => 42, n1 => undef), [undef, 42, n2 => 42, n1 => undef];
is_deeply name_1_2(n2 => 42, n1 => 'a'), ['a', 42, n2 => 42, n1 => 'a'];
is_deeply name_1_2(n2 => 42, n1 => 'a', n1 => 'b'), ['b', 42, n2 => 42, n1 => 'a', n1 => 'b'];
is_deeply name_1_2(n2 => 42, n1 => 'a', n1 => undef), [undef, 42, n2 => 42, n1 => 'a', n1 => undef];
is_deeply name_1_2(n1 => undef, n2 => 42), [undef, 42, n1 => undef, n2 => 42];
is_deeply name_1_2(n1 => 'a', n2 => 42), ['a', 42, n1 => 'a', n2 => 42];
is_deeply name_1_2(n1 => 'a', n1 => 'b', n2 => 42), ['b', 42, n1 => 'a', n1 => 'b', n2 => 42];
is_deeply name_1_2(n1 => 'a', n2 => 42, n1 => undef), [undef, 42, n1 => 'a', n2 => 42, n1 => undef];


fun name_0_2(:$n1 = 'd', :$n2 = 'f') { [$n1, $n2, @_] }

is_deeply name_0_2, ['d', 'f'];
like exception { name_0_2 'n1' }, qr/Odd number/;
like exception { name_0_2 'asdf' }, qr/Odd number/;
like exception { name_0_2 huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_0_2(n1 => 'a'), ['a', 'f', n1 => 'a'];
is_deeply name_0_2(n1 => 'a', n1 => 'b'), ['b', 'f', n1 => 'a', n1 => 'b'];
is_deeply name_0_2(n2 => 'a'), ['d', 'a', n2 => 'a'];
is_deeply name_0_2(n2 => 'a', n2 => 'b'), ['d', 'b', n2 => 'a', n2 => 'b'];
like exception { name_0_2 n1 => 'a', 'n2' }, qr/Odd number/;
like exception { name_0_2 n1 => 'a', 'asdf' }, qr/Odd number/;
like exception { name_0_2 n2 => 'b', n1 => 'a', huh => 1 }, qr/\bnamed\b.+\bhuh\b/;
is_deeply name_0_2(n2 => 42, n1 => undef), [undef, 42, n2 => 42, n1 => undef];
is_deeply name_0_2(n2 => 42, n1 => 'a'), ['a', 42, n2 => 42, n1 => 'a'];
is_deeply name_0_2(n2 => 42, n1 => 'a', n1 => 'b'), ['b', 42, n2 => 42, n1 => 'a', n1 => 'b'];
is_deeply name_0_2(n2 => 42, n1 => 'a', n1 => undef), [undef, 42, n2 => 42, n1 => 'a', n1 => undef];
is_deeply name_0_2(n1 => undef, n2 => 42), [undef, 42, n1 => undef, n2 => 42];
is_deeply name_0_2(n1 => 'a', n2 => 42), ['a', 42, n1 => 'a', n2 => 42];
is_deeply name_0_2(n1 => 'a', n1 => 'b', n2 => 42), ['b', 42, n1 => 'a', n1 => 'b', n2 => 42];
is_deeply name_0_2(n1 => 'a', n2 => 42, n1 => undef), [undef, 42, n1 => 'a', n2 => 42, n1 => undef];


fun pos_1_2_name_0_3_slurp($p1, $p2 = 'E', :$n1 = undef, :$n2 = 'A', :$n3 = 'F', @rest) { [$p1, $p2, $n1, $n2, $n3, {@rest}, @_] }

like exception { pos_1_2_name_0_3_slurp }, qr/Too few/;
is_deeply pos_1_2_name_0_3_slurp('a'), ['a', 'E', undef, 'A', 'F', {}, 'a'];
is_deeply pos_1_2_name_0_3_slurp('a', 'b'), ['a', 'b', undef, 'A', 'F', {}, 'a', 'b'];
like exception { pos_1_2_name_0_3_slurp 'a', 'b', 'c' }, qr/Odd number/;
is_deeply pos_1_2_name_0_3_slurp('a', 'b', 'c', 'd'), ['a', 'b', undef, 'A', 'F', {'c', 'd'}, 'a', 'b', 'c', 'd'];
like exception { pos_1_2_name_0_3_slurp 'a', 'b', 'c', 'd', 'e' }, qr/Odd number/;
is_deeply pos_1_2_name_0_3_slurp('a', 'b', 'c', 'd', 'e', 'f'), ['a', 'b', undef, 'A', 'F', {'c', 'd', 'e', 'f'}, 'a', 'b', 'c', 'd', 'e', 'f'];
is_deeply pos_1_2_name_0_3_slurp('a', 'b', n2 => 'c', n1 => 'd'), ['a', 'b', 'd', 'c', 'F', {}, 'a', 'b', n2 => 'c', n1 => 'd'];
is_deeply pos_1_2_name_0_3_slurp('a', 'b', n2 => 'c', beans => 'legume', n1 => 'd'), ['a', 'b', 'd', 'c', 'F', {beans => 'legume'}, 'a', 'b', n2 => 'c', beans => 'legume', n1 => 'd'];
