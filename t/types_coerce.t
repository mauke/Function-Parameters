#!perl
use warnings FATAL => 'all';
use strict;

use Test::More
    eval { require Type::Library }
    ? ()
    : (skip_all => "Type::Library required for testing type coercion");

BEGIN {
    package MyTC {
        use Type::Library
          -base,
          -declare => qw(MyArrayRef);
        use Type::Utils -all;
        use Types::Standard -types;

        declare MyArrayRef, as ArrayRef;
        coerce MyArrayRef, from Any, via { [$_] };
    };

    MyTC->import('MyArrayRef');
}

use Function::Parameters;

my $re_error = qr/did not pass type constraint/;

eval {
    ( fun( MyArrayRef $x) { } )->(1);
};
like( $@, $re_error, 'coerce mode off, positional' );

eval {
    ( fun( MyArrayRef : $x ) { } )->( x => 1 );
};
like( $@, $re_error, 'coerce mode off, named' );

eval {
    ( fun( MyArrayRef @rest ) { } )->(1);
};
like( $@, $re_error, 'coerce mode off, slurp array' );

eval {
    ( fun( MyArrayRef %rest ) { } )->( x => 1 );
};
like( $@, $re_error, 'coerce mode off, slurp hash' );

use Function::Parameters { fun => { coerce_argument_types => 1 } };

is_deeply( ( fun( MyArrayRef $x) { $x } )->(1), [1], 'positional' );
is_deeply( ( fun( MyArrayRef : $x ) { $x } )->( x => 1 ), [1], 'named' );
is_deeply( ( fun( MyArrayRef @rest ) { \@rest } )->( 1, [2], 3 ),
    [ [1], [2], [3] ],
    'slurp array' );
is_deeply( ( fun( MyArrayRef %rest ) { \%rest } )->( x => 1, y => [2], z => 3 ),
    { x => [1], y => [2], z => [3] },
    'slurp hash' );

done_testing;
