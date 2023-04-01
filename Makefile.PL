use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Spec ();
use File::Find ();

sub MY::postamble {
    my ($self, %args) = @_;
    if ((my $harness_options = delete $args{HARNESS_OPTIONS}) && $self->can('is_make_type')) {
        my $value = join ':', @$harness_options;
        if ($self->is_make_type('gmake')) {
            $args{text} .= "export HARNESS_OPTIONS := $value\n";
        } elsif ($self->is_make_type('nmake')) {
            $args{text} .= "!if [set HARNESS_OPTIONS=$value]\n!endif\n";
        }
    }
    $args{text} || ''
}

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

$::MAINT_MODE = !-f 'META.yml';
my $settings_file = 'Makefile_PL_settings.plx';
my %settings = %{do "./$settings_file" or die "Internal error: can't do $settings_file: ", $@ || $!};

(do './maint/eumm-fixup.pl' || die $@ || $!)->(\%settings) if $::MAINT_MODE;

{
    $settings{depend}{Makefile} .= " $settings_file";
    $settings{LICENSE} ||= 'perl';
    $settings{PL_FILES} ||= {};

    $settings{CONFIGURE_REQUIRES}{strict}                ||= 0;
    $settings{CONFIGURE_REQUIRES}{warnings}              ||= 0;
    $settings{CONFIGURE_REQUIRES}{'File::Find'}          ||= 0;
    $settings{CONFIGURE_REQUIRES}{'File::Spec'}          ||= 0;
    for my $stage (qw(CONFIGURE BUILD)) {
        for ($settings{$stage . '_REQUIRES'}{'ExtUtils::MakeMaker'}) {
            $_ = '7.0' if !$_ || $_ < 7;
        }
    }

    my $module_file = $settings{NAME};
    $module_file =~ s!::!/!g;
    $module_file = "lib/$module_file.pm";

    $settings{VERSION_FROM}  ||= $module_file;
    $settings{ABSTRACT_FROM} ||= $module_file;

    $settings{test}{TESTS} ||= do {
        my $extra_test_dirs = delete $settings{EXTRA_TEST_DIRS};
        join ' ', map find_tests_recursively_in($_), 't', @{$extra_test_dirs || []}
    };

    $settings{DISTNAME} ||= do {
        my $name = $settings{NAME};
        $name =~ s!::!-!g;
        $name
    };

    $settings{clean}{FILES} ||= "$settings{DISTNAME}-*";

    $settings{dist}{COMPRESS} ||= 'gzip -9f';
    $settings{dist}{SUFFIX}   ||= '.gz';

    my $version = $settings{VERSION} || MM->parse_version($settings{VERSION_FROM});
    if ($version =~ s/-TRIAL[0-9]*\z//) {
        $settings{META_MERGE}{release_status} ||= 'unstable';
        $settings{META_MERGE}{version} ||= $version;
        $settings{XS_VERSION} ||= $version;
    }

    $settings{META_MERGE}{'meta-spec'}{version} ||= 2;
    $settings{META_MERGE}{dynamic_config} ||= 0;

    push @{$settings{META_MERGE}{no_index}{directory}}, 'xt';
    if (my $dev = delete $settings{DEVELOP_REQUIRES}) {
        @{$settings{META_MERGE}{prereqs}{develop}{requires}}{keys %$dev} = values %$dev;
    }
    if (my $rec = delete $settings{RECOMMENDS}) {
        @{$settings{META_MERGE}{prereqs}{runtime}{recommends}}{keys %$rec} = values %$rec;
    }

    if (my $sug = delete $settings{SUGGESTS}) {
        @{$settings{META_MERGE}{prereqs}{runtime}{suggests}}{keys %$sug} = values %$sug;
    }

    if (my $repo = delete $settings{REPOSITORY}) {
        if (ref($repo) eq 'ARRAY') {
            my ($type, @args) = @$repo;
            if ($type eq 'github') {
                my ($account, $project) = @args;
                $project ||= '%d';
                $project =~ s{%(L?)(.)}{
                    my $x =
                        $2 eq '%' ? '%' :
                        $2 eq 'd' ? $settings{DISTNAME} :
                        $2 eq 'm' ? $settings{NAME} :
                        die "Internal error: unknown placeholder %$1$2";
                    $1 ? lc($x) : $x
                }seg;
                my $addr = "github.com/$account/$project";
                $repo = {
                    type => 'git',
                    url  => "git://$addr",
                    web  => "https://$addr",
                };
            } else {
                die "Internal error: unknown REPOSITORY type '$type'";
            }
        }
        ref($repo) eq 'HASH' or die "Internal error: REPOSITORY must be a hashref, not $repo";
        @{$settings{META_MERGE}{resources}{repository}}{keys %$repo} = values %$repo;
    }

    if (my $harness_options = delete $settings{HARNESS_OPTIONS}) {
        $settings{postamble}{HARNESS_OPTIONS} = $harness_options;
    }
}

WriteMakefile %settings;
