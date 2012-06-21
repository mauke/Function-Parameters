#!perl

use Test::More tests => 10;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

method id_1() { $self }

method id_2
 (

 )
 : #hello
 (
  $
 )
 {@_ == 0 or return;
 	 $self
 }

method##
    id_3 ##
 (   ##
 	 #
 ) ##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 
 { ##
 	$self ##
 } ##

method add($y) {
	$self + $y
}

method mymap(@args) :(&@) {
  my @res;
  for (@args) {
    push @res, $self->($_);
  }
  @res
}

method fac_1() {
	$self < 2 ? 1 : $self * fac_1 $self - 1
}

method fac_2() :($) {
	$self < 2 ? 1 : $self * fac_2 $self - 1
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
is method ($y) { $self . $y }->(method () { $self + 1 }->(3), method () { $self * 2 }->(1)), '42', 'anonyfun';
