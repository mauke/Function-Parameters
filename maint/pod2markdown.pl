use strict;
use warnings;

BEGIN {
    package Pod2GithubMarkdown;
    use Pod::Markdown ();
    our @ISA = 'Pod::Markdown';

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(
            markdown_fragment_format => sub {
                my ($self, $str) = @_;
                $str =~ tr/A-Za-z0-9_\- //cd;
                $str =~ tr/A-Z /a-z-/;
                $str
            },
            @_
        );
        $self->accept_targets('highlighter');
        $self->{+__PACKAGE__} = {
            hl_language => '',
        };
        $self
    }

    sub start_for {
        my $self = shift;
        my ($attr) = @_;
        if ($attr->{target} eq 'highlighter') {
            $self->_new_stack;
            $self->_stack_state->{for_highlighter} = 1;
            return;
        }
        $self->SUPER::start_for(@_)
    }

    sub end_for {
        my $self = shift;
        my ($attr) = @_;
        if ($self->_stack_state->{for_highlighter}) {
            my $text = $self->_pop_stack_text;
            my %settings =
                map /\A([^=]*)=(.*)\z/s
                    ? ($1 => $2)
                    : (language => $_),
                split ' ', $text;
            $self->{+__PACKAGE__}{hl_language} = $settings{language} // '';
            return;
        }
        $self->SUPER::end_for(@_)
    }

    sub _indent_verbatim {
        my $self = shift;
        my ($paragraph) = @_;
        my $min_indent = 'inf';
        while ($paragraph =~ /^( +)/mg) {
            my $n = length $1;
            $min_indent = $n if $n < $min_indent;
        }
        my $rep =
            $min_indent < 'inf'
                ? "{$min_indent}"
                : '+';
        $paragraph =~ s/^ $rep//mg;
        my $fence = '```';
        while ($paragraph =~ /^ *\Q$fence\E *$/m) {
            $fence .= '`';
        }
        my $hl_language = $self->{+__PACKAGE__}{hl_language};
        if ($hl_language !~ /\A[^`\s]\S*\z/) {
            $hl_language = '';
        }
        "$fence$hl_language\n$paragraph\n$fence"
    }

    sub end_item_number {
        my $self = shift;
        if ($self->_last_string =~ /\S/) {
            return $self->SUPER::end_item_number(@_);
        }
        $self->_end_item($self->_private->{item_number} . '. <!-- -->');
    }
}

binmode $_ for \*STDIN, \*STDOUT;

my $parser = Pod2GithubMarkdown->new(
    output_encoding => 'UTF-8',
);
$parser->output_fh(\*STDOUT);
$parser->parse_file(\*STDIN);
