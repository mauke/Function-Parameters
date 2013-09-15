#!perl
use strict;
use warnings FATAL => 'all';
use Function::Parameters qw(:strict);
use Test::More tests => 2;

{
    my $uniq = 0;

    method fresh_name() {
        $self->prefix . $uniq++
    }
}

method prefix() {
    $self->{prefix}
}

my $o = bless {prefix => "foo_" }, main::;
is $o->fresh_name, 'foo_0';

#TODO: {
#    local $TODO = 'do not know how to handle the scope change in line 7';
    is __LINE__, 24;
#}

__END__

