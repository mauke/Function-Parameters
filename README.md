# NAME

Function::Parameters - define functions and methods with parameter lists ("subroutine signatures")

# SYNOPSIS

```perl
use Function::Parameters;

# plain function
fun foo($x, $y, $z = 5) {
    return $x + $y + $z;
}
print foo(1, 2), "\n";  # 8

# method with implicit $self
method bar($label, $n) {
    return "$label: " . ($n * $self->scale);
}

# named arguments: order doesn't matter in the call
fun create_point(:$x, :$y, :$color) {
    print "creating a $color point at ($x, $y)\n";
}
create_point(
    color => "red",
    x     => 10,
    y     => 5,
);

package Derived {
    use Function::Parameters qw(:std :modifiers);
    use Moo;

    extends 'Base';

    has 'go_big' => (
        is => 'ro',
    );

    # "around" method with implicit $orig and $self
    around size() {
        return $self->$orig() * 2 if $self->go_big;
        return $self->$orig();
    }
}
```

# DESCRIPTION

This module provides two new keywords, `fun` and `method`, for defining
functions and methods with parameter lists. At minimum this saves you from
having to unpack `@_` manually, but this module can do much more for you.

The parameter lists provided by this module are similar to the `signatures`
feature available in perl v5.20+. However, this module supports all perl
versions starting from v5.14, it offers far more features than core signatures,
and it is not experimental. The downside is that you need a C compiler if you
want to install it from source, as it uses Perl's
[keyword plugin](https://metacpan.org/pod/perlapi#PL_keyword_plugin) API in order to work reliably
without requiring a source filter.

## Default functionality

This module is a lexically scoped pragma: If you `use Function::Parameters`
inside a block or file, the keywords won't be available outside of that block
or file.

You can also disable `Function::Parameters` within a block:

```perl
{
    no Function::Parameters;  # disable all keywords
    ...
}
```

Or explicitly list the keywords you want to disable:

```perl
{
    no Function::Parameters qw(method);
    # 'method' is a normal identifier here
    ...
}
```

You can also explicitly list the keywords you want to enable:

```perl
use Function::Parameters qw(fun);  # provides 'fun' but not 'method'
use Function::Parameters qw(method);  # provides 'method' but not 'fun'
```

### Simple parameter lists

By default you get two keywords, `fun` and `method` (but see
["Customizing and extending"](#customizing-and-extending) below). `fun` is very similar to `sub`. You can
use it to define both named and anonymous functions:

```perl
fun left_pad($str, $n) {
    return sprintf '%*s', $n, $str;
}

print left_pad("hello", 10), "\n";

my $twice = fun ($x) { $x * 2 };
print $twice->(21), "\n";
```

In the simplest case the parameter list is just a comma-separated list of zero
or more scalar variables (enclosed in parentheses, following the function name,
if any).

`Function::Parameters` automatically validates the arguments your function is
called with. If the number of arguments doesn't match the parameter list, an
exception is thrown.

Apart from that, the parameter variables are defined and initialized as if by:

```perl
sub left_pad {
    sub left_pad;
    my ($str, $n) = @_;
    ...
}
```

In particular, `@_` is still available in functions defined by `fun` and
holds the original argument list.

The inner `sub left_pad;` declaration is intended to illustrate that the name
of the function being defined is in scope in its own body, meaning you can call
it recursively without having to use parentheses:

```perl
fun fac($n) {
    return 1 if $n < 2;
    return $n * fac $n - 1;
}
```

In a normal `sub` the last line would have had to be written
`return $n * fac($n - 1);`.

`method` is almost the same as `fun` but automatically creates a `$self`
variable as the first parameter (which is removed from `@_`):

```perl
method foo($x, $y) {
   ...
}

# works like:
sub foo :method {
   my $self = shift;
   my ($x, $y) = @_;
   ...
}
```

As you can see, the `:method` attribute is also added automatically (see
["method" in attributes](https://metacpan.org/pod/attributes#method) for details).

In some cases (e.g. class methods) `$self` is not the best name for the
invocant of the method. You can override it on a case-by-case basis by putting
a variable name followed by a `:` (colon) as the first thing in the parameter
list:

```perl
method new($class: $x, $y) {
    return bless { x => $x, y => $y }, $class;
}
```

Here the invocant is named `$class`, not `$self`. It looks a bit weird but
still works the same way if the remaining parameter list is empty:

```perl
method from_env($class:) {
    return $class->new($ENV{x}, $ENV{y});
}
```

### Default arguments

(Most of the following examples use `fun` only. Unless specified otherwise
everything applies to `method` as well.)

You can make some arguments optional by giving them default values.

```perl
fun passthrough($x, $y = 42, $z = []) {
    return ($x, $y, $z);
}
```

In this example the first parameter `$x` is required but `$y` and `$z` are
optional.

```perl
passthrough('a', 'b', 'c', 'd')   # error: Too many arguments
passthrough('a', 'b', 'c')        # returns ('a', 'b', 'c')
passthrough('a', 'b')             # returns ('a', 'b', [])
passthrough('a', undef)           # returns ('a', undef, [])
passthrough('a')                  # returns ('a', 42, [])
passthrough()                     # error: Too few arguments
```

Default arguments are evaluated whenever a corresponding real argument is not
passed in by the caller. `undef` counts as a real argument; you can't use the
default value for parameter _N_ and still pass a value for parameter _N+1_.
`$z = []` means each call that doesn't pass a third argument gets a new array
reference (they're not shared between calls).

Default arguments are evaluated as part of the function body, allowing for
silliness such as:

```perl
fun weird($name = return "nope") {
    print "Hello, $name!\n";
    return $name;
}

weird("Larry");  # prints "Hello, Larry!" and returns "Larry"
weird();         # returns "nope" immediately; function body doesn't run
```

Preceding parameters are in scope for default arguments:

```perl
fun dynamic_default($x, $y = length $x) {
   return "$x/$y";
}

dynamic_default("hello", 0)  # returns "hello/0"
dynamic_default("hello")     # returns "hello/5"
dynamic_default("abc")       # returns "abc/3"
```

If you just want to make a parameter optional without giving it a special
value, write `$param = undef`. There is a special shortcut syntax for
this case: `$param = undef` can also be written `$param =` (with no following
expression).

```perl
fun foo($x = undef, $y = undef, $z = undef) {
    # three arguments, all optional
    ...
}

fun foo($x=, $y=, $z=) {
    # shorter syntax, same meaning
    ...
}
```

Optional parameters must come at the end. It is not possible to have a required
parameter after an optional one.

### Slurpy/rest parameters

The last parameter of a function or method can be an array. This lets you slurp
up any number of arguments the caller passes (0 or more).

```perl
fun scale($factor, @values) {
    return map { $_ * $factor } @values;
}

scale(10, 1 .. 4)  # returns (10, 20, 30, 40)
scale(10)          # returns ()
```

You can also use a hash, but then the number of arguments has to be even.

### Named parameters

As soon as your functions take more than three arguments, it gets harder to
keep track of what argument means what:

```perl
foo($handle, $w, $h * 2 + 15, 1, 24, 'icon');
# what do these arguments mean?
```

`Function::Parameters` offers an alternative for these kinds of situations in
the form of named parameters. Unlike the parameters described previously, which
are identified by position, these parameters are identified by name:

```perl
fun create_point(:$x, :$y, :$color) {
    ...
}

# Case 1
create_point(
    x     => 50,
    y     => 50,
    color => 0xff_00_00,
);
```

To create a named parameter, put a `:` (colon) in front of it in the parameter
list. When the function is called, the arguments have to be supplied in the
form of a hash initializer (a list of alternating keys/values). As with a hash,
the order of key/value pairs doesn't matter (except in the case of duplicate
keys, where the last occurrence wins):

```perl
# Case 2
create_point(
    color => 0xff_00_00,
    x     => 50,
    y     => 50,
);

# Case 3
create_point(
    x     => 200,
    color => 0x12_34_56,
    color => 0xff_00_00,
    x     => 50,
    y     => 50,
);
```

Case 1, Case 2, and Case 3 all mean the same thing.

As with positional parameters, you can make named parameters optional by
supplying a [default argument](#default-arguments):

```perl
fun create_point(:$x, :$y, :$color = 0x00_00_00) {
    ...
}

create_point(x => 0, y => 64)  # color => 0x00_00_00 is implicit
```

If you want to accept any key/value pairs, you can add a
[rest parameter](#slurpyrest-parameters) (hashes are particularly useful):

```perl
fun accept_all_keys(:$name, :$age, %rest) {
    ...
}

accept_all_keys(
    age     => 42,
    gender  => 2,
    name    => "Jamie",
    marbles => [],
);
# $name = "Jamie";
# $age = 42;
# %rest = (
#     gender  => 2,
#     marbles => [],
# );
```

You can combine positional and named parameters but all positional parameters
have to come first:

```perl
method output(
   $data,
   :$handle       = $self->output_handle,
   :$separator    = $self->separator,
   :$quote_fields = 0,
) {
    ...
}

$obj->output(["greetings", "from", "space"]);
$obj->output(
   ["a", "random", "example"],
   quote_fields => 1,
   separator    => ";",
);
```

### Unnamed parameters

If your function doesn't use a particular parameter at all, you can omit its
name and just write a sigil in the parameter list:

```perl
register_callback('click', fun ($target, $) {
    ...
});
```

Here we're calling a hypothetical `register_callback` function that registers
our coderef to be called in response to a `click` event. It will pass two
arguments to the click handler, but the coderef only cares about the first one
(`$target`). The second parameter doesn't even get a name (just a sigil,
`$`). This marks it as unused.

This case typically occurs when your functions have to conform to an externally
imposed interface, e.g. because they're called by someone else. It can happen
with callbacks or methods that don't need all of the arguments they get.

You can use unnamed [slurpy parameters](#slurpyrest-parameters) to accept and
ignore all following arguments. In particular, `fun foo(@)` is a lot like
`sub foo` in that it accepts and ignores any number of arguments (apart from
leaving them in `@_`).

### Type constraints

It is possible to automatically check the types of arguments passed to your
function. There are two ways to do this.

1. <!-- -->

    ```perl
    use Types::Standard qw(Str Int ArrayRef);

    fun foo(Str $label, ArrayRef[Int] $counts) {
        ...
    }
    ```

    In this variant you simply put the name of a type in front of a parameter. The
    way this works is that `Function::Parameters` parses the type using very
    simple rules:

    - A _type_ is a sequence of one or more simple types, separated by `|` (pipe).
    `|` is meant for union types (e.g. `Str | ArrayRef[Int]` would accept either
    a string or reference to an array of integers).
    - A _simple type_ is an identifier, optionally followed by a list of one or more
    types, separated by `,` (comma), enclosed in `[` `]` (square brackets).

    `Function::Parameters` then resolves simple types by looking for functions of
    the same name in your current package. A type specification like
    `Str | ArrayRef[Int]` ends up running the Perl code
    `Str() | ArrayRef([Int()])` (at compile time, while the function definition is
    being processed). In other words, `Function::Parameters` doesn't support any
    types natively; it simply uses whatever is in scope.

    You don't have to define these functions yourself. You can also import them
    from a type library such as [`Types::Standard`](https://metacpan.org/pod/Types::Standard) or
    [`MooseX::Types::Moose`](https://metacpan.org/pod/MooseX::Types::Moose).

    The only requirement is that the returned value (here referred to as `$tc`,
    for "type constraint") is an object that provides `$tc->check($value)`
    and `$tc->get_message($value)` methods. `check` is called to determine
    whether a particular value is valid; it should return a true or false value.
    `get_message` is called on values that fail the `check` test; it should
    return a string that describes the error.

2. <!-- -->

    ```perl
    my ($my_type, $some_other_type);
    BEGIN {
        $my_type = Some::Constraint::Class->new;
        $some_other_type = Some::Other::Class->new;
    }

    fun foo(($my_type) $label, ($some_other_type) $counts) {
        ...
    }
    ```

    In this variant you enclose an arbitrary Perl expression in `(` `)`
    (parentheses) and put it in front of a parameter. This expression is evaluated
    at compile time and must return a type constraint object as described above.
    (If you use variables here, make sure they're defined at compile time.)

### Method modifiers

`Function::Parameters` has support for method modifiers as provided by
[`Moo`](https://metacpan.org/pod/Moo) or [`Moose`](https://metacpan.org/pod/Moose). They're not exported by default, so you
have to say

```perl
use Function::Parameters qw(:modifiers);
```

to get them. This line gives you method modifiers _only_; `fun` and `method`
are not defined. To get both the standard keywords and method modifiers, you
can either write two `use` lines:

```perl
use Function::Parameters;
use Function::Parameters qw(:modifiers);
```

or explicitly list the keywords you want:

```perl
use Function::Parameters qw(fun method :modifiers);
```

or add the `:std` import tag (which gives you the default import behavior):

```perl
use Function::Parameters qw(:std :modifiers);
```

This defines the following additional keywords: `before`, `after`, `around`,
`augment`, `override`. These work mostly like `method`, but they don't
install the function into your package themselves. Instead they invoke whatever
`before`, `after`, `around`, `augment`, or `override` function
(respectively) is in scope to do the job.

```perl
before foo($x, $y, $z) {
    ...
}
```

works like

```perl
&before('foo', method ($x, $y, $z) {
    ...
});
```

`after`, `augment`, and `override` work the same way.

`around` is slightly different: Instead of shifting off the first element of
`@_` into `$self` (as `method` does), it shifts off _two_ values:

```perl
around foo($x, $y, $z) {
    ...
}
```

works like

```perl
&around('foo', sub :method {
    my $orig = shift;
    my $self = shift;
    my ($x, $y, $z) = @_;
    ...
});
```

(except you also get the usual `Function::Parameters` features such as
checking the number of arguments, etc).

`$orig` and `$self` both count as invocants and you can override their names
like this:

```perl
around foo($original, $object: $x, $y, $z) {
    # $original is a reference to the wrapped method;
    # $object is the object we're being called on
    ...
}
```

If you use `:` to pick your own invocant names in the parameter list of
`around`, you must specify exactly two variables.

These modifiers also differ from `fun` and `method` (and `sub`) in that they
require a function name (there are no anonymous method modifiers) and they
take effect at runtime, not compile time. When you say `fun foo() {}`, the
`foo` function is defined right after the closing `}` of the function body is
parsed. But with e.g. `before foo() {}`, the declaration becomes a normal
function call (to the `before` function in the current package), which is
performed at runtime.

### Prototypes and attributes

You can specify attributes (see ["Subroutine Attributes" in perlsub](https://metacpan.org/pod/perlsub#Subroutine-Attributes)) for your
functions using the usual syntax:

```perl
fun deref($x) :lvalue {
   ${$x}
}

my $silly;
deref(\$silly) = 42;
```

To specify a prototype (see ["Prototypes" in perlsub](https://metacpan.org/pod/perlsub#Prototypes)), use the `prototype`
attribute:

```perl
fun mypush($aref, @values) :prototype(\@@) {
    push @{$aref}, @values;
}
```

### Introspection

The function `Function::Parameters::info` lets you introspect parameter lists
at runtime. It is not exported, so you have to call it by its full name.

It takes a reference to a function and returns either `undef` (if it knows
nothing about the function) or an object that describes the parameter list of
the given function. See
[`Function::Parameters::Info`](https://metacpan.org/pod/Function::Parameters::Info) for details.

## Customizing and extending

### Wrapping `Function::Parameters`

Due to its nature as a lexical pragma, importing from `Function::Parameters`
always affects the scope that is currently being compiled. If you want to write
a wrapper module that enables `Function::Parameters` automatically, just call
`Function::Parameters->import` from your own `import` method (and
`Function::Parameters->unimport` from your `unimport`, as required).

### Gory details of importing

At the lowest layer `use Function::Parameters ...` takes a list of one or more
hash references. Each key is a keyword to be defined as specified by the
corresponding value, which must be another hash reference containing
configuration options.

```perl
use Function::Parameters
    {
        keyword_1 => { ... },
        keyword_2 => { ... },
    },
    {
        keyword_3 => { ... },
    };
```

If you don't specify a particular option, its default value is used. The
available configuration options are:

- `attributes`

    (string) The attributes that every function declared with this
    keyword should have (in the form of source code, with a leading `:`).

    Default: nothing

- `check_argument_count`

    (boolean) Whether functions declared with this keyword should check how many
    arguments they are called with. If false, omitting a required argument sets it
    to `undef` and excess arguments are silently ignored. If true, an exception is
    thrown if too few or too many arguments are passed.

    Default: `1`

- `check_argument_types`

    (boolean) Whether functions declared with this keyword should check the types
    of the arguments they are called with. If false,
    [type constraints](#type-constraints) are parsed but silently ignored. If true,
    an exception is thrown if an argument fails a type check.

    Default: `1`

- `default_arguments`

    (boolean) Whether functions declared with this keyword should allow default
    arguments in their parameter list. If false,
    [default arguments](#default-arguments) are a compile-time error.

    Default: `1`

- `install_sub`

    (sub name or reference) If this is set, named functions declared with this
    keyword are not entered into the symbol table directly. Instead the subroutine
    specified here (by name or reference) is called with two arguments, the name of
    the function being declared and a reference to its body.

    Default: nothing

- `invocant`

    (boolean) Whether functions declared with this keyword should allow explicitly
    specifying invocant(s) at the beginning of the parameter list (as in
    `($invocant: ...)` or `($invocant1, $invocant2, $invocant3: ...)`).

    Default: 0

- `name`

    (string) There are three possible values for this option. `'required'` means
    functions declared with this keyword must have a name. `'prohibited'` means
    specifying a name is not allowed. `'optional'` means this keyword can be used
    for both named and anonymous functions.

    Default: `'optional'`

- `named_parameters`

    (boolean) Whether functions declared with this keyword should allow named
    parameters. If false, [named parameters](#named-parameters) are a compile-time
    error.

    Default: `1`

- `reify_type`

    (coderef or `'auto'` or `'moose'`) The code reference used to resolve
    [type constraints](#type-constraints) in functions declared with this keyword.
    It is called once for each type constraint that doesn't use the `( EXPR )`
    syntax, with one argument, the text of the type in the parameter list (e.g.
    `'ArrayRef[Int]'`). The package the function declaration is in is available
    through [`caller`](https://metacpan.org/pod/perlfunc#caller-EXPR).

    The only requirement is that the returned value (here referred to as `$tc`,
    for "type constraint") is an object that provides `$tc->check($value)`
    and `$tc->get_message($value)` methods. `check` is called to determine
    whether a particular value is valid; it should return a true or false value.
    `get_message` is called on values that fail the `check` test; it should
    return a string that describes the error.

    Instead of a code reference you can also specify one of two strings.

    `'auto'` stands for a built-in type reifier that treats identifiers as
    subroutine names, `[` `]` as an array reference, and `|` as bitwise or. In
    other words, it parses and executes type constraints (mostly) as if they had
    been Perl source code.

    `'moose'` stands for a built-in type reifier that loads
    [`Moose::Util::TypeConstraints`](https://metacpan.org/pod/Moose::Util::TypeConstraints) and just
    forwards to
    [`find_or_create_isa_type_constraint`](https://metacpan.org/pod/Moose::Util::TypeConstraints#find_or_create_isa_type_constraint-type_name).

    Default: `'auto'`

- `runtime`

    (boolean) Whether functions declared with this keyword should be installed into
    the symbol table at runtime. If false, named functions are defined (or their
    [`install_sub`](#install_sub) is invoked if specified) immediately after
    their declaration is parsed (as with [`sub`](https://metacpan.org/pod/perlfunc#sub-NAME-BLOCK)). If
    true, function declarations become normal statements that only take effect at
    runtime (similar to `*foo = sub { ... };` or
    `$install_sub->('foo', sub { ... });`, respectively).

    Default: `0`

- `shift`

    (string or arrayref) In its simplest form, this is the name of a variable that
    acts as the default invocant (a required leading argument that is removed from
    `@_`) for all functions declared with this keyword (e.g.  `'$self'` for
    methods). You can also set this to an array reference of strings, which lets
    you specify multiple default invocants, or even to an array reference of array
    references of the form `[ $name, $type ]` (where `$name` is the variable name
    and `$type` is a [type constraint object](#type-constraints)), which lets you
    specify multiple default invocants with type constraints.

    If you define any default invocants here and also allow individual declarations
    to override the default (with `invocant => 1`), the number of overridden
    invocants must match the default. For example, `method` has a default invocant
    of `$self`, so `method foo($x, $y: $z)` is invalid because it tries to define
    two invocants.

    Default: `[]` (meaning no invocants)

- `strict`

    (boolean) Whether functions declared with this keyword should do "strict"
    checks on their arguments. Currently setting this simply sets
    [`check_argument_count`](#check_argument_count) to the same value with no
    other effects.

    Default: nothing

- `types`

    (boolean) Whether functions declared with this keyword should allow type
    constraints in their parameter lists. If false, trying to use
    [type constraints](#type-constraints) is a compile-time error.

    Default: `1`

You can get the same effect as `use Function::Parameters;` by saying:

```perl
use Function::Parameters {
    fun => {
        # 'fun' uses default settings only
    },
    method => {
        attributes => ':method',
        shift      => '$self',
        invocant   => 1,
        # the rest is defaults
    },
};
```

### Configuration bundles

Because specifying all these configuration options from scratch each time is a
lot of writing, `Function::Parameters` offers configuration bundles in the
form of special strings. These strings can be used to replace a configuration
hash completely or as the value of the `defaults` pseudo-option within a
configuration hash. The latter lets you use the configuration bundle behind the
string to provide defaults and tweak them with your own settings.

The following bundles are available:

- `function_strict`

    Equivalent to `{}`, i.e. all defaults.

- `function_lax`

    Equivalent to:

    ```perl
    {
        defaults => 'function_strict',
        strict   => 0,
    }
    ```

    i.e. just like [`function_strict`](#function_strict) but with
    [`strict`](#strict) checks turned off.

- `function`

    Equivalent to `function_strict`. This is what the default `fun` keyword
    actually uses. (In version 1 of this module, `function` was equivalent to
    `function_lax`.)

- `method_strict`

    Equivalent to:

    ```perl
    {
        defaults   => 'function_strict',
        attributes => ':method',
        shift      => '$self',
        invocant   => 1,
    }
    ```

- `method_lax`

    Equivalent to:

    ```perl
    {
        defaults => 'method_strict',
        strict   => 0,
    }
    ```

    i.e. just like [`method_strict`](#method_strict) but with
    [`strict`](#strict) checks turned off.

- `method`

    Equivalent to `method_strict`. This is what the default `method` keyword
    actually uses. (In version 1 of this module, `method` was equivalent to
    `method_lax`.)

- `classmethod_strict`

    Equivalent to:

    ```perl
    {
        defaults => 'method_strict',
        shift    => '$class',
    }
    ```

    i.e. just like [`method_strict`](#method_strict) but the implicit first
    parameter is called `$class`, not `$self`.

- `classmethod_lax`

    Equivalent to:

    ```perl
    {
        defaults => 'classmethod_strict',
        strict   => 0,
    }
    ```

    i.e. just like [`classmethod_strict`](#classmethod_strict) but with
    [`strict`](#strict) checks turned off.

- `classmethod`

    Equivalent to `classmethod_strict`. This is currently not used anywhere within
    `Function::Parameters`.

- `around`

    Equivalent to:

    ```perl
    {
        defaults    => 'method',
        install_sub => 'around',
        shift       => ['$orig', '$self'],
        runtime     => 1,
        name        => 'required',
    }
    ```

    i.e. just like [`method`](#method) but with a custom installer
    (`'around'`), two implicit first parameters, only taking effect at
    runtime, and a method name is required.

- `before`

    Equivalent to:

    ```perl
    {
        defaults    => 'method',
        install_sub => 'before',
        runtime     => 1,
        name        => 'required',
    }
    ```

    i.e. just like [`method`](#method) but with a custom installer
    (`'before'`), only taking effect at runtime, and a method name is required.

- `after`

    Equivalent to:

    ```perl
    {
        defaults    => 'method',
        install_sub => 'after',
        runtime     => 1,
        name        => 'required',
    }
    ```

    i.e. just like [`method`](#method) but with a custom installer
    (`'after'`), only taking effect at runtime, and a method name is required.

- `augment`

    Equivalent to:

    ```perl
    {
        defaults    => 'method',
        install_sub => 'augment',
        runtime     => 1,
        name        => 'required',
    }
    ```

    i.e. just like [`method`](#method) but with a custom installer
    (`'augment'`), only taking effect at runtime, and a method name is required.

- `override`

    Equivalent to:

    ```perl
    {
        defaults    => 'method',
        install_sub => 'override',
        runtime     => 1,
        name        => 'required',
    }
    ```

    i.e. just like [`method`](#method) but with a custom installer
    (`'override'`), only taking effect at runtime, and a method name is required.

You can get the same effect as `use Function::Parameters;` by saying:

```perl
use Function::Parameters {
    fun    => { defaults => 'function' },
    method => { defaults => 'method' },
};
```

or:

```perl
use Function::Parameters {
    fun    => 'function',
    method => 'method',
};
```

### Import tags

In addition to hash references you can also use special strings in your import
list. The following import tags are available:

- `'fun'`

    Equivalent to `{ fun => 'function' }`.

- `'method'`

    Equivalent to `{ method => 'method' }`.

- `'classmethod'`

    Equivalent to `{ classmethod => 'classmethod' }`.

- `'before'`

    Equivalent to `{ before => 'before' }`.

- `'after'`

    Equivalent to `{ after => 'after' }`.

- `'around'`

    Equivalent to `{ around => 'around' }`.

- `'augment'`

    Equivalent to `{ augment => 'augment' }`.

- `'override'`

    Equivalent to `{ override => 'override' }`.

- `':strict'`

    Equivalent to `{ fun => 'function_strict', method => 'method_strict' }`
    but that's just the default behavior anyway.

- `':lax'`

    Equivalent to `{ fun => 'function_lax', method => 'method_lax' }`, i.e. it
    provides `fun` and `method` keywords that define functions that don't check
    their arguments.

- `':std'`

    Equivalent to `'fun', 'method'`. This is what's used by default:

    ```perl
    use Function::Parameters;
    ```

    is the same as:

    ```perl
    use Function::Parameters qw(:std);
    ```

- `':modifiers'`

    Equivalent to `'before', 'after', 'around', 'augment', 'override'`.

For example, when you say

```perl
use Function::Parameters qw(:modifiers);
```

`:modifiers` is an import tag that [expands to](#modifiers)

```perl
use Function::Parameters qw(before after around augment override);
```

Each of those is another import tag. Stepping through the first one:

```perl
use Function::Parameters qw(before);
```

is [equivalent to](#before):

```perl
use Function::Parameters { before => 'before' };
```

This says to define the keyword `before` according to the
[configuration bundle `before`](#before):

```perl
use Function::Parameters {
    before => {
        defaults    => 'method',
        install_sub => 'before',
        runtime     => 1,
        name        => 'required',
    },
};
```

The `defaults => 'method'` part [pulls in](#configuration-bundles) the
contents of the [`'method'` configuration bundle](#method) (which is the
same as [`'method_strict'`](#method_strict)):

```perl
use Function::Parameters {
    before => {
        defaults    => 'function_strict',
        attributes  => ':method',
        shift       => '$self',
        invocant    => 1,
        install_sub => 'before',
        runtime     => 1,
        name        => 'required',
    },
};
```

This in turn uses the
[`'function_strict'` configuration bundle](#function_strict) (which is
empty because it consists of default values only):

```perl
use Function::Parameters {
    before => {
        attributes  => ':method',
        shift       => '$self',
        invocant    => 1,
        install_sub => 'before',
        runtime     => 1,
        name        => 'required',
    },
};
```

But if we wanted to be completely explicit, we could write this as:

```perl
use Function::Parameters {
    before => {
        check_argument_count => 1,
        check_argument_types => 1,
        default_arguments    => 1,
        named_parameters     => 1,
        reify_type           => 'auto',
        types                => 1,

        attributes  => ':method',
        shift       => '$self',
        invocant    => 1,
        install_sub => 'before',
        runtime     => 1,
        name        => 'required',
    },
};
```

## Incompatibilites with version 1 of `Function::Parameters`

- Version 1 defaults to lax mode (no argument checks). To get the same behavior
on both version 1 and version 2, explicitly write either
`use Function::Parameters qw(:strict);` (the new default) or
`use Function::Parameters qw(:lax);` (the old default). (Or write
`use Function::Parameters 2;` to trigger an error if an older version of
`Function::Parameters` is loaded.)
- Parameter lists used to be optional. The syntax `fun foo { ... }` would accept
any number of arguments. This syntax has been removed; you now have to write
`fun foo(@) { ... }` to accept (and ignore) all arguments. On the other hand,
if you meant for the function to take no arguments, write `fun foo() { ... }`.
- There used to be a shorthand syntax for prototypes: Using `:(...)` (i.e. an
attribute with an empty name) as the first attribute was equivalent to
`:prototype(...)`. This syntax has been removed.
- The default type reifier used to be hardcoded to use [`Moose`](https://metacpan.org/pod/Moose) (as in
`reify_type => 'moose'`). This has been changed to use whatever type
functions are in scope (`reify_type => 'auto'`).
- Type reifiers used to see the wrong package in
[`caller`](https://metacpan.org/pod/perlfunc#caller-EXPR). As a workaround the correct calling package
used to be passed as a second argument. This problem has been fixed and the
second argument has been removed. (Technically this is a core perl bug
([RT #129239](https://rt.perl.org/Public/Bug/Display.html?id=129239)) that
wasn't so much fixed as worked around in `Function::Parameters`.)

    If you want your type reifier to be compatible with both versions, you can do
    this:

    ```perl
    sub my_reifier {
        my ($type, $package) = @_;
        $package //= caller;
        ...
    }
    ```

    Or using `Function::Parameters` itself:

    ```perl
    fun my_reifier($type, $package = caller) {
        ...
    }
    ```

# SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

```sh
perldoc Function::Parameters
```

You can also look for information at
[https://metacpan.org/pod/Function%3A%3AParameters](https://metacpan.org/pod/Function%3A%3AParameters).

To see a list of open bugs, visit
[https://rt.cpan.org/Public/Dist/Display.html?Name=Function-Parameters](https://rt.cpan.org/Public/Dist/Display.html?Name=Function-Parameters).

To report a new bug, send an email to
`bug-Function-Parameters [at] rt.cpan.org`.

# SEE ALSO

[Function::Parameters::Info](https://metacpan.org/pod/Function::Parameters::Info),
[Moose](https://metacpan.org/pod/Moose),
[Moo](https://metacpan.org/pod/Moo),
[Type::Tiny](https://metacpan.org/pod/Type::Tiny)

# AUTHOR

Lukas Mai, `<l.mai at web.de>`

# COPYRIGHT & LICENSE

Copyright 2010-2014, 2017 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
