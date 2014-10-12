#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use Dir::Self;
use lib __DIR__ . "/lib";

eval "use InvalidCase01;";
ok($@, "Got an error");

#TODO: {
#
#local $TODO = 'Devel::Declare and Eval::Closure have unresolved issues'
#    if Eval::Closure->VERSION > 0.06;

like($@,
     qr/^Global symbol "\$op" requires explicit package name .*?\bInvalidCase01.pm line 8\b/,
     "Sane error message for syntax error");

#}


{
  my $warnings = "";
  local $SIG{__WARN__} = sub { $warnings .= $_[0] };

  eval "use Redefined;";
  is($@, '', "No error");
  like($warnings, qr/^Subroutine meth1 redefined at .*?\bRedefined.pm line 9\b/,
       "Redefined method warning");
}

done_testing;
