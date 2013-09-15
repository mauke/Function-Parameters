#!perl
use strict;
use warnings FATAL => 'all';
use Test::More
    eval { require Moose }
    ? (tests => 7)
    : (skip_all => "Moose required for testing types")
;

{
    package Foo;

    use Moose;
    use Function::Parameters qw(:strict);

    for my $meth (qw/foo bar baz/) {
        Foo->meta->add_method("anon_$meth" => method (Str $bar) {
            $meth . $bar
        });

        eval qq{
            method str_$meth (Str \$bar) {
                \$meth . \$bar
            }
        };
        die $@ if $@;
    }
}

can_ok('Foo', map { ("anon_$_", "str_$_") } qw/foo bar baz/);

my $foo = Foo->new;

for my $meth (qw/foo bar baz/) {
    is($foo->${\"anon_$meth"}('bar'), $meth . 'bar');
    is($foo->${\"str_$meth"}('bar'), $meth . 'bar');
}

