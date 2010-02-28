#!perl

use Test::More tests => 10;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

fun id_1($x) { $x }

fun id_2
 (
 	 $x
 )
 :
 (
  $
 )
 {
 	 $x
 }

fun id_3 ##
 (  $x ##
 ) ##
 { ##
 	 $x ##
 } ##

fun add($x, $y) {
	$x + $y
}

fun mymap($fun, @args) :(&@) {
  my @res;
  for (@args) {
    push @res, $fun->($_);
  }
  @res
}

fun fac_1($n) {
	$n < 2 ? 1 : $n * fac_1 $n - 1
}

fun fac_2($n) :($) {
	$n < 2 ? 1 : $n * fac_2 $n - 1
}

ok id_1 1;
ok id_1(1), 'basic sanity';
ok id_2 1, 'simple prototype';
ok id_3(1), 'definition over multiple lines';
is add(2, 2), 4, '2 + 2 = 4';
is add(39, 3), 42, '39 + 3 = 42';
is_deeply [mymap { $_ * 2 } 2, 3, 5, 9], [4, 6, 10, 18], 'mymap works';
is fac_1(5), 120, 'fac_1';
is fac_2 6, 720, 'fac_2';
is fun ($x, $y) { $x . $y }->(fun ($foo) { $foo + 1 }->(3), fun ($bar) { $bar * 2 }->(1)), '42', 'anonyfun';
