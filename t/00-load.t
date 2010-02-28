#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Function::Parameters' );
}

diag( "Testing Function::Parameters $Function::Parameters::VERSION, Perl $], $^X" );
