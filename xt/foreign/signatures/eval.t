#!perl
use strict;
use warnings FATAL => 'all';
use Test::More tests => 8;

use Function::Parameters;

eval 'fun foo ($bar) { $bar }';
ok(!$@, 'signatures parse in eval');
diag $@ if $@;
ok(\&foo, 'fun declared in eval');
is(foo(42), 42, 'eval signature works');

no Function::Parameters;

$SIG{__WARN__} = sub {};
eval 'fun bar ($baz) { $baz }';
like($@, qr/requires explicit package name/, 'string eval disabled');

{
    use Function::Parameters;

    eval 'fun bar ($baz) { $baz }';
    ok(!$@, 'signatures parse in eval');
    diag $@ if $@;
    ok(\&bar, 'fun declared in eval');
    is(bar(42), 42, 'eval signature works');
}

$SIG{__WARN__} = sub {};
eval 'fun moo ($kooh) { $kooh }';
like($@, qr/requires explicit package name/, 'string eval disabled');
