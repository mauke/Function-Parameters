#!perl
# vi: set et sw=4 sts=4:
use 5.006;
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
        'strict' => 0,
        'Dir::Self' => 0,
        'Test::More' => 0,
        'Test::Fatal' => 0,
    },
    PREREQ_PM => {
        'Carp' => 0,
        'Moo' => 0,
        'XSLoader' => 0,
        'warnings' => 0,
    },
    MIN_PERL_VERSION => '5.14.0',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                url => 'git://git.shadowcat.co.uk/p5sagit/Function-Parameters',
                web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=p5sagit/Function-Parameters.git',
                type => 'git',
            },
        },
    },
    depend => { Makefile => '$(VERSION_FROM)' },
    test => { TESTS => 't/*.t t/foreign/*.t t/foreign/*/*.t' },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Function-Parameters-*' },
);
