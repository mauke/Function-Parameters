#!perl
use warnings FATAL => 'all';
use strict;
use lib 't/lib';

use Test::More;

{
    package Foo;

    use Test::More;
    use Test::Fatal;;
    use Method::Signatures;

    method formalize($text, :$justify = "left", :$case = undef) {
        my %params;
        $params{text}           = $text;
        $params{justify}        = $justify;
        $params{case}           = $case if defined $case;

        return \%params;
    }

    is_deeply( Foo->formalize( "stuff" ), { text => "stuff", justify => "left" } );

    like exception { Foo->formalize( "stuff", wibble => 23 ) }, qr/\bnamed\b.+\bwibble\b/;

    method foo( :$arg ) {
        return $arg;
    }

    is( Foo->foo( arg => 42 ), 42 );
    like exception { foo() }, qr/Too few arguments/;


    # Compile time errors need internal refactoring before I can get file, line and method
    # information.
    eval q{
        method wrong( :$named, $pos ) {}
    };
    like $@, qr/\bpositional\b.+\$pos\b.+\bnamed\b.+\$named\b/;

    eval q{
        method wrong( $foo, :$named, $bar ) {}
    };
    like $@, qr/\bpositional\b.+\$bar\b.+\bnamed\b.+\$named\b/;

    eval q{
        method wrong( $foo, $bar = undef, :$named ) {}
    };
    like $@, qr/\boptional positional\b.+\$bar\b.+\brequired named\b.+\$named\b/;
}


done_testing();
