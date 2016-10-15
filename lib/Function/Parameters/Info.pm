package Function::Parameters::Info;

use v5.14.0;
use warnings;

use Function::Parameters;
use Carp ();

our $VERSION = '1.0706';

{
    package Function::Parameters::Param;

    use overload
        fallback => 1,
        '""'     => method (@) { $self->{name} },
    ;

    method new($class: :$name, :$type) {
        bless { @_ }, $class
    }

    method name() { $self->{name} }
    method type() { $self->{type} }
}

method new($class:
    :$keyword,
    :$nshift,
    :$_positional_required,
    :$_positional_optional,
    :$_named_required,
    :$_named_optional,
    :$slurpy,
) {
    bless {@_}, $class
}

method keyword() { $self->{keyword} }
method nshift () { $self->{nshift}  }
method slurpy () { $self->{slurpy}  }
method positional_optional() { @{$self->{_positional_optional}} }
method named_required     () { @{$self->{_named_required}} }
method named_optional     () { @{$self->{_named_optional}} }

method positional_required() {
    my @p = @{$self->{_positional_required}};
    splice @p, 0, $self->nshift;
    @p
}

method args_min() {
    my $r = 0;
    $r += @{$self->{_positional_required}};
    $r += $self->named_required * 2;
    $r
}

method args_max() {
    return 0 + 'Inf' if defined $self->slurpy || $self->named_required || $self->named_optional;
    my $r = 0;
    $r += @{$self->{_positional_required}};
    $r += $self->positional_optional;
    $r
}

method invocant() {
    my $nshift = $self->nshift;
    return undef
        if $nshift == 0;
    return $self->{_positional_required}[0]
        if $nshift == 1;
    Carp::croak "Can't return a single invocant; this function has $nshift";
}

method invocants() {
    my @p = @{$self->{_positional_required}};
    splice @p, $self->nshift;
    @p
}

'ok'

__END__

=encoding UTF-8

=head1 NAME

Function::Parameters::Info - Information about parameter lists

=head1 SYNOPSIS

  use Function::Parameters;
  
  fun foo($x, $y, :$hello, :$world = undef) {}
  
  my $info = Function::Parameters::info \&foo;
  my $p0 = $info->invocant;             # undef
  my @p1 = $info->positional_required;  # ('$x', '$y')
  my @p2 = $info->positional_optional;  # ()
  my @p3 = $info->named_required;       # ('$hello')
  my @p4 = $info->named_optional;       # ('$world')
  my $p5 = $info->slurpy;               # undef
  my $min = $info->args_min;  # 4
  my $max = $info->args_max;  # inf
  
  my $invocant = Function::Parameters::info(method () { 42 })->invocant;  # '$self'
  
  my $slurpy = Function::Parameters::info(fun {})->slurpy;  # '@_'

=head1 DESCRIPTION

L<C<Function::Parameters::info>|Function::Parameters/Introspection> returns
objects of this class to describe parameter lists of functions. The following
methods are available:

=head2 $info->invocant

Returns the name of the variable into which the first argument is
L<C<shift>|perlfunc/shift ARRAY>ed automatically, or C<undef> if no such thing
exists. This will usually return C<'$self'> for methods.

=head2 $info->positional_required

Returns a list of the names of the required positional parameters (or a count
in scalar context).

=head2 $info->positional_optional

Returns a list of the names of the optional positional parameters (or a count
in scalar context).

=head2 $info->named_required

Returns a list of the names of the required named parameters (or a count
in scalar context).

=head2 $info->named_optional

Returns a list of the names of the optional named parameters (or a count
in scalar context).

=head2 $info->slurpy

Returns the name of the final array or hash that gobbles up all remaining
arguments, or C<undef> if no such thing exists.

As a special case, functions defined without an explicit parameter list (i.e.
without C<( )>) will return C<'@_'> here because they accept any number of
arguments.

=head2 $info->args_min

Returns the minimum number of arguments this function requires. This is
computed as follows: Invocant and required positional parameters count 1 each.
Optional parameters don't count. Required named parameters count 2 each (key +
value). Slurpy parameters don't count either because they accept empty lists.

=head2 $info->args_max

Returns the maximum number of arguments this function accepts. This is computed
as follows: If there is any named or slurpy parameter, the result is C<Inf>.
Otherwise the result is the sum of all invocant and positional parameters.

=head2 Experimental feature: Types

All the methods described above actually return parameter objects wherever the
description says "name". These objects have two methods: C<name>, which
returns the name of the parameter (as a plain string), and C<type>, which
returns the corresponding type constraint object (or undef if there was no type
specified).

This should be invisible if you don't use types because the objects also
L<overload|overload> stringification to call C<name>. That is, if you treat
parameter objects like strings, they behave like strings (i.e. their names).

=head1 SEE ALSO

L<Function::Parameters>

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2013 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
