#!perl

use strict;
use warnings FATAL => 'all';

use Test::More
    eval { require Moose }
    ? ()
    : (skip_all => "Moose required for testing types")
;
use Test::More;
use Test::Fatal;

use Function::Parameters qw(:moose);


{ package Foo::Bar; sub new { bless {}, __PACKAGE__; } }
{ package Foo::Baz; sub new { bless {}, __PACKAGE__; } }

our $foobar = Foo::Bar->new;
our $foobaz = Foo::Baz->new;


# types to check below
# the test name needs to be interpolated into a method name, so it must be a valid identifier
# either good value or bad value can be an array reference:
#   *   if it is, it is taken to be multiple values to try
#   *   if you want to pass an array reference, you have to put it inside another array reference
#   *   so, [ 42, undef ] makes two calls: one with 42, and one with undef
#   *   but [[ 42, undef ]] makes one call, passing [ 42, undef ]
our @TYPES =
(
##  Test Name       =>  Type                =>  Good Value                      =>  Bad Value
    int             =>  'Int'               =>  42                              =>  'foo'                               ,
    bool            =>  'Bool'              =>  0                               =>  'fool'                              ,
    aref            =>  'ArrayRef',         =>  [[ 42, undef ]]                 =>  42                                  ,
    class           =>  'Foo::Bar'          =>  $foobar                         =>  $foobaz                             ,
    maybe_int       =>  'Maybe[Int]'        =>  [ 42, undef ]                   =>  'foo'                               ,
    paramized_aref  =>  'ArrayRef[Num]'     =>  [[ 6.5, 42, 1e23 ]]             =>  [[ 6.5, 42, 'thing' ]]              ,
    paramized_href  =>  'HashRef[Num]'      =>  { a => 6.5, b => 2, c => 1e23 } =>  { a => 6.5, b => 42, c => 'thing' } ,
    paramized_nested=>  'HashRef[ArrayRef[Int]]'
                                            =>  { foo=>[1..3], bar=>[1] }       =>  { foo=>['a'] }                               ,
##  ScalarRef[X] not implemented in Mouse, so this test is moved to typeload_moose.t
##  if Mouse starts supporting it, the test could be restored here
    paramized_sref  =>  'ScalarRef[Num]'    =>  \42                             =>  \'thing'                            ,
    int_or_aref     =>  'Int|ArrayRef[Int]' =>  [ 42 , [42 ] ]                  =>  'foo'                               ,
    int_or_aref_or_undef
                    =>  'Int|ArrayRef[Int]|Undef'
                                            =>  [ 42 , [42 ], undef ]           =>  'foo'                               ,
);


our $tester;
{
    package TypeCheck::Class;

    use strict;
    use warnings;

    use Test::More;
    use Test::Fatal;

    use Function::Parameters qw(:moose);

    method new ($class:) { bless {}, $class; }

    sub _list { return ref $_[0] eq 'ARRAY' ? @{$_[0]} : ( $_[0] ); }


    $tester = __PACKAGE__->new;
    while (@TYPES)
    {
        my ($name, $type, $goodval, $badval) = splice @TYPES, 0, 4;
        note "name/type/goodval/badval $name/$type/$goodval/$badval";
        my $method = "check_$name";
        no strict 'refs';

        # make sure the declaration of the method doesn't throw a warning
        is eval qq{ method $method ($type \$bar) {} 42 }, 42;
        is $@, '';

        # positive test--can we call it with a good value?
        my @vals = _list($goodval);
        my $count = 1;
        foreach (@vals)
        {
            my $tag = @vals ? ' (alternative ' . $count++ . ')' : '';
            is exception { $tester->$method($_) }, undef, "call with good value for $name passes" . $tag;
        }

        # negative test--does calling it with a bad value throw an exception?
        @vals = _list($badval);
        $count = 1;
        foreach (@vals)
        {
            my $tag = @vals ? ' (#' . $count++ . ')' : '';
            like exception { $tester->$method($_) }, qr/method \Q$method\E.+parameter 1\b.+\$bar\b.+Validation failed for '[^']+' with value\b/,
                    "call with bad value for $name dies";
        }
    }


    # try some mixed (i.e. some with a type, some without) and multiples

    my $method = 'check_mixed_type_first';
    is eval qq{ method $method (Int \$bar, \$baz) {} 42 }, 42;
    is exception { $tester->$method(0, 'thing') }, undef, 'call with good values (type, notype) passes';
    like exception { $tester->$method('thing1', 'thing2') }, qr/method \Q$method\E.+parameter 1\b.+\$bar\b.+Validation failed for '[^']+' with value\b/,
            'call with bad values (type, notype) dies';

    $method = 'check_mixed_type_second';
    is eval qq{ method $method (\$bar, Int \$baz) {} 42 }, 42;
    is exception { $tester->$method('thing', 1) }, undef, 'call with good values (notype, type) passes';
    like exception { $tester->$method('thing1', 'thing2') }, qr/method \Q$method\E.+parameter 2\b.+\$baz\b.+Validation failed for '[^']+' with value\b/,
            'call with bad values (notype, type) dies';

    $method = 'check_multiple_types';
    is eval qq{ method $method (Int \$bar, Int \$baz) {} 42 }, 42;
    is exception { $tester->$method(1, 1) }, undef, 'call with good values (type, type) passes';
    # with two types, and bad values for both, they should fail in order of declaration
    like exception { $tester->$method('thing1', 'thing2') }, qr/method \Q$method\E.+parameter 1\b.+\$bar\b.+Validation failed for '[^']+' with value\b/,
            'call with bad values (type, type) dies';

    # want to try one with undef as well to make sure we don't get an uninitialized warning

    like exception { $tester->check_int(undef) }, qr/method check_int.+parameter 1\b.+\$bar\b.+Validation failed for '[^']+' with value\b/,
            'call with bad values (undef) dies';



    # finally, some types that shouldn't be recognized
    my $type;

    ## Moose accepts unknown types as classes
    #$method = 'unknown_type';
    #$type = 'Bmoogle';
    #is eval qq{ method $method ($type \$bar) {} 42 }, 42;
    #like exception { $tester->$method(42) }, qr/ducks $tester, $type, "perhaps you forgot to load it?", $method/,
    #        'call with unrecognized type dies';

    # this one is a bit specialer in that it involved an unrecognized parameterization
    $method = 'unknown_paramized_type';
    $type = 'Bmoogle[Int]';
    is eval qq{ method $method ($type \$bar) {} 42 }, undef;
    like $@, qr/\QCould not locate the base type (Bmoogle)/;
    like exception { $tester->$method(42) }, qr/\QCan't locate object method "unknown_paramized_type" via package "TypeCheck::Class"/;

}


done_testing;
