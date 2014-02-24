package Documania::Module;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite (
    new => 0,
    rw  => [qw/description methods/],
);

sub new_from_module {
    my ($class, $module, $base_dir) = @_;

    my $path = $module;
    $path =~ s!::!/!g;
    $path = File::Spec->catfile($base_dir, "lib/$path.pm");
    $class->new_from_file($path);
}

sub new_from_file {
    my ($class, $path) = @_;

    open my $fh, '<:encoding(utf8)', $path or next;

    my @comments;
    my $description;
    my @methods;
    while (my $line = <$fh>) {
        if ($line =~ /^#[ ]*DESCRIPTION\s*:\s*(.*)/) {
            $description = $1;
        } elsif ($line =~ /^#(.*)/) {
            my $m = $1;
            $m =~ s!\A[ ]!!;
            push @comments, $m;
        } elsif ($line =~ /^sub\s+(\S+)/) {
            my $subname = $1;
            my $title;
            for (my $i=0; $i<@comments; $i++) {
                $title = shift @comments;
                last if $title;
            }
            push @methods, {
                name    => $subname,
                title   => $title,
                comment => join("\n", @comments),
            };
        } else {
            @comments = ();
        }
    }

    bless +{
        description => $description,
        methods     => \@methods,
    }, $class;
}

1;

