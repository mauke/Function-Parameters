use strict;
use warnings;
use ExtUtils::MakeMaker;

sub merge_key_into {
    my ($href, $target, $source) = @_;
    %{$href->{$target}} = (%{$href->{$target}}, %{delete $href->{$source}});
}

my %opt = (
    NAME   => 'Function::Parameters',
    AUTHOR => q{Lukas Mai <l.mai@web.de>},

    MIN_PERL_VERSION => '5.14.0',
    CONFIGURE_REQUIRES => {},
    BUILD_REQUIRES => {},
    TEST_REQUIRES => {
        'constant'    => 0,
        'strict'      => 0,
        'utf8'        => 0,
        'Dir::Self'   => 0,
        'Test::More'  => 0,
        'Test::Fatal' => 0,
    },
    PREREQ_PM => {
        'Carp'     => 0,
        'XSLoader' => 0,
        'warnings' => 0,
    },

    depend => {
        Makefile    => '$(VERSION_FROM)',
        '$(OBJECT)' => join(' ', glob 'hax/*.c.inc'),
    },

    test => { TESTS => join(' ', map 't' . '/*' x $_ . '.t', 1 .. 4) },
);

{
    $opt{LICENSE} ||= 'perl';
    $opt{PL_FILES} ||= {};

    $opt{CONFIGURE_REQUIRES}{strict}                ||= 0;
    $opt{CONFIGURE_REQUIRES}{warnings}              ||= 0;
    $opt{CONFIGURE_REQUIRES}{'ExtUtils::MakeMaker'} ||= '6.48';

    my $module_file = $opt{NAME};
    $module_file =~ s!::!/!g;
    $module_file = "lib/$module_file.pm";

    $opt{VERSION_FROM}  ||= $module_file;
    $opt{ABSTRACT_FROM} ||= $module_file;

    $opt{DISTNAME} ||= do {
        my $name = $opt{NAME};
        $name =~ s!::!-!g;
        $name
    };

    $opt{clean}{FILES} ||= "$opt{DISTNAME}-*";

    $opt{dist}{COMPRESS} ||= 'gzip -9f';
    $opt{dist}{SUFFIX}   ||= '.gz';

    $opt{META_MERGE}{'meta-spec'}{version} ||= 2;
    $opt{META_MERGE}{dynamic_config} ||= 0;

    my $github_account = 'mauke';
    my $github = "github.com/$github_account/$opt{DISTNAME}";
    $opt{META_MERGE}{resources}{repository}{type} ||= 'git';
    $opt{META_MERGE}{resources}{repository}{url}  ||= "git://$github";
    $opt{META_MERGE}{resources}{repository}{web}  ||= "https://$github";
}

(do 'maint/eumm-fixup.pl' || die $@ || $!)->(\%opt) if !-f 'META.yml';

(my $mm_version = ExtUtils::MakeMaker->VERSION) =~ tr/_//d;

if ($mm_version < 6.67_04) {
    # Why? For the glory of satan, of course!
    no warnings qw(redefine);
    *ExtUtils::MM_Any::_add_requirements_to_meta_v1_4 = \&ExtUtils::MM_Any::_add_requirements_to_meta_v2;
}

if ($mm_version < 6.63_03) {
    merge_key_into \%opt, 'BUILD_REQUIRES', 'TEST_REQUIRES';
}

if ($mm_version < 6.55_01) {
    merge_key_into \%opt, 'CONFIGURE_REQUIRES', 'BUILD_REQUIRES';
}

if ($mm_version < 6.51_03) {
    merge_key_into \%opt, 'PREREQ_PM', 'CONFIGURE_REQUIRES';
}

WriteMakefile %opt;
