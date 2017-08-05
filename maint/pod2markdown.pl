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
        $self->accept_targets('meta.language');
        $self->{+__PACKAGE__} = {
            meta_language => '',
        };
        $self
    }

    sub start_for {
        my $self = shift;
        my ($attr) = @_;
        if ($attr->{target} eq 'meta.language') {
            $self->_new_stack;
            $self->_stack_state->{for_meta_language} = 1;
            return;
        }
        $self->SUPER::start_for(@_)
    }

    sub end_for {
        my $self = shift;
        my ($attr) = @_;
        if ($self->_stack_state->{for_meta_language}) {
            my $text = $self->_pop_stack_text;
            s/\A\s+//, s/\s+\z// for $text;
            if ($text =~ /\A\S+\z/) {
                $self->{+__PACKAGE__}{meta_language} = $text;
            } else {
                $self->{+__PACKAGE__}{meta_language} = '';
                $self->scream($attr->{start_line}, "bad meta.language value: '$text'")
                    if $text =~ /\S/;
            }
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
        "$fence$self->{+__PACKAGE__}{meta_language}\n$paragraph\n$fence"
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
