#!perl
use warnings FATAL => 'all';
use strict;

use Test::More tests => 8;
use Test::Fatal;

use Function::Parameters qw(:strict);
use Function::Parameters {
	def => { check_argument_count => 1 },
};

{
	package MyTC;

	method new(
		$class:
		$name,
		$check,
		$get_message = fun ($value) {
			"Validation failed for constraint '$name' with value '$value'"
		},
	) {
		bless {
			name => $name,
			check => $check,
			get_message => $get_message,
		}, $class
	}

	method check($value) {
		$self->{check}($value)
	}

	method get_message($value) {
		$self->{get_message}($value)
	}
}

use constant {
	TEvenNum  => MyTC->new('even number'  => fun ($n) { $n =~ /^[0-9]+\z/ && $n % 2 == 0 }),
	TShortStr => MyTC->new('short string' => fun ($s) { length($s) < 10 }),
};

fun foo((TEvenNum) $x, (TShortStr) $y) {
	"$x/$y"
}

is foo(42, "hello"), "42/hello";
like exception { foo 41, "hello" },       qr{\bValidation failed for constraint 'even number' with value '41'};
like exception { foo 42, "1234567890~" }, qr{\bValidation failed for constraint 'short string' with value '1234567890~'};
like exception { foo 41, "1234567890~" }, qr{\bValidation failed for constraint 'even number' with value '41'};

def foo2((TEvenNum) $x, (TShortStr) $y) {
	"$x/$y"
}

is foo2(42, "hello"), "42/hello";
like exception { foo2 41, "hello" },       qr{\bValidation failed for constraint 'even number' with value '41'};
like exception { foo2 42, "1234567890~" }, qr{\bValidation failed for constraint 'short string' with value '1234567890~'};
like exception { foo2 41, "1234567890~" }, qr{\bValidation failed for constraint 'even number' with value '41'};
