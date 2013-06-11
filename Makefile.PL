use strict;
use warnings;
use ExtUtils::MakeMaker;

sub merge_key_into {
	my ($href, $target, $source) = @_;
	%{$href->{$target}} = (%{$href->{$target}}, %{delete $href->{$source}});
}

my %opt = (
	NAME          => 'Function::Parameters',
	AUTHOR        => q{Lukas Mai <l.mai@web.de>},
	VERSION_FROM  => 'lib/Function/Parameters.pm',
	ABSTRACT_FROM => 'lib/Function/Parameters.pm',

	LICENSE => 'perl',
	PL_FILES => {},

	MIN_PERL_VERSION => '5.14.0',
	CONFIGURE_REQUIRES => {
		'strict' => 0,
		'warnings' => 0,
		'ExtUtils::MakeMaker' => '6.48',
	},
	BUILD_REQUIRES => {},
	TEST_REQUIRES => {
		'constant' => 0,
		'strict' => 0,
		'utf8' => 0,
		'Dir::Self' => 0,
		'Test::More' => 0,
		'Test::Fatal' => 0,
	},
	PREREQ_PM => {
		'Carp' => 0,
		'XSLoader' => 0,
		'warnings' => 0,
	},

	depend => { Makefile => '$(VERSION_FROM)' },
	test   => { TESTS    => 't/*.t t/foreign/*.t t/foreign/*/*.t' },
	dist   => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean  => { FILES    => 'Function-Parameters-*' },

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
);

if (ExtUtils::MakeMaker->VERSION < 6.67_04) {
	# Why? For the glory of satan, of course!
	no warnings qw(redefine);
	*ExtUtils::MM_Any::_add_requirements_to_meta_v1_4 = \&ExtUtils::MM_Any::_add_requirements_to_meta_v2;
}

if (ExtUtils::MakeMaker->VERSION < 6.63_03) {
	merge_key_into \%opt, 'BUILD_REQUIRES', 'TEST_REQUIRES';
}

if (ExtUtils::MakeMaker->VERSION < 6.55_01) {
	merge_key_into \%opt, 'CONFIGURE_REQUIRES', 'BUILD_REQUIRES';
}

if (ExtUtils::MakeMaker->VERSION < 6.51_03) {
	merge_key_into \%opt, 'PREREQ_PM', 'CONFIGURE_REQUIRES';
}

WriteMakefile %opt;
