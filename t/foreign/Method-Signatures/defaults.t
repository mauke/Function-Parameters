#!perl -w

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More;
use Test::Fatal qw(lives_ok);

{
    package Stuff;

    use Test::More;
    use Method::Signatures;

    method add($this = 23, $that = 42) {
        return $this + $that;
    }

    is( Stuff->add(),    23 + 42 );
    is( Stuff->add(99),  99 + 42 );
    is( Stuff->add(2,3), 5 );

    TODO: {
        local $TODO = 'is ro not implemented';
        
        ok eval q[
            method minus($this is ro = 23, $that is ro = 42) {
                return $this - $that;
            }
            1;
        ];

        ok eval {
            is( Stuff->minus(),         23 - 42 );
            is( Stuff->minus(99),       99 - 42 );
            is( Stuff->minus(2, 3),     2 - 3 );
        };
    }

    # Test that undef overrides defaults
    method echo($message = "what?") {
        return $message
    }

    is( Stuff->echo(),          "what?" );
    is( Stuff->echo(undef),     undef   );
    is( Stuff->echo("who?"),    'who?'  );


    # Test that you can reference earlier args in a default
    method copy_cat($this, $that = $this) {
        return $that;
    }

    is( Stuff->copy_cat("wibble"), "wibble" );
    is( Stuff->copy_cat(23, 42),   42 );
}


{
    package Bar;
    use Test::More;
    use Method::Signatures;

    method hello($msg = "Hello, world!") {
        return $msg;
    }

    is( Bar->hello,               "Hello, world!" );
    is( Bar->hello("Greetings!"), "Greetings!" );


    method hi($msg = q,Hi,) {
        return $msg;
    }

    is( Bar->hi,                "Hi" );
    is( Bar->hi("Yo"),          "Yo" );


    TODO: {
        local $TODO = 'defaults for lists not implemented';

        ok eval q[
            method list(@args = (1,2,3)) {
                return @args;
            }
            1;
        ];

        ok eval {
            is_deeply [Bar->list()], [1,2,3];
        };
    }


    method code($num, $code = sub { $num + 2 }) {
        return $code->();
    }

    is( Bar->code(42), 44 );
}

note "Defaults are type checked"; {
    package Biff;
    use Test::More;
    use Method::Signatures;

    func hi(
        Object $place = "World"
    ) {
        return "Hi, $place!\n";
    }

    ok !eval { hi() };
    like $@, qr/parameter 1 \(\$place\): Validation failed/;
}


note "Multi-line defaults"; {
    package Whatever;

    use Method::Signatures;
    use Test::More;

    func stuff(
        $arg = {
            foo => 23,
            bar => 42
        }
    ) {
        return $arg->{foo};
    }

    is( stuff(), 23 );

    func things(
        $arg = "Hello
There"
    ) {
        return $arg;
    }

    is( things(), "Hello\nThere" );
}

done_testing;
