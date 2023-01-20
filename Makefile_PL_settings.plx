use strict;
use warnings;

{
    my $broken;
    if (eval { require Moose }) {
        if (!eval { package A_Moose_User; Moose->import; 1 }) {
            $broken = 'import';
        }
    } elsif ($@ !~ /^Can't locate Moose\.pm /) {
        $broken = 'require';
    }
    if ($broken) {
        print STDERR <<"EOT";
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! Error: You seem to have Moose but I can't "use" it ($broken dies). !!!
!!! This would cause confusing test errors, so I'm bailing out. Sorry. !!!
!!! Maybe try upgrading Moose?                                         !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

The exception was:
$@
EOT
        exit 1;
    }
}

return {
    NAME   => 'Function::Parameters',
    AUTHOR => q{Lukas Mai <l.mai@web.de>},

    MIN_PERL_VERSION => '5.14.0',
    CONFIGURE_REQUIRES => {},
    BUILD_REQUIRES => {},
    TEST_REQUIRES => {
        'constant'    => 0,
        'strict'      => 0,
        'utf8'        => 0,
        'FindBin'     => 0,
        'Hash::Util'  => 0.07,
        'Test::More'  => 0,
        'Test::Fatal' => 0,
    },
    PREREQ_PM => {
        'Carp'         => 0,
        'Scalar::Util' => 0,
        'XSLoader'     => 0,
        'warnings'     => 0,
    },
    DEVELOP_REQUIRES => {
        'Test::Pod' => 1.22,
    },

    depend => {
        Makefile    => '$(VERSION_FROM)',
        '$(OBJECT)' => join(' ', glob 'hax/*.c.inc'),
    },

    REPOSITORY => [ github => 'mauke' ],
};
