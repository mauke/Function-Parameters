#!perl

use Test::More tests => 10;

use warnings FATAL => 'all';
use strict;

use Function::Parameters { clathod => 'classmethod' };

clathod id_1() { $class }

clathod id_2
 (

 )
 : #hello
 (
  $
 )
 {@_ == 0 or return;
 	 $class
 }

clathod##
    id_3 ##
 (   ##
 	 #
 ) ##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 
 { ##
 	  $class##
 } ##

clathod add($y) {
    $class + $y
}

clathod mymap(@args) :(&@) {
  my @res;
  for (@args) {
    push @res, $class->($_);
  }
  @res
}

clathod fac_1() {
    $class < 2 ? 1 : $class * fac_1 $class - 1
}

clathod fac_2() :($) {
    $class < 2 ? 1 : $class * fac_2 $class - 1
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
is clathod ($y) { $class . $y }->(clathod () { $class + 1 }->(3), clathod () { $class * 2 }->(1)), '42', 'anonyfun';
