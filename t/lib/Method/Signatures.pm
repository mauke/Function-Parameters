package Method::Signatures;

use strict;
use warnings;
use Carp;

our $VERSION = '20150222';

use Function::Parameters ();

=head1 NAME

Method::Signatures - A compatibility wrapper around Function::Parameters

=head1 Differences

=head2 Lexical vs Package

Method::Signatures works per package, but Function::Parameters is lexical.

=head2 Unsupported Features

=head3 into

C<< use Method::Signatures { into => 'Some::Other::Class' } >> is not
supported.

The most common use of C<into> is when writing a wrapper around
Method::Signatures.  This can be done like so.

    sub import {
        require Method::Signatures;
        Method::Signatures->import;
    }

See L<Function::Parameters/Wrapping "Function::Parameters"> for details.

=cut

sub import {
    my $class = shift;
    my $ms_opts  = shift;

    croak "into is not supported, see the documentation for alternatives"
      if $ms_opts->{into};
    
    my %fp_opts = (
        runtime => 0,
        reify_type => sub { Method::Signatures->_make_constraint($_[0]) },
        ms_compat_question_mark => 1,
        ms_compat_named_optional => 1,
    );

    # Adapt compile_at_BEGIN
    $fp_opts{runtime} = $ms_opts->{compile_at_BEGIN} ? 0 : 1
      if exists $ms_opts->{compile_at_BEGIN};

    Function::Parameters->import({
        func    => {
            defaults => 'function_strict',
            %fp_opts,
        },
        method  => {
            defaults => 'method_strict',
            %fp_opts,
        },
    });

    return;
}


# STUFF FOR TYPE CHECKING

# This variable will hold all the bits we need.  MUTC could stand for Moose::Util::TypeConstraint,
# or it could stand for Mouse::Util::TypeConstraint ... depends on which one you've got loaded (or
# Mouse if you have neither loaded).  Because we use Any::Moose to allow the user to choose
# whichever they like, we'll need to figure out the exact method names to call.  We'll also need a
# type constraint cache, where we stick our constraints once we find or create them.  This insures
# that we only have to run down any given constraint once, the first time it's seen, and then after
# that it's simple enough to pluck back out.  This is very similar to how MooseX::Params::Validate
# does it.
our %mutc;

# This is a helper function to initialize our %mutc variable.
sub _init_mutc
{
    require Any::Moose;
    Any::Moose->import('::Util::TypeConstraints');

    no strict 'refs';
    my $class = any_moose('::Util::TypeConstraints');
    $mutc{class} = $class;

    $mutc{findit}     = \&{ $class . '::find_or_parse_type_constraint' };
    $mutc{pull}       = \&{ $class . '::find_type_constraint'          };
    $mutc{make_class} = \&{ $class . '::class_type'                    };
    $mutc{make_role}  = \&{ $class . '::role_type'                     };

    $mutc{isa_class}  = $mutc{pull}->("ClassName");
    $mutc{isa_role}   = $mutc{pull}->("RoleName");
}

# This is a helper function to find (or create) the constraint we need for a given type.  It would
# be called when the type is not found in our cache.
sub _make_constraint
{
    my ($class, $type) = @_;

    _init_mutc() unless $mutc{class};

    # Look for basic types (Int, Str, Bool, etc).  This will also create a new constraint for any
    # parameterized types (e.g. ArrayRef[Int]) or any disjunctions (e.g. Int|ScalarRef[Int]).
    my $constr = eval { $mutc{findit}->($type) };
    if ($@)
    {
        $class->signature_error("the type $type is unrecognized (looks like it doesn't parse correctly)");
    }
    return $constr if $constr;

    # Check for roles.  Note that you *must* check for roles before you check for classes, because a
    # role ISA class.
    return $mutc{make_role}->($type) if $mutc{isa_role}->check($type);

    # Now check for classes.
    return $mutc{make_class}->($type) if $mutc{isa_class}->check($type);

    $class->signature_error("the type $type is unrecognized (perhaps you forgot to load it?)");
}

# This method does the actual type checking.  It's what we inject into our user's method, to be
# called directly by them.
#
# Note that you can override this instead of inject_for_type_check if you'd rather.  If you do,
# remember that this is a class method, not an object method.  That's because it's called at
# runtime, when there is no Method::Signatures object still around.
sub type_check
{
    my ($class, $type, $value, $name) = @_;

    # find it if isn't cached
    $mutc{cache}->{$type} ||= $class->_make_constraint($type);

    # throw an error if the type check fails
    unless ($mutc{cache}->{$type}->check($value))
    {
        $class->type_error($type, $value, $name);
    }

    # $mutc{cache} = {};
}

# If you just want to change what the type failure errors look like, just override this.
# Note that you can call signature_error yourself to handle the croak-like aspects.
sub type_error
{
    my ($class, $type, $value, $name) = @_;
    $value = defined $value ? qq{"$value"} : 'undef';
    $class->signature_error(qq{the '$name' parameter ($value) is not of type $type});
}


1;
