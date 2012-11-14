#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use Dir::Self;
use lib __DIR__ . '/lib';

ok !eval { require Bad };
#TODO: {
#    local $TODO = "The user should see the actual syntax error";
    like $@, qr{^Global symbol "\$info" requires explicit package name}m;

#    like($@, qr{^PPI failed to find statement for '\$bar'}m,
#         'Bad syntax generates stack trace');
#}

done_testing();
