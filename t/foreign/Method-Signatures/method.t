#!perl -w

use strict;
use warnings FATAL => 'all';
use lib 't/lib';

use Test::More 'no_plan';

{
    package Foo;
    use Method::Signatures;

    method new (%args) {
        return bless {%args}, $self;
    }

    method set ($key, $val) {
        return $self->{$key} = $val;
    }

    method get ($key) {
        return $self->{$key};
    }

    method no_proto {
        return($self, @_);
    }

    method empty_proto() {
        return($self, @_);
    }

    method echo(@args) {
        return($self, @args);
    }

    method caller($height = 0) {
        return (CORE::caller($height))[0..2];
    }

#line 39
    method warn($foo=) {
        my $warning = '';
        local $SIG{__WARN__} = sub { $warning = join '', @_; };
        CORE::warn "Testing warn";

        return $warning;
    }

    # Method with the same name as a loaded class.
    method strict () {
        42
    }
}

my $obj = Foo->new( foo => 42, bar => 23 );
isa_ok $obj, "Foo";
is $obj->get("foo"), 42;
is $obj->get("bar"), 23;

$obj->set(foo => 99);
is $obj->get("foo"), 99;

for my $method (qw(no_proto empty_proto)) {
    is_deeply [$obj->$method], [$obj];

    TODO: {
        local $TODO;
        $TODO = 'no signature should be the same as the empty signature'
          if $method eq 'no_proto';
        ok !eval { $obj->$method(23); 1 };
    }
    TODO: {
        local $TODO = 'wrong number of arguments reported for methods';
        like $@, qr{Too many arguments for method \Q$method \(expected 0, got 1\)};
    }
}

is_deeply [$obj->echo(1,2,3)], [$obj,1,2,3], "echo";

is_deeply [$obj->caller], [__PACKAGE__, $0, __LINE__], 'caller works';

is $obj->warn, "Testing warn at $0 line 42.\n";

is eval { $obj->strict }, 42;
