#!perl
use strict;
use warnings;
use Test::More;
use Function::Parameters;

my @warnings;
BEGIN {
    $SIG{__WARN__} = sub {
        push @warnings, $_[0];
    };
}

sub wget {
    splice @warnings
}

{
    BEGIN { $^H{'Function::Parameters/config'} .= ''; }
    if (0) {}
    if (0) {}
}
BEGIN {
    my @w = wget;
    is @w, 1;
    like $w[0], qr{^Function::Parameters: \$\^H\{'Function::Parameters/config'\} is not a reference; skipping: HASH\(};
}

{
    no warnings 'Function::Parameters';
    BEGIN { $^H{'Function::Parameters/config'} .= ''; }
    if (0) {}
    if (0) {}
}
BEGIN {
    my @w = wget;
    is @w, 0;
    is $w[0], undef;
}

done_testing;
