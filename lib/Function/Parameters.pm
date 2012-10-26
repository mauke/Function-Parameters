package Function::Parameters;

use v5.14.0;

use strict;
use warnings;

use Carp qw(confess);

use XSLoader;
BEGIN {
	our $VERSION = '0.10_01';
	XSLoader::load;
}

sub _assert_valid_identifier {
	my ($name, $with_dollar) = @_;
	my $bonus = $with_dollar ? '\$' : '';
	$name =~ /^${bonus}[^\W\d]\w*\z/
		or confess qq{"$name" doesn't look like a valid identifier};
}

sub _assert_valid_attributes {
	my ($attrs) = @_;
	$attrs =~ /^\s*:\s*[^\W\d]\w*\s*(?:(?:\s|:\s*)[^\W\d]\w*\s*)*(?:\(|\z)/
		or confess qq{"$attrs" doesn't look like valid attributes};
}

my @bare_arms = qw(function method);
my %type_map = (
	function => {
		name => 'optional',
		default_arguments => 1,
		check_argument_count => 0,
		named_parameters => 1,
	},
	method   => {
		name => 'optional',
		default_arguments => 1,
		check_argument_count => 0,
		named_parameters => 1,
		attrs => ':method',
		shift => '$self',
		invocant => 1,
	},
	classmethod   => {
		name => 'optional',
		default_arguments => 1,
		check_argument_count => 0,
		named_parameters => 1,
		attributes => ':method',
		shift => '$class',
		invocant => 1,
	},
);
for my $k (keys %type_map) {
	$type_map{$k . '_strict'} = {
		%{$type_map{$k}},
		check_argument_count => 1,
	};
}

sub import {
	my $class = shift;

	if (!@_) {
		@_ = {
			fun => 'function',
			method => 'method',
		};
	}
	if (@_ == 1 && $_[0] eq ':strict') {
		@_ = {
			fun => 'function_strict',
			method => 'method_strict',
		};
	}
	if (@_ == 1 && ref($_[0]) eq 'HASH') {
		@_ = map [$_, $_[0]{$_}], keys %{$_[0]};
	}

	my %spec;

	my $bare = 0;
	for my $proto (@_) {
		my $item = ref $proto
			? $proto
			: [$proto, $bare_arms[$bare++] || confess(qq{Don't know what to do with "$proto"})]
		;
		my ($name, $proto_type) = @$item;
		_assert_valid_identifier $name;

		unless (ref $proto_type) {
			# use '||' instead of 'or' to preserve $proto_type in the error message
			$proto_type = $type_map{$proto_type}
				|| confess qq["$proto_type" doesn't look like a valid type (one of ${\join ', ', sort keys %type_map})];
		}

		my %type = %$proto_type;
		my %clean;

		$clean{name} = delete $type{name} || 'optional';
		$clean{name} =~ /^(?:optional|required|prohibited)\z/
			or confess qq["$clean{name}" doesn't look like a valid name attribute (one of optional, required, prohibited)];

		$clean{shift} = delete $type{shift} || '';
		_assert_valid_identifier $clean{shift}, 1 if $clean{shift};

		$clean{attrs} = join ' ', map delete $type{$_} || (), qw(attributes attrs);
		_assert_valid_attributes $clean{attrs} if $clean{attrs};
		
		$clean{default_arguments} =
			exists $type{default_arguments}
			? !!delete $type{default_arguments}
			: 1
		;
		$clean{check_argument_count} = !!delete $type{check_argument_count};
		$clean{invocant} = !!delete $type{invocant};
		$clean{named_parameters} = !!delete $type{named_parameters};

		%type and confess "Invalid keyword property: @{[keys %type]}";

		$spec{$name} = \%clean;
	}
	
	for my $kw (keys %spec) {
		my $type = $spec{$kw};

		my $flags =
			$type->{name} eq 'prohibited' ? FLAG_ANON_OK :
			$type->{name} eq 'required' ? FLAG_NAME_OK :
			FLAG_ANON_OK | FLAG_NAME_OK
		;
		$flags |= FLAG_DEFAULT_ARGS if $type->{default_arguments};
		$flags |= FLAG_CHECK_NARGS if $type->{check_argument_count};
		$flags |= FLAG_INVOCANT if $type->{invocant};
		$flags |= FLAG_NAMED_PARAMS if $type->{named_parameters};
		$^H{HINTK_FLAGS_ . $kw} = $flags;
		$^H{HINTK_SHIFT_ . $kw} = $type->{shift};
		$^H{HINTK_ATTRS_ . $kw} = $type->{attrs};
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


'ok'

__END__

=encoding UTF-8

=head1 NAME

Function::Parameters - subroutine definitions with parameter lists

=head1 SYNOPSIS

 use Function::Parameters;
 
 # simple function
 fun foo($bar, $baz) {
   return $bar + $baz;
 }
 
 # function with prototype
 fun mymap($fun, @args)
   :(&@)
 {
   my @res;
   for (@args) {
     push @res, $fun->($_);
   }
   @res
 }
 
 print "$_\n" for mymap { $_ * 2 } 1 .. 4;
 
 # method with implicit $self
 method set_name($name) {
   $self->{name} = $name;
 }
 
 # method with explicit invocant
 method new($class: %init) {
   return bless { %init }, $class;
 }
 
 # function with default arguments
 fun search($haystack, $needle = qr/^(?!)/, $offset = 0) {
   ...
 }
 
 # method with default arguments
 method skip($amount = 1) {
   $self->{position} += $amount;
 }

=cut

=pod

 use Function::Parameters qw(:strict);
 
 fun greet($x) {
   print "Hello, $x\n";
 }
 
 greet "foo", "bar";
 # Dies at runtime with "Too many arguments for fun greet"
 
 greet;
 # Dies at runtime with "Not enough arguments for fun greet"

=cut

=pod

 # use different keywords
 use Function::Parameters {
   proc => 'function',
   meth => 'method',
 };
 
 my $f = proc ($x) { $x * 2 };
 meth get_age() {
   return $self->{age};
 }

=head1 DESCRIPTION

This module lets you use parameter lists in your subroutines. Thanks to
L<PL_keyword_plugin|perlapi/PL_keyword_plugin> it works without source filters.

=head2 Basic stuff

To use this new functionality, you have to use C<fun> instead of C<sub> -
C<sub> continues to work as before. The syntax is almost the same as for
C<sub>, but after the subroutine name (or directly after C<fun> if you're
writing an anonymous sub) you can write a parameter list in parentheses. This
list consists of comma-separated variables.

The effect of C<fun foo($bar, $baz) {> is as if you'd written
C<sub foo { my ($bar, $baz) = @_; >, i.e. the parameter list is simply
copied into L<my|perlfunc/my-EXPR> and initialized from L<@_|perlvar/"@_">.

In addition you can use C<method>, which understands the same syntax as C<fun>
but automatically creates a C<$self> variable for you. So by writing
C<method foo($bar, $baz) {> you get the same effect as
C<sub foo { my $self = shift; my ($bar, $baz) = @_; >.

=head2 Customizing the generated keywords

You can customize the names of the keywords injected into your scope. To do
that you pass a reference to a hash mapping keywords to types in the import
list:

 use Function::Parameters {
   KEYWORD1 => TYPE1,
   KEYWORD2 => TYPE2,
   ...
 };

Or more concretely:

 use Function::Parameters { proc => 'function', meth => 'method' }; # -or-
 use Function::Parameters { proc => 'function' }; # -or-
 use Function::Parameters { meth => 'method' }; # etc.

The first line creates two keywords, C<proc> and C<meth> (for defining
functions and methods, respectively). The last two lines only create one
keyword. Generally the hash keys (keywords) can be any identifiers you want
while the values (types) have to be either a hash reference (see below) or
C<'function'>, C<'method'>, C<'classmethod'>, C<'function_strict'>,
C<'method_strict'>, or C<'classmethod_strict'>. The main difference between
C<'function'> and C<'method'> is that C<'method'>s automatically
L<shift|perlfunc/shift> their first argument into C<$self> (C<'classmethod'>s
are similar but shift into C<$class>).

The following shortcuts are available:

 use Function::Parameters;
    # is equivalent to #
 use Function::Parameters { fun => 'function', method => 'method' };

=cut

=pod

 use Function::Parameters ':strict';
    # is equivalent to #
 use Function::Parameters { fun => 'function_strict', method => 'method_strict' };

=pod

The following shortcuts are deprecated and may be removed from a future version
of this module:

 # DEPRECATED
 use Function::Parameters 'foo';
   # is equivalent to #
 use Function::Parameters { 'foo' => 'function' };

=cut

=pod

 # DEPRECATED
 use Function::Parameters 'foo', 'bar';
   # is equivalent to #
 use Function::Parameters { 'foo' => 'function', 'bar' => 'method' };

That is, if you want to create custom keywords with L<Function::Parameters>,
use a hashref, not a list of strings.

You can tune the properties of the generated keywords even more by passing
a hashref instead of a string. This hash can have the following keys:

=over

=item C<name>

Valid values: C<optional> (default), C<required> (all uses of this keyword must
specify a function name), and C<prohibited> (all uses of this keyword must not
specify a function name). This means a C<< name => 'prohibited' >> keyword can
only be used for defining anonymous functions.

=item C<shift>

Valid values: strings that look like a scalar variable. Any function created by
this keyword will automatically L<shift|perlfunc/shift> its first argument into
a local variable whose name is specified here.

=item C<invocant>

Valid values: booleans. This lets users of this keyword specify an explicit
invocant, that is, the first parameter may be followed by a C<:> (colon)
instead of a comma and will by initialized by shifting the first element off
C<@_>.

You can combine C<shift> and C<invocant>, in which case the variable named in
C<shift> serves as a default shift target for functions that don't specify an
explicit invocant.

=item C<attributes>, C<attrs>

Valid values: strings that are valid source code for attributes. Any value
specified here will be inserted as a subroutine attribute in the generated
code. Thus:

 use Function::Parameters { sub_l => { attributes => ':lvalue' } };
 sub_l foo() {
   ...
 }

turns into

 sub foo :lvalue {
   ...
 }

It is recommended that you use C<attributes> in new code but C<attrs> is also
accepted for now.

=item C<default_arguments>

Valid values: booleans. This property is on by default, so you have to pass
C<< default_arguments => 0 >> to turn it off. If it is disabled, using C<=> in
a parameter list causes a syntax error. Otherwise it lets you specify
default arguments directly in the parameter list:

 fun foo($x, $y = 42, $z = []) {
   ...
 }

turns into

 sub foo {
   my ($x, $y, $z) = @_;
   $y = 42 if @_ < 2;
   $z = [] if @_ < 3;
   ...
 }

You can even refer to previous parameters in the same parameter list:

 print fun ($x, $y = $x + 1) { "$x and $y" }->(9);  # "9 and 10"

This also works with the implicit first parameter of methods:

 method scale($factor = $self->default_factor) {
   $self->{amount} *= $factor;
 }

=item C<check_argument_count>

Valid values: booleans. This property is off by default. If it is enabled, the
generated code will include checks to make sure the number of passed arguments
is correct (and otherwise throw an exception via L<Carp::croak|Carp>):

  fun foo($x, $y = 42, $z = []) {
    ...
  }

turns into

 sub foo {
   Carp::croak "Not enough arguments for fun foo" if @_ < 1;
   Carp::croak "Too many arguments for fun foo" if @_ > 3;
   my ($x, $y, $z) = @_;
   $y = 42 if @_ < 2;
   $z = [] if @_ < 3;
   ...
 }

=back

Plain C<'function'> is equivalent to:

 {
   name => 'optional',
   default_arguments => 1,
   check_argument_count => 0,
 }

(These are all default values so C<'function'> is also equivalent to C<{}>.)

C<'function_strict'> is like C<'function'> but with
C<< check_argument_count => 1 >>.

C<'method'> is equivalent to:

 {
   name => 'optional',
   default_arguments => 1,
   check_argument_count => 0,
   attributes => ':method',
   shift => '$self',
   invocant => 1,
 }

C<'method_strict'> is like C<'method'> but with
C<< check_argument_count => 1 >>.

C<'classmethod'> is equivalent to:

 {
   name => 'optional',
   default_arguments => 1,
   check_argument_count => 0,
   attributes => ':method',
   shift => '$class',
   invocant => 1,
 }

C<'classmethod_strict'> is like C<'classmethod'> but with
C<< check_argument_count => 1 >>.

=head2 Syntax and generated code

Normally, Perl subroutines are not in scope in their own body, meaning the
parser doesn't know the name C<foo> or its prototype while processing the body
of C<sub foo ($) { foo $bar[1], $bar[0]; }>, parsing it as
C<$bar-E<gt>foo([1], $bar[0])>. Yes. You can add parens to change the
interpretation of this code, but C<foo($bar[1], $bar[0])> will only trigger
a I<foo() called too early to check prototype> warning. This module attempts
to fix all of this by adding a subroutine declaration before the function body,
so the parser knows the name (and possibly prototype) while it processes the
body. Thus C<fun foo($x) :($) { $x }> really turns into
C<sub foo ($) { sub foo ($); my ($x) = @_; $x }>.

If you need L<subroutine attributes|perlsub/Subroutine-Attributes>, you can
put them after the parameter list with their usual syntax.

Syntactically, these new parameter lists live in the spot normally occupied
by L<prototypes|perlsub/"Prototypes">. However, you can include a prototype by
specifying it as the first attribute (this is syntactically unambiguous
because normal attributes have to start with a letter while a prototype starts
with C<(>).

As an example, the following declaration uses every available feature
(subroutine name, parameter list, default arguments, prototype, default
attributes, attributes, argument count checks, and implicit C<$self> overriden
by an explicit invocant declaration):

 method foo($this: $x, $y, $z = sqrt 5)
   :($$$;$)
   :lvalue
   :Banana(2 + 2)
 {
   ...
 }

And here's what it turns into:

 sub foo ($$$;$) :method :lvalue :Banana(2 + 2) {
   sub foo ($$$;$);
   Carp::croak "Not enough arguments for method foo" if @_ < 3;
   Carp::croak "Too many arguments for method foo" if @_ > 4;
   my $this = shift;
   my ($x, $y, $z) = @_;
   $z = sqrt 5 if @_ < 3;
   ...
 }

Another example:

 my $coderef = fun ($p, $q)
   :(;$$)
   :lvalue
   :Gazebo((>:O)) {
   ...
 };

And the generated code:

 my $coderef = sub (;$$) :lvalue :Gazebo((>:O)) {
   # vvv   only if check_argument_count is enabled    vvv
   Carp::croak "Not enough arguments for fun (anon)" if @_ < 2;
   Carp::croak "Too many arguments for fun (anon)" if @_ > 2;
   # ^^^                                              ^^^
   my ($p, $q) = @_;
   ...
 };

=head2 Wrapping Function::Parameters

If you want to wrap L<Function::Parameters>, you just have to call its
C<import> method. It always applies to the file that is currently being parsed
and its effects are L<lexical|perlpragma> (i.e. it works like L<warnings> or
L<strict>).

 package Some::Wrapper;
 use Function::Parameters ();
 sub import {
   Function::Parameters->import;
   # or Function::Parameters->import(@custom_import_args);
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
