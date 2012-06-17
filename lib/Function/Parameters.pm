package Function::Parameters;

use strict;
use warnings;

use XSLoader;
BEGIN {
	our $VERSION = '0.05_01';
	XSLoader::load;
}

use B::Hooks::EndOfScope qw(on_scope_end);
use Carp qw(confess);
use bytes ();

sub _assert_valid_identifier {
	my ($name, $with_dollar) = @_;
	my $bonus = $with_dollar ? '\$' : '';
	$name =~ /^${bonus}[^\W\d]\w*\z/
		or confess qq{"$name" doesn't look like a valid identifier};
}

my @bare_arms = qw(function method);
my %type_map = (
	function => { name => 'optional' },
	method   => { name => 'optional', shift => '$self' },
);

sub import {
	my $class = shift;

	@_ or @_ = ('fun', 'method');
	if (@_ == 1 && ref($_[0]) eq 'HASH') {
		@_ = map [$_, $_[0]{$_}], keys %{$_[0]}
			or return;
	}

	my %spec;

	my $bare = 0;
	for my $proto (@_) {
		my $item = ref $proto
			? $proto
			: [$proto, $bare_arms[$bare++] || confess(qq{Don't know what to do with "$proto"})]
		;
		my ($name, $type) = @$item;
		_assert_valid_identifier $name;

		unless (ref $type) {
			# use '||' instead of 'or' to preserve $type in the error message
			$type = $type_map{$type}
				|| confess qq["$type" doesn't look like a valid type (one of ${\join ', ', sort keys %type_map})];
		}
		$type->{name} ||= 'optional';
		$type->{name} =~ /^(?:optional|required|prohibited)\z/
			or confess qq["$type->{name}" doesn't look like a valid name attribute (one of optional, required, prohibited)];
		if ($type->{shift}) {
			_assert_valid_identifier $type->{shift}, 1;
			bytes::length($type->{shift}) < SHIFT_NAME_LIMIT
				or confess qq["$type->{shift}" is longer than I can handle];
		}
		
		$spec{$name} = $type;
	}
	
	for my $kw (keys %spec) {
		my $type = $spec{$kw};

		$^H{HINTK_SHIFT_ . $kw} = $type->{shift} || '';
		$^H{HINTK_NAME_ . $kw} =
			$type->{name} eq 'prohibited' ? FLAG_NAME_PROHIBITED :
			$type->{name} eq 'required' ? FLAG_NAME_REQUIRED :
			FLAG_NAME_OPTIONAL
		;
		$^H{+HINTK_KEYWORDS} .= "$kw ";
	}
}

sub unimport {
	my $class = shift;

	if (!@_) {
		delete $^H{+HINTK_KEYWORDS};
		return;
	}

	for my $kw (@_) {
		$^H{+HINTK_KEYWORDS} =~ s/(?<![^ ])\Q$kw\E //g;
	}
}

sub _fini {
	on_scope_end {
		xs_fini;
	};
}


'ok'

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
 
 method set_name($name) {
   $self->{name} = $name;
 }

=cut

=pod

 use Function::Parameters 'proc', 'meth';
 
 my $f = proc ($x) { $x * 2 };
 meth get_age() {
   return $self->{age};
 }

=head1 DESCRIPTION

This module lets you use parameter lists in your subroutines. Thanks to
L<perlapi/PL_keyword_plugin> it works without source filters.

WARNING: This is my first attempt at writing L<XS code|perlxs> and I have
almost no experience with perl's internals. So while this module might
appear to work, it could also conceivably make your programs segfault.
Consider this module alpha quality.

=head2 Basic stuff

To use this new functionality, you have to use C<fun> instead of C<sub> -
C<sub> continues to work as before. The syntax is almost the same as for
C<sub>, but after the subroutine name (or directly after C<fun> if you're
writing an anonymous sub) you can write a parameter list in parentheses. This
list consists of comma-separated variables.

The effect of C<fun foo($bar, $baz) {> is as if you'd written
C<sub foo { my ($bar, $baz) = @_; >, i.e. the parameter list is simply
copied into C<my> and initialized from L<@_|perlvar/"@_">.

In addition you can use C<method>, which understands the same syntax as C<fun>
but automatically creates a C<$self> variable for you. So by writing
C<method foo($bar, $baz) {> you get the same effect as
C<sub foo { my $self = shift; my ($bar, $baz) = @_; >.

=head2 Customizing the generated keywords

You can customize the names of the keywords injected in your package. To do that
you pass a hash reference in the import list:

 use Function::Parameters { proc => 'function', meth => 'method' }; # -or-
 use Function::Parameters { proc => 'function' }; # -or-
 use Function::Parameters { meth => 'method' };

The first line creates two keywords, C<proc> and C<meth> (for defining
functions and methods, respectively). The last two lines only create one
keyword. Generally the hash keys can be any identifiers you want while the
values have to be either C<function>, C<method>, or a hash reference (see
below). The difference between C<function> and C<method> is that C<method>s
automatically L<shift|perlfunc/shift> their first argument into C<$self>.

The following shortcuts are available:

 use Function::Parameters;
    # is equivalent to #
 use Function::Parameters { fun => 'function', method => 'method' };

=cut

=pod

 use Function::Parameters 'foo';
   # is equivalent to #
 use Function::Parameters { 'foo' => 'function' };

=cut

=pod

 use Function::Parameters 'foo', 'bar';
   # is equivalent to #
 use Function::Parameters { 'foo' => 'function', 'bar' => 'method' };

You can customize things even more by passing a hashref instead of C<function>
or C<method>. This hash can have the following keys:

=over

=item C<name>

Valid values: C<optional> (default), C<required> (all uses of this keyword must
specify a function name), and C<prohibited> (all uses of this keyword must not
specify a function name). This means a C<< name => 'prohibited' >> keyword can
only be used for defining anonymous functions.

=item C<shift>

Valid values: strings that look like a scalar variable. Any function created by
this keyword will automatically L<shift|perlfunc/shift> its first argument into
a local variable with the name specified here.

=back

Plain C<function> is equivalent to C<< { name => 'optional' } >>, and plain
C<method> is equivalent to C<< { name => 'optional', shift => '$self'} >>.

=head2 Other advanced stuff

Normally, Perl subroutines are not in scope in their own body, meaning the
parser doesn't know the name C<foo> or its prototype while processing
C<sub foo ($) { foo $bar[1], $bar[0]; }>, parsing it as
C<$bar-E<gt>foo([1], $bar[0])>. Yes. You can add parens to change the
interpretation of this code, but C<foo($bar[1], $bar[0])> will only trigger
a I<foo() called too early to check prototype> warning. This module attempts
to fix all of this by adding a subroutine declaration before the definition,
so the parser knows the name (and possibly prototype) while it processes the
body. Thus C<fun foo($x) :($) { $x }> really turns into
C<sub foo ($); sub foo ($) { my ($x) = @_; $x }>.

If you need L<subroutine attributes|perlsub/"Subroutine Attributes">, you can
put them after the parameter list with their usual syntax.

Syntactically, these new parameter lists live in the spot normally occupied
by L<prototypes|perlsub/"Prototypes">. However, you can include a prototype by
specifying it as the first attribute (this is syntactically unambiguous
because normal attributes have to start with a letter).

If you want to wrap L<Function::Parameters>, you just have to call its
C<import> method. It always applies to the file that is currently being parsed
and its effects are lexical (i.e. it works like L<warnings> or L<strict>);

  package Some::Wrapper;
  use Function::Parameters ();
  sub import {
    Function::Parameters->import;
    # or Function::Parameters->import(@other_import_args);
  }

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010, 2011, 2012 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
