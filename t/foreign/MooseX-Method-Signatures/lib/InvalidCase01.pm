package InvalidCase01;
use strict;
use warnings; no warnings 'syntax';
use Function::Parameters qw(:strict);
use Carp qw/croak/;

method meth1(@){
  croak "Binary operator $op expects 2 children, got " . $#$_
    if @{$_} > 3;
}

method meth2(){ {
  "a" "b"
}

method meth3() {}
1;

