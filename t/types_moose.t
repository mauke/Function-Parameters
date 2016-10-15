#!perl
use warnings FATAL => 'all';
use strict;

use Test::More
    eval { require Moose }
    ? (tests => 49)
    : (skip_all => "Moose required for testing types")
;
use Test::Fatal;

use Function::Parameters {
    fun    => { defaults => 'function', reify_type => 'moose' },
    method => { defaults => 'method',   reify_type => 'moose' },
};

fun foo(Int $n, CodeRef $f, $x) {
    $x = $f->($x) for 1 .. $n;
    $x
}

is foo(0, fun (@) {}, undef), undef;
is foo(0, fun (@) {}, "o hai"), "o hai";
is foo(3, fun ($x) { "($x)" }, 1.5), "(((1.5)))";
is foo(3, fun (Str $x) { "($x)" }, 1.5), "(((1.5)))";

{
    my $info = Function::Parameters::info \&foo;
    is $info->invocant, undef;
    is $info->slurpy, undef;
    is $info->positional_optional, 0;
    is $info->named_required, 0;
    is $info->named_optional, 0;
    my @req = $info->positional_required;
    is @req, 3;
    is $req[0]->name, '$n';
    ok $req[0]->type->equals('Int');
    is $req[1]->name, '$f';
    ok $req[1]->type->equals('CodeRef');
    is $req[2]->name, '$x';
    is $req[2]->type, undef;
}

like exception { foo("ermagerd", fun (@) {}, undef) }, qr/\bparameter 1.+\$n\b.+\bValidation failed\b.+\bInt\b.+ermagerd/;
like exception { foo(0, {}, undef) }, qr/\bparameter 2.+\$f\b.+\bValidation failed\b.+\bCodeRef\b/;

fun bar(((Function::Parameters::info(\&foo)->positional_required)[0]->type) $whoa) { $whoa * 2 }

is bar(21), 42;
{
    my $info = Function::Parameters::info \&bar;
    is $info->invocant, undef;
    is $info->slurpy, undef;
    is $info->positional_optional, 0;
    is $info->named_required, 0;
    is $info->named_optional, 0;
    my @req = $info->positional_required;
    is @req, 1;
    is $req[0]->name, '$whoa';
    ok $req[0]->type->equals('Int');
}

{
    my $info = Function::Parameters::info(fun ( ArrayRef [ Int | CodeRef ]@nom) {});
    is $info->invocant, undef;
    is $info->positional_required, 0;
    is $info->positional_optional, 0;
    is $info->named_required, 0;
    is $info->named_optional, 0;
    my $slurpy = $info->slurpy;
    is $slurpy->name, '@nom';
    ok $slurpy->type->equals(Moose::Util::TypeConstraints::find_or_parse_type_constraint('ArrayRef[Int|CodeRef]'));
}

{
    my $phase = 'runtime';
    BEGIN { $phase = 'A'; }
    fun
     baz
      (
       (
        is
         (
          $phase
           ++
            ,
             'A'
         )
          ,
           'Int'
       )
        :
         $marco
          ,
           (
            is
             (
              $phase
               ++
                ,
                 'B'
             )
              ,
               q
                $ArrayRef[Str]$
           )
            :
             $polo
         )
          {
           [
            $marco
             ,
              $polo
          ]
      }
    BEGIN { is $phase, 'C'; }
    is $phase, 'runtime';

    is_deeply baz(polo => [qw(foo bar baz)], marco => 11), [11, [qw(foo bar baz)]];

    my $info = Function::Parameters::info \&baz;
    is $info->invocant, undef;
    is $info->slurpy, undef;
    is $info->positional_required, 0;
    is $info->positional_optional, 0;
    is $info->named_optional, 0;
    my @req = $info->named_required;
    is @req, 2;
    is $req[0]->name, '$marco';
    ok $req[0]->type->equals('Int');
    is $req[1]->name, '$polo';
    ok $req[1]->type->equals('ArrayRef[Str]');
}
