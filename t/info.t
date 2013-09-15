#!perl
use warnings FATAL => 'all';
use strict;

use Test::More
	eval { require Moo }
	? (tests => 122)
	: (skip_all => "Moo required for testing parameter introspection")
;

use Function::Parameters;

sub Inf () { 0 + 'Inf' }

fun foo($pr1, $pr2, $po1 = 1, $po2 = 2, :$no1 = 3, :$no2 = 4, %r) {}

{
	my $info = Function::Parameters::info \&foo;
	is $info->keyword, 'fun';
	is $info->invocant, undef;
	is_deeply [$info->positional_required], [qw($pr1 $pr2)];
	is scalar $info->positional_required, 2;
	is_deeply [$info->positional_optional], [qw($po1 $po2)];
	is scalar $info->positional_optional, 2;
	is_deeply [$info->named_required], [];
	is scalar $info->named_required, 0;
	is_deeply [$info->named_optional], [qw($no1 $no2)];
	is scalar $info->named_optional, 2;
	is $info->slurpy, '%r';
	is $info->args_min, 2;
	is $info->args_max, Inf;
}

{
	my $info = Function::Parameters::info fun ($pr1, :$nr1, :$nr2) {};
	is $info->keyword, 'fun';
	is $info->invocant, undef;
	is_deeply [$info->positional_required], [qw($pr1)];
	is scalar $info->positional_required, 1;
	is_deeply [$info->positional_optional], [];
	is scalar $info->positional_optional, 0;
	is_deeply [$info->named_required], [qw($nr1 $nr2)];
	is scalar $info->named_required, 2;
	is_deeply [$info->named_optional], [];
	is scalar $info->named_optional, 0;
	is $info->slurpy, undef;
	is $info->args_min, 5;
	is $info->args_max, Inf;
}

sub bar {}

is Function::Parameters::info(\&bar), undef;

is Function::Parameters::info(sub {}), undef;

method baz($class: $po1 = 1, $po2 = 2, $po3 = 3, :$no1 = 4, @rem) {}

{
	my $info = Function::Parameters::info \&baz;
	is $info->keyword, 'method';
	is $info->invocant, '$class';
	is_deeply [$info->positional_required], [];
	is scalar $info->positional_required, 0;
	is_deeply [$info->positional_optional], [qw($po1 $po2 $po3)];
	is scalar $info->positional_optional, 3;
	is_deeply [$info->named_required], [];
	is scalar $info->named_required, 0;
	is_deeply [$info->named_optional], [qw($no1)];
	is scalar $info->named_optional, 1;
	is $info->slurpy, '@rem';
	is $info->args_min, 1;
	is $info->args_max, Inf;
}

{
	my $info = Function::Parameters::info method () {};
	is $info->keyword, 'method';
	is $info->invocant, '$self';
	is_deeply [$info->positional_required], [];
	is scalar $info->positional_required, 0;
	is_deeply [$info->positional_optional], [];
	is scalar $info->positional_optional, 0;
	is_deeply [$info->named_required], [];
	is scalar $info->named_required, 0;
	is_deeply [$info->named_optional], [];
	is scalar $info->named_optional, 0;
	is $info->slurpy, undef;
	is $info->args_min, 1;
	is $info->args_max, 1;
}

{
	use Function::Parameters { proc => 'function' };
	my $info = Function::Parameters::info proc {};
	is $info->keyword, 'proc';
	is $info->invocant, undef;
	is_deeply [$info->positional_required], [];
	is scalar $info->positional_required, 0;
	is_deeply [$info->positional_optional], [];
	is scalar $info->positional_optional, 0;
	is_deeply [$info->named_required], [];
	is scalar $info->named_required, 0;
	is_deeply [$info->named_optional], [];
	is scalar $info->named_optional, 0;
	is $info->slurpy, '@_';
	is $info->args_min, 0;
	is $info->args_max, Inf;
}

{
	my $info = Function::Parameters::info method {};
	is $info->keyword, 'method';
	is $info->invocant, '$self';
	is_deeply [$info->positional_required], [];
	is scalar $info->positional_required, 0;
	is_deeply [$info->positional_optional], [];
	is scalar $info->positional_optional, 0;
	is_deeply [$info->named_required], [];
	is scalar $info->named_required, 0;
	is_deeply [$info->named_optional], [];
	is scalar $info->named_optional, 0;
	is $info->slurpy, '@_';
	is $info->args_min, 1;
	is $info->args_max, Inf;
}

{
	my @fs;
	for my $i (qw(aku soku zan)) {
		push @fs, [$i => fun (:$sin, :$swift, :$slay) { $i }];
	}
	for my $kf (@fs) {
		my ($i, $f) = @$kf;
		my $info = Function::Parameters::info $f;
		is $info->keyword, 'fun';
		is $info->invocant, undef;
		is_deeply [$info->positional_required], [];
		is scalar $info->positional_required, 0;
		is_deeply [$info->positional_optional], [];
		is scalar $info->positional_optional, 0;
		is_deeply [$info->named_required], [qw($sin $swift $slay)];
		is scalar $info->named_required, 3;
		is_deeply [$info->named_optional], [];
		is scalar $info->named_optional, 0;
		is $info->slurpy, undef;
		is $info->args_min, 6;
		is $info->args_max, Inf;
		is $f->(), $i;
	}
}
