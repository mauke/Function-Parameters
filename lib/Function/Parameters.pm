package Function::Parameters;

use v5.14.0;

use warnings;

use Carp qw(confess);

use XSLoader;
BEGIN {
	our $VERSION = '1.00';
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


our %metadata;

sub _register_info {
	my (
		$key,
		$declarator,
		$invocant,
		$positional_required,
		$positional_optional,
		$named_required,
		$named_optional,
		$slurpy,
	) = @_;

	my $blob = pack '(Z*)*',
		$declarator,
		$invocant // '',
		join(' ', @$positional_required),
		join(' ', @$positional_optional),
		join(' ', @$named_required),
		join(' ', @$named_optional),
		$slurpy // '',
	;

	$metadata{$key} = $blob;
}

sub info {
	my ($func) = @_;
	my $key = _cv_root $func or return undef;
	my $blob = $metadata{$key} or return undef;
	my @info = unpack '(Z*)*', $blob;
	require Function::Parameters::Info;
	Function::Parameters::Info->new(
		keyword => $info[0],
		invocant => $info[1] || undef,
		_positional_required => [split ' ', $info[2]],
		_positional_optional => [split ' ', $info[3]],
		_named_required => [split ' ', $info[4]],
		_named_optional => [split ' ', $info[5]],
		slurpy => $info[6] || undef,
	)
}

'ok'

__END__

=encoding UTF-8

=head1 NAME

Function::Parameters - subroutine definitions with parameter lists

=head1 SYNOPSIS

 use Function::Parameters qw(:strict);
 
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
 
 # function with optional parameters
 fun search($haystack, $needle = qr/^(?!)/, $offset = 0) {
   ...
 }
 
 # method with named parameters
 method resize(:$width, :$height) {
   $self->{width}  = $width;
   $self->{height} = $height;
 }
 
 $obj->resize(height => 4, width => 5);
 
 # function with named optional parameters
 fun search($haystack, :$needle = qr/^(?!)/, :$offset = 0) {
   ...
 }
 
 my $results = search $text, offset => 200;

=head1 DESCRIPTION

This module extends Perl with keywords that let you define functions with
parameter lists. It uses Perl's L<keyword plugin|perlapi/PL_keyword_plugin>
API, so it works reliably and doesn't require a source filter.

=head2 Basics

The anatomy of a function (as recognized by this module):

=over

=item 1.

The keyword introducing the function.

=item 2.

The function name (optional).

=item 3.

The parameter list (optional).

=item 4.

The prototype (optional).

=item 5.

The attribute list (optional).

=item 6.

The function body.

=back

Example:

  # (1)   (2) (3)      (4)   (5)     (6)
    fun   foo ($x, $y) :($$) :lvalue { ... }
 
  #         (1) (6)
    my $f = fun { ... };

In the following section I'm going to describe all parts in order from simplest to most complex.

=head3 Body

This is just a normal block of statements, as with L<C<sub>|perlsub>. No surprises here.

=head3 Name

If present, it specifies the name of the function being defined. As with
L<C<sub>|perlsub>, if a name is present, the whole declaration is syntactically
a statement and its effects are performed at compile time (i.e. at runtime you
can call functions whose definitions only occur later in the file). If no name
is present, the declaration is an expression that evaluates to a reference to
the function in question. No surprises here either.

=head3 Attributes

Attributes are relatively unusual in Perl code, but if you want them, they work
exactly the same as with L<C<sub>|perlsub/Subroutine-Attributes>.

=head3 Prototype

As with L<C<sub>|perlsub/Prototypes>, a prototype, if present, contains hints as to how
the compiler should parse calls to this function. This means prototypes have no
effect if the function call is compiled before the function declaration has
been seen by the compiler or if the function to call is only determined at
runtime (e.g. because it's called as a method or through a reference).

With L<C<sub>|perlsub>, a prototype comes directly after the function name (if
any). C<Function::Parameters> reserves this spot for the
L<parameter list|/"Parameter list">. To specify a prototype, put it as the
first attribute (e.g. C<fun foo :(&$$)>). This is syntactically unambiguous
because normal L<attributes|/Attributes> need a name after the colon.

=head3 Parameter list

The parameter list is a list of variables enclosed in parentheses, except it's
actually a bit more complicated than that. A parameter list can include the
following 6 parts, all of which are optional:

=over

=item 1. Invocant

This is a scalar variable followed by a colon (C<:>) and no comma. If an
invocant is present in the parameter list, the first element of
L<C<@_>|perlvar/@ARG> is automatically L<C<shift>ed|perlfunc/shift> off and
placed in this variable. This is intended for methods:

  method new($class: %init) {
    return bless { %init }, $class;
  }

  method throw($self:) {
    die $self;
  }

=item 2. Required positional parameters

The most common kind of parameter. This is simply a comma-separated list of
scalars, which are filled from left to right with the arguments that the caller
passed in:

  fun add($x, $y) {
    return $x + $y;
  }
  
  say add(2, 3);  # "5"

=item 3. Optional positional parameters

Parameters can be marked as optional by putting an equals sign (C<=>) and an
expression (the "default argument") after them. If no corresponding argument is
passed in by the caller, the default argument will be used to initialize the
parameter:

  fun scale($base, $factor = 2) {
    return $base * $factor;
  }
 
  say scale(3, 5);  # "15"
  say scale(3);     # "6"

The default argument is I<not> cached. Every time a function is called with
some optional arguments missing, the corresponding default arguments are
evaluated from left to right. This makes no difference for a value like C<2>
but it is important for expressions with side effects, such as reference
constructors (C<[]>, C<{}>) or function calls.

Default arguments see not only the surrounding lexical scope of their function
but also any preceding parameters. This allows the creation of dynamic defaults
based on previous arguments:

  method set_name($self: $nick = $self->default_nick, $real_name = $nick) {
    $self->{nick} = $nick;
    $self->{real_name} = $real_name;
  }
 
  $obj->set_name("simplicio");  # same as: $obj->set_name("simplicio", "simplicio");

Because default arguments are actually evaluated as part of the function body,
you can also do silly things like this:

  fun foo($n = return "nope") {
    "you gave me $n"
  }
 
  say foo(2 + 2);  # "you gave me 4"
  say foo();       # "nope"

=item 4. Required named parameters

By putting a colon (C<:>) in front of a parameter you can make it named
instead of positional:

  fun rectangle(:$width, :$height) {
    ...
  }
 
  rectangle(width => 2, height => 5);
  rectangle(height => 5, width => 2);  # same thing!

That is, the caller must specify a key name in addition to the value, but in
exchange the order of the arguments doesn't matter anymore. As with hash
initialization, you can specify the same key multiple times and the last
occurrence wins:

  rectangle(height => 1, width => 2, height => 2, height => 5;
  # same as: rectangle(width => 2, height => 5);

You can combine positional and named parameters as long as the positional
parameters come first:

  fun named_rectangle($name, :$width, :$height) {
    ...
  }
 
  named_rectangle("Avocado", width => 0.5, height => 1.2);

=item 5. Optional named parameters

As with positional parameters, you can make named parameters optional by
specifying a default argument after an equals sign (C<=>):

  fun rectangle(:$width, :$height, :$color = "chartreuse") {
    ...
  }
 
  rectangle(height => 10, width => 5);
  # same as: rectangle(height => 10, width => 5, color => "chartreuse");

=cut

=pod
  
  fun get($url, :$cookie_jar = HTTP::Cookies->new(), :$referrer = $url) {
    ...
  }

  my $data = get "http://www.example.com/", referrer => undef;  # overrides $referrer = $url

The above example shows that passing any value (even C<undef>) will override
the default argument.

=item 6. Slurpy parameter

Finally you can put an array or hash in the parameter list, which will gobble
up the remaining arguments (if any):

  fun foo($x, $y, @rest) { ... }
 
  foo "a", "b";            # $x = "a", $y = "b", @rest = ()
  foo "a", "b", "c";       # $x = "a", $y = "b", @rest = ("c")
  foo "a", "b", "c", "d";  # $x = "a", $y = "b", @rest = ("c", "d")

If you combine this with named parameters, the slurpy parameter will end up
containing all unrecognized keys:

  fun bar(:$size, @whatev) { ... }
 
  bar weight => 20, size => 2, location => [0, -3];
  # $size = 2, @whatev = ('weight', 20, 'location', [0, -3])

=back

Apart from the L<C<shift>|perlfunc/shift> performed by the L<invocant|/"1.
Invocant">, all of the above leave L<C<@_>|perlvar/@ARG> unchanged; and if you
don't specify a parameter list at all, L<C<@_>|perlvar/@ARG> is all you get.

=head3 Keyword

The keywords provided by C<Function::Parameters> are customizable. Since
C<Function::Parameters> is actually a L<pragma|perlpragma>, the provided
keywords have lexical scope. The following import variants can be used:

=over

=item C<use Function::Parameters ':strict'>

Provides the keywords C<fun> and C<method> (described below) and enables
argument checks so that calling a function and omitting a required argument (or
passing too many arguments) will throw an error.

=item C<use Function::Parameters>

Provides the keywords C<fun> and C<method> (described below) and enables
"lax" mode: Omitting a required argument sets it to C<undef> while excess
arguments are silently ignored.

=item C<< use Function::Parameters { KEYWORD1 => TYPE1, KEYWORD2 => TYPE2, ... } >>

Provides completely custom keywords as described by their types. A "type" is
either a string (one of the predefined types C<function>, C<method>,
C<classmethod>, C<function_strict>, C<method_strict>, C<classmethod_strict>) or
a reference to a hash with the following keys:

=over

=item C<name>

Valid values: C<optional> (default), C<required> (all functions defined with
this keyword must have a name), and C<prohibited> (functions defined with this
keyword must be anonymous).

=item C<shift>

Valid values: strings that look like scalar variables. This lets you specify a
default L<invocant|/"1. Invocant">, i.e. a function defined with this keyword
that doesn't have an explicit invocant in its parameter list will automatically
L<C<shift>|perlfunc/shift> its first argument into the variable specified here.

=item C<invocant>

Valid values: booleans. If you set this to a true value, the keyword will
accept L<invocants|/"1. Invocant"> in parameter lists; otherwise specifying
an invocant in a function defined with this keyword is a syntax error.

=item C<attributes>

Valid values: strings containing (source code for) attributes. This causes any
function defined with this keyword to have the specified
L<attributes|attributes> (in addition to any attributes specified in the
function definition itself).

=item C<default_arguments>

Valid values: booleans. This property is on by default; use
C<< default_arguments => 0 >> to turn it off. This controls whether optional
parameters are allowed. If it is turned off, using C<=> in parameter lists is
a syntax error.

=item C<check_argument_count>

Valid values: booleans. If turned on, functions defined with this keyword will
automatically check that they have been passed all required arguments and no
excess arguments. If this check fails, an exception will by thrown via
L<C<Carp::croak>|Carp>.

=back

The predefined type C<function> is equivalent to:

 {
   name => 'optional',
   invocant => 0,
   default_arguments => 1,
   check_argument_count => 0,
 }

These are all default values, so C<function> is also equivalent to C<{}>.

C<method> is equivalent to:

 {
   name => 'optional',
   shift => '$self',
   invocant => 1,
   attributes => ':method',
   default_arguments => 1,
   check_argument_count => 0,
 }


C<classmethod> is equivalent to:

 {
   name => 'optional',
   shift => '$class',
   invocant => 1,
   attributes => ':method',
   default_arguments => 1,
   check_argument_count => 0,
 }

C<function_strict>, C<method_strict>, and
C<classmethod_strict> are like C<function>, C<method>, and
C<classmethod>, respectively, but with C<< check_argument_count => 1 >>.

=back

Plain C<use Function::Parameters> is equivalent to
C<< use Function::Parameters { fun => 'function', method => 'method' } >>.

C<use Function::Parameters qw(:strict)> is equivalent to
C<< use Function::Parameters { fun => 'function_strict', method => 'method_strict' } >>.

=head2 Introspection

You can ask a function at runtime what parameters it has. This functionality is
available through the function C<Function::Parameters::info> (which is not
exported, so you have to call it by its full name). It takes a reference to a
function, and returns either C<undef> (if it knows nothing about the function)
or a L<Function::Parameters::Info> object describing the parameter list.

Note: This feature is implemented using L<Moo>, so you'll need to have L<Moo>
installed if you want to call C<Function::Parameters::info>.

See L<Function::Parameters::Info> for examples.

=head2 Wrapping C<Function::Parameters>

If you want to write a wrapper around C<Function::Parameters>, you only have to
call its C<import> method. Due to its L<pragma|perlpragma> nature it always
affects the file that is currently being compiled.

 package Some::Wrapper;
 use Function::Parameters ();
 sub import {
   Function::Parameters->import;
   # or Function::Parameters->import(@custom_import_args);
 }

=head2 How it works

The module is actually written in L<C|perlxs> and uses
L<C<PL_keyword_plugin>|perlapi/PL_keyword_plugin> to generate opcodes directly.
However, you can run L<C<perl -MO=Deparse ...>|B::Deparse> on your code to see
what happens under the hood. In the simplest case (no argument checks, possibly
an L<invocant|/"1. Invocant">, required positional/slurpy parameters only), the
generated code corresponds to:

  fun foo($x, $y, @z) { ... }
  # ... turns into ...
  sub foo { my ($x, $y, @z) = @_; sub foo; ... }

  method bar($x, $y, @z) { ... }
  # ... turns into ...
  sub bar :method { my $self = shift; my ($x, $y, @z) = @_; sub bar; ... }

=head1 SEE ALSO

L<Function::Parameters::Info>

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010, 2011, 2012 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
