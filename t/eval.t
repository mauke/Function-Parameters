#!perl

use warnings FATAL => 'all';
use strict;

use Function::Parameters;

{
    package TX;

    method new($class: :$chk) { bless { @_ }, $class }

    method check($x) { $self->{chk}($x) }

    method get_message($x) { die "get_message($x)"; }
}

our @trace;

use Function::Parameters {
    def => {
        defaults    => 'function',
        runtime     => 1,
        shift       => [
            [
                '$self' => TX->new(chk => fun ($x) {
                    push @trace, [self_check => $x];
                    1
                })
            ],
        ],
        install_sub => fun ($name, $body) {
            $name = caller . "::$name" unless $name =~ /::/;
            push @trace, [install => $name];
            my $sym = do { no strict 'refs'; \*$name };
            *$sym = $body;
        },
    }
};

package Groovy;
use constant OtherType => TX->new(
    chk => fun ($x) {
        push @trace, [other_check => $x];
        1
    },
);

use Test::More tests => 5;

is_deeply [ splice @trace ], [];

def foo(OtherType $x) { push @trace, [foo => $self, $x]; }

is_deeply [ splice @trace ], [
    [install => 'Groovy::foo'],
];

is eval q{
    def bar(OtherType $x) { push @trace, [bar => $self, $x]; }
    42
}, 42;

is_deeply [ splice @trace ], [
    [install => 'Groovy::bar'],
];

foo('A1', 'A2');
bar('B1', 'B2');
is_deeply [ splice @trace ], [
    [self_check  => 'A1'],
    [other_check => 'A2'],
    [foo         => qw(A1 A2)],
    [self_check  => 'B1'],
    [other_check => 'B2'],
    [bar         => qw(B1 B2)],
];
