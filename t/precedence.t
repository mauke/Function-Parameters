#!perl

use Test::More tests => 11;

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

fun four { 2 + 2 } fun five() { 1 + four }

fun quantum :() {; 0xf00d
}

is four, 4, "basic sanity 1";
is five, 5, "basic sanity 2";
is quantum, 0xf00d, "basic sanity 3";
is quantum / 2 #/
, 0xf00d / 2, "basic sanity 4 - () proto";

is eval('my $x = fun forbidden {}'), undef, "statements aren't expressions";
like $@, qr/syntax error/;

is eval('my $x = { fun forbidden {} }'), undef, "statements aren't expressions 2 - electric boogaloo";
like $@, qr/syntax error/;

is fun { join '.', five, four }->(), '5.4', "can immedicall anon subs";

is 0 * fun {} + 42, 42, "* binds tighter than +";
is 0 * fun { quantum / q#/ }
# } + 42, 42, "* binds tighter than + 2 - electric boogaloo";
