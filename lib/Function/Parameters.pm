package Function::Parameters;

use strict;
use warnings;

our $VERSION = '0.03';

use Devel::Declare;
use B::Hooks::EndOfScope;
use B::Compiling;

sub guess_caller {
	my ($start) = @_;
	$start ||= 1;

	my $defcaller = (caller $start)[0];
	my $caller = $defcaller;

	for (my $level = $start; ; ++$level) {
		my ($pkg, $function) = (caller $level)[0, 3] or last;
		#warn "? $pkg, $function";
		$function =~ /::import\z/ or return $caller;
		$caller = $pkg;
	}
	$defcaller
}

sub _fun ($) { $_[0] }

sub _croak {
	require Carp;
	{
		no warnings qw(redefine);
		*_croak = \&Carp::croak;
	}
	goto &Carp::croak;
}

sub import {
	my $class = shift;
	my $keyword = @_ ? shift : 'fun';
	my $caller = guess_caller;
	#warn "caller = $caller";
	
	_croak qq{"$_" is not exported by the $class module} for @_;

	$keyword =~ /^[[:alpha:]_]\w*\z/ or _croak qq{"$keyword" does not look like a valid identifier};

	Devel::Declare->setup_for(
		$caller,
		{ $keyword => { const => \&parser } }
	);

	no strict 'refs';
	*{$caller . '::' . $keyword} = \&_fun;
}

sub report_pos {
	my ($offset, $name) = @_;
	$name ||= '';
	my $line = Devel::Declare::get_linestr();
	substr $line, $offset + 1, 0, "\x{20de}\e[m";
	substr $line, $offset, 0, "\e[31;1m";
	print STDERR "$name($offset)>> $line\n";
}

