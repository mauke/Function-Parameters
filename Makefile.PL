use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Function::Parameters',
    AUTHOR              => q{Lukas Mai <l.mai@web.de>},
    VERSION_FROM        => 'lib/Function/Parameters.pm',
    ABSTRACT_FROM       => 'lib/Function/Parameters.pm',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.56',
    },
    LICENSE => 'perl',
    PL_FILES => {},
    BUILD_REQUIRES => {
        'Dir::Self' => 0,
        'Test::More' => 0,
    },
    PREREQ_PM => {
    	'Carp' => 0,
    	'XSLoader' => 0,
        'warnings' => 0,
        'strict' => 0,
    },
    MIN_PERL_VERSION => '5.14.0',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Function-Parameters-*' },
);
