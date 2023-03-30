#!perl
use warnings qw(all FATAL uninitialized);
use strict;
use Test::More tests => 15;
use Test::Fatal;
use Function::Parameters;

{
    package MyTC_noco;

    method new($class: $good) {
        bless { good => $good }, $class
    }

    method coerce($value) {
        die "bad";
    }

    method check($value) {
        $value eq $self->{good}
    }

    method get_message($value) {
        "'$value' ain't '$self->{good}'"
    }
}

{
    package MyTC;
    BEGIN { our @ISA = MyTC_noco::; }

    method has_coercion() {
        $self->{has_coercion}
    }

    method enable_coercion($flag = 1) {
        $self->{has_coercion} = $flag;
    }

    method new($class: $good, $coerce = 0) {
        my $self = $class->SUPER::new($good);
        $self->enable_coercion($coerce);
        $self
    }

    method coerce($value) {
        $value =~ s/\?+\z//;
        $value
    }
}

use constant {
    Type_A => MyTC_noco->new('Type_A:good'),
    Type_B => MyTC->new('Type_B:good'),
    Type_C => MyTC->new('Type_C:good', 1),
};

fun constrained_0(Type_A $x, Type_B $y, Type_C $z) { [$x, $y, $z] }
fun constrained_1((Type_A) $x, (Type_B) $y, (Type_C) $z) { [$x, $y, $z] }
fun constrained_2(('Type_A') $x, ('Type_B') $y, ('Type_C') $z) { [$x, $y, $z] }

is_deeply constrained_0('Type_A:good', 'Type_B:good', 'Type_C:good'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];
is_deeply constrained_1('Type_A:good', 'Type_B:good', 'Type_C:good'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];
is_deeply constrained_2('Type_A:good', 'Type_B:good', 'Type_C:good'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];

like exception { constrained_0 'Type_A:good???', '-', '-' }, qr/\Q'Type_A:good???' ain't 'Type_A:good'/;
like exception { constrained_1 'Type_A:good???', '-', '-' }, qr/\Q'Type_A:good???' ain't 'Type_A:good'/;
like exception { constrained_2 'Type_A:good???', '-', '-' }, qr/\Q'Type_A:good???' ain't 'Type_A:good'/;

like exception { constrained_0 'Type_A:good', 'Type_B:good???', '-', }, qr/\Q'Type_B:good???' ain't 'Type_B:good'/;
like exception { constrained_1 'Type_A:good', 'Type_B:good???', '-', }, qr/\Q'Type_B:good???' ain't 'Type_B:good'/;
like exception { constrained_2 'Type_A:good', 'Type_B:good???', '-', }, qr/\Q'Type_B:good???' ain't 'Type_B:good'/;

like exception { constrained_0 'Type_A:good', 'Type_B:good', 'Type_C:bad??', }, qr/\Q'Type_C:bad' ain't 'Type_C:good'/;
like exception { constrained_1 'Type_A:good', 'Type_B:good', 'Type_C:bad??', }, qr/\Q'Type_C:bad' ain't 'Type_C:good'/;
like exception { constrained_2 'Type_A:good', 'Type_B:good', 'Type_C:bad??', }, qr/\Q'Type_C:bad' ain't 'Type_C:good'/;

is_deeply constrained_0('Type_A:good', 'Type_B:good', 'Type_C:good???'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];
is_deeply constrained_1('Type_A:good', 'Type_B:good', 'Type_C:good???'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];
is_deeply constrained_2('Type_A:good', 'Type_B:good', 'Type_C:good???'), ['Type_A:good', 'Type_B:good', 'Type_C:good'];
