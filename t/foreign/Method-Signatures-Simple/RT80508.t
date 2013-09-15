#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;

{
    package My::Obj;
    use Function::Parameters qw(:strict);

    method with_space ( $this : $that ) {
        return ($this, $that);
    }
}

is_deeply [ My::Obj->with_space (1) ], [ 'My::Obj', 1 ], 'space between invocant name and colon should parse';

__END__

