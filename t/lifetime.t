use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;

use Function::Parameters {
    fun_cx => { defaults => 'function', install_sub => 'jamitin' },
    fun_rx => { defaults => 'function', install_sub => 'jamitin', runtime => 1 },
};

use Hash::Util qw(fieldhash);

my %watcher;
BEGIN { fieldhash %watcher; }

my $calls;
BEGIN { $calls = 0; }

sub jamitin {
    my ($name, $body) = @_;
    $watcher{$body} = $name;
    $calls++;
}

my $forceclosure;

BEGIN {
    is $calls, 0;
    is_deeply \%watcher, {};
}

BEGIN {
    jamitin 'via_sub_cx', sub { $forceclosure };
}

BEGIN {
    is $calls, 1;
    is_deeply \%watcher, {};
}

fun_cx via_fun_cx(@) { $forceclosure }

BEGIN {
    is $calls, 2;
    is_deeply \%watcher, {};
}

BEGIN {
    $calls = 0;
}


is $calls, 0;
is_deeply \%watcher, {};

jamitin 'via_sub_rx', sub { $forceclosure };

is $calls, 1;
is_deeply \%watcher, {};

fun_rx via_fun_rx(@) { $forceclosure }

is $calls, 2;
TODO: {
    local $TODO = 'bug/leak: runtime-installed subs are kept alive somehow';
    is_deeply \%watcher, {};
}
