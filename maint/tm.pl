use v5.12.0;
use warnings;

my $tmpl_file;
(($tmpl_file, my $perl_ver_min, my $perl_ver_max) = @ARGV) == 3
    && (my $out_file = $tmpl_file) =~ s/\.tmpl\z//
    or die "Usage: $0 FILE.tmpl PERL_VER_MIN PERL_VER_MAX\n";

open my $fh, '<', $tmpl_file
    or die "$0: can't open for reading: $tmpl_file: $!\n";

my %tmpl_var = (
    'perl-versions' => '[' . join(', ',  map $_ % 2 ? () : qq{"5.$_"}, $perl_ver_min .. $perl_ver_max) . ']',
);

my $output = '';
while (my $line = readline $fh) {
    $line =~ s{<\?php echo \h*(.*?)\h*; \?>}{
        $tmpl_var{$1} // die "Unknown template parameter '$1'";
    }eg;
    $output .= $line;
}

my $out_file_tmp = "$out_file.~tmp~";

open my $out_fh, '>', $out_file_tmp
    or die "$0: can't open for writing: $out_file_tmp: $!\n";

print $out_fh $output
    or die "$0: can't write: $out_file_tmp: $!\n";

close $out_fh
    or die "$0: can't write: $out_file_tmp: $!\n";

rename $out_file_tmp, $out_file
    or die "$0: can't rename $out_file_tmp to $out_file: $!\n";
