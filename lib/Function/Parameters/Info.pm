package Function::Parameters::Info;

use v5.14.0;

use warnings;

use Moo;

our $VERSION = '0.01';

my @pn_ro = glob '{positional,named}_{required,optional}';

for my $attr (qw[keyword invocant slurpy], map "_$_", @pn_ro) {
	has $attr => (
		is => 'ro',
	);
}

for my $gen (join "\n", map "sub $_ { \@{\$_[0]->_$_} }", @pn_ro) {
	eval "$gen\n1" or die $@;
}

'ok'

__END__
