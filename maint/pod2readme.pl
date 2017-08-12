use strict;
use warnings;

BEGIN {
    package Pod2ReadmeText;
    use Pod::Text ();
    our @ISA = 'Pod::Text';

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        $self->accept_targets('README');
        $self->{+__PACKAGE__} = {
            passthrough => 0,
        };
        $self
    }

    sub cmd_head1 {
        my $self = shift;
        my ($attrs, $text) = @_;
        $self->{+__PACKAGE__}{passthrough} = $text =~ /^\s*(?:NAME|INSTALLATION|LICENSE|COPYRIGHT|SUPPORT)\b/;
        $self->SUPER::cmd_head1(@_)
    }

    sub output {
        my $self = shift;
        $self->{+__PACKAGE__}{passthrough} or return;
        $self->SUPER::output(@_)
    }
}

my $parser = Pod2ReadmeText->new(
    sentence => 0,
    errors   => 'die',
    loose    => 1,
);

$parser->parse_from_file;
