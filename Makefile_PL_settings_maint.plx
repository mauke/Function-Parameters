use strict;
use warnings;

sub {
    my ($opt) = @_;

    if ($^V ge v5.16.0 && $^V lt v5.22.0) {
        # Hack. ASan reports a memory leak on 5.16 .. 5.20, but I don't
        # want integration tests to fail for now.
        $opt->{EXTRA_ASAN_OPTIONS} .= " LSAN_OPTIONS='exitcode=0'";
    }

    $opt->{DEVELOP_REQUIRES} = {
        'aliased'         => 0,
        'Moose'           => 0,
        'MooseX::Types'   => 0,
        'Sub::Name'       => 0,
        'Test::Pod'       => 1.22,
    };
}
