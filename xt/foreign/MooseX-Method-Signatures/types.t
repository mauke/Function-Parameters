#!perl
use strict;
use warnings FATAL => 'all';
use Test::More
    eval { require Moose; require MooseX::Types }
    ? (tests => 4)
    : (skip_all => "Moose, MooseX::Types required for testing types")
;
use Test::Fatal;

{
    package MyTypes;
    use MooseX::Types::Moose qw/Str/;
    use Moose::Util::TypeConstraints;
    use MooseX::Types -declare => [qw/CustomType/];

    BEGIN {
        subtype CustomType,
            as Str,
            where { length($_) == 2 };
    }
}

{
    package TestClass;
    use Function::Parameters qw(:strict);
    BEGIN { MyTypes->import('CustomType') };
    use MooseX::Types::Moose qw/ArrayRef/;
    #use namespace::clean;

    method foo ((CustomType) $bar) { }

    method bar ((ArrayRef[CustomType]) $baz) { }
}

my $o = bless {} => 'TestClass';

is(exception { $o->foo('42') }, undef);
ok(exception { $o->foo('bar') });

is(exception { $o->bar(['42', '23']) }, undef);
ok(exception { $o->bar(['foo', 'bar']) });