sub parser {
	my ($declarator, $start) = @_;
	my $offset = $start;
	my $line = Devel::Declare::get_linestr();

	my $fail = do {
		my $_file = PL_compiling->file;
		my $_line = PL_compiling->line;
		sub {
			my $n = $_line + substr($line, $start, $offset - $start) =~ tr[\n][];
			die join('', @_) . " at $_file line $n\n";
		}
	};

	my $atomically = sub {
		my ($pars) = @_;
		sub {
			my $tmp = $offset;
			my @ret = eval { $pars->(@_) };
			if ($@) {
				$offset = $tmp;
				die $@;
			}
			wantarray ? @ret : $ret[0]
		}
	};

	my $try = sub {
		my ($pars) = @_;
		my @ret = eval { $pars->() };
		if ($@) {
			return;
		}
		wantarray ? @ret : $ret[0]
	};

	my $skipws = sub {
		#warn ">> $line";
		my $skip = Devel::Declare::toke_skipspace($offset);
		if ($skip < 0) {
			$skip == -$offset or die "Internal error: offset=$offset, skip=$skip";
			Devel::Declare::set_linestr($line);
			return;
		}
		$line = Devel::Declare::get_linestr();
		#warn "toke_skipspace($offset) = $skip\n== $line";
		$offset += $skip;
	};

	$offset += Devel::Declare::toke_move_past_token($offset);
	$skipws->();
	my $manip_start = $offset;

	my $name;
	if (my $len = Devel::Declare::toke_scan_word($offset, 1)) {
		$name = substr $line, $offset, $len;
		$offset += $len;
		$skipws->();
	}

	my $scan_token = sub {
		my ($str) = @_;
		my $len = length $str;
		substr($line, $offset, $len) eq $str or $fail->(qq{Missing "$str"});
		$offset += $len;
		$skipws->();
	};

	my $scan_id = sub {
		my $len = Devel::Declare::toke_scan_word($offset, 0) or $fail->('Missing identifier');
		my $name = substr $line, $offset, $len;
		$offset += $len;
		$skipws->();
		$name
	};

	my $scan_var = $atomically->(sub {
		(my $sigil = substr($line, $offset, 1)) =~ /^[\$\@%]\z/ or $fail->('Missing [$@%]');
		$offset += 1;
		$skipws->();
		my $name = $scan_id->();
		$sigil . $name
	});

	my $separated_by = $atomically->(sub {
		my ($sep, $pars) = @_;
		my $len = length $sep;
		defined(my $x = $try->($pars)) or return;
		my @res = $x;
		while () {
			substr($line, $offset, $len) eq $sep or return @res;
			$offset += $len;
			$skipws->();
			push @res, $pars->();
		}
	});

	my $many_till = $atomically->(sub {
		my ($end, $pars) = @_;
		my $len = length $end;
		my @res;
		until (substr($line, $offset, $len) eq $end) {
			push @res, $pars->();
		}
		@res
	});

	my $scan_params = $atomically->(sub {
		if ($try->(sub { $scan_token->('('); 1 })) {
			my @param = $separated_by->(',', $scan_var);
			$scan_token->(')');
			return @param;
		}
		$try->($scan_var)
	});

	my @param = $scan_params->();

	my $scan_pargroup_opt = sub {
		substr($line, $offset, 1) eq '(' or return '';
		my $len = Devel::Declare::toke_scan_str($offset);
		my $res = Devel::Declare::get_lex_stuff();
		Devel::Declare::clear_lex_stuff();
		$res eq '' and $fail->(qq{Can't find ")" anywhere before EOF});
		$offset += $len;
		$skipws->();
		"($res)"
	};

	my $scan_attr = sub {
		my $name = $scan_id->();
		my $param = $scan_pargroup_opt->() || '';
		$name . $param
	};

	my $scan_attributes = $atomically->(sub {
		$try->(sub { $scan_token->(':'); 1 }) or return '', [];
		my $proto = $scan_pargroup_opt->();
		my @attrs = $many_till->('{', $scan_attr);
		' ' . $proto, \@attrs
	});

	my ($proto, $attributes) = $scan_attributes->();
	my $attr = @$attributes ? ' : ' . join(' ', @$attributes) : '';

	$scan_token->('{');

	my $manip_end = $offset;
	my $manip_len = $manip_end - $manip_start;
	#print STDERR "($manip_start:$manip_len:$manip_end)\n";

	my $params = @param ? 'my (' . join(', ', @param) . ') = @_;' : '';
	#report_pos $offset;
	$proto =~ tr[\n][ ];

	if (defined $name) {
		my $pkg = __PACKAGE__;
		#print STDERR "($manip_start:$manip_len) [$line]\n";
		substr $line, $manip_start, $manip_len, " do { sub $name$proto; sub $name$proto$attr { BEGIN { ${pkg}::terminate_me(q[$name]); } $params ";
	} else {
		substr $line, $manip_start, $manip_len, " sub$proto$attr { $params ";
	}
	#print STDERR ".> $line\n";
	Devel::Declare::set_linestr($line);
}

sub terminate_me {
	my ($name) = @_;
	on_scope_end {
		my $line = Devel::Declare::get_linestr();
		#print STDERR "~~> $line\n";
		my $offset = Devel::Declare::get_linestr_offset();
		substr $line, $offset, 0, " \\&$name };";
		Devel::Declare::set_linestr($line);
		#print STDERR "??> $line\n";
	};
}

1

__END__

=head1 NAME

Function::Parameters - subroutine definitions with parameter lists

=head1 SYNOPSIS

 use Function::Parameters;
 
 fun foo($bar, $baz) {
   return $bar + $baz;
 }
 
 fun mymap($fun, @args) :(&@) {
   my @res;
   for (@args) {
     push @res, $fun->($_);
   }
   @res
 }
 
 print "$_\n" for mymap { $_ * 2 } 1 .. 4;

 use Function::Parameters 'proc';
 my $f = proc ($x) { $x * 2 };
 
=head1 DESCRIPTION

This module lets you use parameter lists in your subroutines. Thanks to
L<Devel::Declare> it works without source filters.

WARNING: This is my first attempt at using L<Devel::Declare> and I have
almost no experience with perl's internals. So while this module might
appear to work, it could also conceivably make your programs segfault.
Consider this module alpha quality.

=head2 Basic stuff

To use this new functionality, you have to use C<fun> instead of C<sub> -
C<sub> continues to work as before. The syntax is almost the same as for
C<sub>, but after the subroutine name (or directly after C<fun> if you're
writing an anonymous sub) you can write a parameter list in parens. This
list consists of comma-separated variables.

The effect of C<fun foo($bar, $baz) {> is as if you'd written
C<sub foo { my ($bar, $baz) = @_; >, i.e. the parameter list is simply
copied into C<my> and initialized from L<@_|perlvar/"@_">.

=head2 Advanced stuff

You can change the name of the new keyword from C<fun> to anything you want by
specifying it in the import list, i.e. C<use Function::Parameters 'spork'> lets
you write C<spork> instead of C<fun>.

If you need L<subroutine attributes|perlsub/"Subroutine Attributes">, you can
put them after the parameter list with their usual syntax. There's one
exception, though: you can only use one colon (to start the attribute list);
multiple attributes have to be separated by spaces.

Syntactically, these new parameter lists live in the spot normally occupied
by L<prototypes|perlsub/"Prototypes">. However, you can include a prototype by
specifying it as the first attribute (this is syntactically unambiguous
because normal attributes have to start with a letter).

Normally, Perl subroutines are not in scope in their own body, meaning the
parser doesn't know the name C<foo> or its prototype when processing
C<sub foo ($) { foo $bar[1], $bar[0]; }>, parsing it as
C<$bar-E<gt>foo([1], $bar[0])>. Yes. You can add parens to change the
interpretation of this code, but C<foo($bar[1], $bar[0])> will only trigger
a I<foo() called too early to check prototype> warning. This module attempts
to fix all of this by adding a subroutine declaration before the definition,
so the parser knows the name (and possibly prototype) while it processes the
body. Thus C<fun foo($x) :($) { $x }> really turns into
C<sub foo ($); sub foo ($) { my ($x) = @_; $x }>.

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
