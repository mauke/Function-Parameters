#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;

{
    package My::Obj;
    use Function::Parameters qw(:strict);
    method new () {
        bless {}, $self;
    }
    method foo (
      $x,  # the X
      $y,  # the Y
      ) {
        return $x * $y;
    }
    my $bar = method (
        $P, # comment
        $Q, # comment
        ) { # comment
        $P + $Q
    };
}

my $o = My::Obj->new;
is $o->foo(4, 5), 20, "should allow comments and newlines in proto";
is __LINE__, 28, "should leave line number intact";

__END__
