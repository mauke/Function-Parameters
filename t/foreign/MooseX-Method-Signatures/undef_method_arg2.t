#!perl
use strict;
use warnings FATAL => 'all';
use Test::More
    eval {
        require Moose;
        require Test::Deep;
    }
    ? (tests => 4)
    : (skip_all => "Moose, Test::Deep required for testing types")
;

# assigned to by each 'foo' method
my $captured_args;

{
    package Named;

    use Moose;
    use Function::Parameters qw(:strict);

#    use Data::Dumper;

    method foo (
        Str :$foo_a,
        Maybe[Str] :$foo_b = undef) {
        $captured_args = \@_;
    }
}


{
    package Positional;
    use Moose;
    use Function::Parameters qw(:strict);

#    use Data::Dumper;

    method foo (
        Str $foo_a,
        Maybe[Str] $foo_b = undef) {
        $captured_args = \@_;
    }
}


use Test::Deep;
#use Data::Dumper;



my $positional = Positional->new;
$positional->foo('str', undef);

cmp_deeply(
    $captured_args,
    [
        #noclass({}),
        'str',
        undef,
    ],
    'positional: explicit undef shows up in @_ correctly',
);

$positional->foo('str');

cmp_deeply(
    $captured_args,
    [
        #noclass({}),
        'str',
    ],
    'positional: omitting an argument results in no entry in @_',
);

my $named = Named->new;
$named->foo(foo_a => 'str', foo_b => undef);

cmp_deeply(
    $captured_args,
    [
        #noclass({}),
        foo_a => 'str',
        foo_b => undef,
    ],
    'named: explicit undef shows up in @_ correctly',
);

$named->foo(foo_a => 'str');

#TODO: {
#    local $TODO = 'this fails... should work the same as for positional args.';
cmp_deeply(
    $captured_args,
    [
        #noclass({}),
        foo_a => 'str',
    ],
    'named: omitting an argument results in no entry in @_',
);

#print "### named captured args: ", Dumper($captured_args);
#}




