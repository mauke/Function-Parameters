use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Spec ();
use File::Find ();

sub find_tests_recursively_in {
    my ($dir) = @_;
    -d $dir or die "$dir is not a directory";

    my %seen;
    my $wanted = sub {
        /\.t\z/ or return;
        my $directories = (File::Spec->splitpath($File::Find::name))[1];
        my $depth = grep $_ ne '', File::Spec->splitdir($directories);
        $seen{$depth} = 1;
    };
    File::Find::find($wanted, $dir);

    join ' ',
        map { $dir . '/*' x $_ . '.t' }
        sort { $a <=> $b }
        keys %seen
}

my $settings_file = 'Makefile_PL_settings';
my %settings = %{do $settings_file or die "Internal error: can't do $settings_file: ", $@ || $!};

{
    $settings{depend}{Makefile} .= " $settings_file";
    $settings{LICENSE} ||= 'perl';
    $settings{PL_FILES} ||= {};

    $settings{CONFIGURE_REQUIRES}{strict}                ||= 0;
    $settings{CONFIGURE_REQUIRES}{warnings}              ||= 0;
    $settings{CONFIGURE_REQUIRES}{'ExtUtils::MakeMaker'} ||= 0;
    $settings{CONFIGURE_REQUIRES}{'File::Find'}          ||= 0;
    $settings{CONFIGURE_REQUIRES}{'File::Spec'}          ||= 0;

    my $module_file = $settings{NAME};
    $module_file =~ s!::!/!g;
    $module_file = "lib/$module_file.pm";

    $settings{VERSION_FROM}  ||= $module_file;
    $settings{ABSTRACT_FROM} ||= $module_file;

    $settings{test}{TESTS} ||= find_tests_recursively_in 't';

    $settings{DISTNAME} ||= do {
        my $name = $settings{NAME};
        $name =~ s!::!-!g;
        $name
    };

    $settings{clean}{FILES} ||= "$settings{DISTNAME}-*";

    $settings{dist}{COMPRESS} ||= 'gzip -9f';
    $settings{dist}{SUFFIX}   ||= '.gz';

    $settings{META_MERGE}{'meta-spec'}{version} ||= 2;
    $settings{META_MERGE}{dynamic_config} ||= 0;

    push @{$settings{META_MERGE}{no_index}{directory}}, 'xt';

    if (my $bonus = delete $settings{bonus}) {
        if (my $account = delete $bonus->{github}) {
            my $github_addr = "github.com/$account/$settings{DISTNAME}";
            $settings{META_MERGE}{resources}{repository}{type} ||= 'git';
            $settings{META_MERGE}{resources}{repository}{url}  ||= "git://$github_addr";
            $settings{META_MERGE}{resources}{repository}{web}  ||= "https://$github_addr";
        }
        die "Internal error: unknown 'bonus' keys: @{[sort keys %$bonus]}" if %$bonus;
    }
}

(do 'maint/eumm-fixup.pl' || die $@ || $!)->(\%settings) if !-f 'META.yml';

(my $mm_version = ExtUtils::MakeMaker->VERSION) =~ tr/_//d;

if ($mm_version < 6.63_03) {
    $settings{META_MERGE}{resources}{repository} = $settings{META_MERGE}{resources}{repository}{url}
        if $settings{META_MERGE}{resources} &&
           $settings{META_MERGE}{resources}{repository} &&
           $settings{META_MERGE}{resources}{repository}{url};
    delete $settings{META_MERGE}{'meta-spec'}{version};
} elsif ($mm_version < 6.67_04) {
    # Why? For the glory of satan, of course!
    no warnings qw(redefine);
    *ExtUtils::MM_Any::_add_requirements_to_meta_v1_4 = \&ExtUtils::MM_Any::_add_requirements_to_meta_v2;
}

{
    my $merge_key_into = sub {
        my ($target, $source) = @_;
        %{$settings{$target}} = (%{$settings{$target}}, %{delete $settings{$source}});
    };

    $merge_key_into->('BUILD_REQUIRES', 'TEST_REQUIRES')
        if $mm_version < 6.63_03;

    $merge_key_into->('CONFIGURE_REQUIRES', 'BUILD_REQUIRES')
        if $mm_version < 6.55_01;

    $merge_key_into->('PREREQ_PM', 'CONFIGURE_REQUIRES')
        if $mm_version < 6.51_03;
}

delete $settings{MIN_PERL_VERSION} if $mm_version < 6.47_01;
delete $settings{META_MERGE}       if $mm_version < 6.46;
delete $settings{LICENSE}          if $mm_version < 6.30_01;
delete $settings{ABSTRACT_FROM}    if $mm_version < 6.06_03;
delete $settings{AUTHOR}           if $mm_version < 6.06_03;

WriteMakefile %settings;
