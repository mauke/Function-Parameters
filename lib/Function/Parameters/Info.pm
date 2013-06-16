package Function::Parameters::Info;

use v5.14.0;
use warnings;

our $VERSION = '0.03';

# If Moo isn't loaded yet but Moose is, avoid pulling in Moo and fall back to Moose
my $Moo;
BEGIN {
	if ($INC{'Moose.pm'} && !$INC{'Moo.pm'}) {
		$Moo = 'Moose';
	} else {
		require Moo;
		$Moo = 'Moo';
	}
	$Moo->import;
}

{
	package Function::Parameters::Param;

	BEGIN { $Moo->import; }
	use overload
		fallback => 1,
		'""'     => sub { $_[0]->name },
	;

	has $_ => (is => 'ro') for qw(name type);

	__PACKAGE__->meta->make_immutable;
}

my @pn_ro = glob '{positional,named}_{required,optional}';

for my $attr (qw[keyword invocant slurpy], map "_$_", @pn_ro) {
	has $attr => (
		is => 'ro',
	);
}

for my $gen (join "\n", map "sub $_ { \@{\$_[0]->_$_} }", @pn_ro) {
	eval "$gen\n1" or die $@;
}

sub args_min {
	my $self = shift;
	my $r = 0;
	$r++ if defined $self->invocant;
	$r += $self->positional_required;
	$r += $self->named_required * 2;
	$r
}

sub args_max {
	my $self = shift;
	return 0 + 'Inf' if defined $self->slurpy || $self->named_required || $self->named_optional;
	my $r = 0;
	$r++ if defined $self->invocant;
	$r += $self->positional_required;
	$r += $self->positional_optional;
	$r
}

__PACKAGE__->meta->make_immutable;

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
L<C<shift>|perlfunc/shift>ed automatically, or C<undef> if no such thing
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
