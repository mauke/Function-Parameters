use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Function::Parameters',
    AUTHOR              => q{Lukas Mai <l.mai@web.de>},
    VERSION_FROM        => 'lib/Function/Parameters.pm',
    ABSTRACT_FROM       => 'lib/Function/Parameters.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'warnings' => 0,
        'strict' => 0,
        'Devel::Declare' => 0,
        'B::Hooks::EndOfScope' => 0,
        'B::Compiling' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Function-Parameters-*' },
);
