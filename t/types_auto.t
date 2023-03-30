#!perl
use warnings qw(all FATAL uninitialized);
use strict;

use Test::More tests => 12;

{
    package MyTC;

    use overload
        '~'   => 'complement',
        '|'   => 'union',
        '&'   => 'intersection',
        '/'   => 'alternative',
        '&{}' => 'apply';

    sub new {
        my ($class, $name) = @_;
        bless { _name => $name }, $class
    }

    sub name { $_[0]{_name} }

    sub check { 1 }

    sub get_message { die "Internal error: get_message: ${\$_[0]->name}"; }

    sub complement {
        my ($x) = @_;
        ref($x)->new('~' . $x->name)
    }

    sub union {
        my ($x, $y) = @_;
        ref($x)->new('(' . $x->name . '|' . $y->name . ')')
    }

    sub intersection {
        my ($x, $y) = @_;
        ref($x)->new('(' . $x->name . '&' . $y->name . ')')
    }

    sub alternative {
        my ($x, $y) = @_;
        ref($x)->new('(' . $x->name . '/' . $y->name . ')')
    }

    sub apply {
        my $self = shift;
        sub {
            return $self if !@_;
            @_ == 1 or die "Internal error: apply->(@_)";
            my @args = @{$_[0]};
            ref($self)->new($self->name . '[' . join(',', map $_->name, @args) . ']')
        }
    }
}

use Function::Parameters;

BEGIN {
    for my $suffix ('a' .. 't') {
        my $name = "T$suffix";
        my $obj = MyTC->new($name);
        my $symbol = do { no strict 'refs'; \*$name };
        *$symbol = sub { $obj->(@_) };
    }
}

is eval 'fun (NoSuchType $x) {}', undef;
like $@, qr/\AUndefined type name main::NoSuchType /;

is eval 'fun (("NoSuchType") $x) {}', undef;
like $@, qr/\AUndefined type name main::NoSuchType /;

for my $f (
    fun (   Ta[Tb] | ~Td | Tf [ (Tg), ~~ ~ Ti | (Ta | Tb & Tc & Td), Tj | Tk[Tl], To [ Tq, Tr ] | Tt ] & Ta / Tb | Tc / Td & Te $x) {},
    fun ((' Ta[Tb] | ~Td | Tf [ (Tg), ~~ ~ Ti | (Ta | Tb & Tc & Td), Tj | Tk[Tl], To [ Tq, Tr ] | Tt ] & Ta / Tb | Tc / Td & Te ') $x) {},
) {
    my $m = Function::Parameters::info $f;
    is my ($xi) = $m->positional_required, 1;
    is $xi->name, '$x';
    my $t = $xi->type;
    is ref $t, 'MyTC';
    is $t->name, '(((Ta[Tb]|~Td)|(Tf[Tg,(~~~Ti|(Ta|((Tb&Tc)&Td))),(Tj|Tk[Tl]),(To[Tq,Tr]|Tt)]&(Ta/Tb)))|((Tc/Td)&Te))';
}
