package Documania;
use 5.008005;
use strict;
use warnings;
use utf8;
use Carp ();
use Encode qw/encode_utf8/;
use FindBin;
use Text::Xslate;
use Class::Accessor::Lite (
    new => 0,
    rw  => [qw/base_dir template syntax dispatcher_module/],
);

our $VERSION = "0.01";

use constant DEFAULT_TEMPLATE => <<'...';
# API docs

This documentation was generated by `[% generator %]`.

[% FOR module IN modules %]
## [% module.description || module.name %]
[% FOR method IN module.methods %]
### [% method.title || method.path %]

    [% method.http_method %] [% method.path %]

[% method.comment %]
[% END %]
[% END %]
...

sub new {
    my ($class, $args) = @_;

    my $dispatcher_module = $args->{dispatcher_module} || 'Router::Boom';
    $dispatcher_module = 'Documania::Dispatcher::' . $dispatcher_module;

    bless {
        base_dir => $args->{base_dir} || $FindBin::Bin,
        syntax   => $args->{syntax}   || 'TTerse',
        template => $args->{template} || DEFAULT_TEMPLATE,
        dispatcher_module => $dispatcher_module,
    }, $class;
}

sub generate {
    my ($self, $dispatcher, $output_path) = @_;

    Carp::croak("[ERROR] Dispatcher class name or path is required") unless $dispatcher;
    Carp::croak("[ERROR] Output file path is required") unless $output_path;

    $dispatcher =~ s!::!/!g;
    if ($dispatcher !~ m/\.pm\Z/) {
        $dispatcher .= '.pm';
    }
    $dispatcher = $self->base_dir . '/lib/' . $dispatcher;

    my $dispatcher_module = $self->dispatcher_module;
    eval "require $dispatcher_module"; ## no critic
    my ($packages, $routes) = $dispatcher_module->analyze_routes($dispatcher);

    my $docs = $self->_build_docs($packages, $routes);
    my $xslate = Text::Xslate->new(syntax => $self->syntax);
    my $content = $xslate->render_string($self->template, +{
        modules => $docs,
        generator => $0,
    });
    $self->_spew_utf8($output_path, $content);
}

sub _spew_utf8 {
    my ($self, $fname, $content) = @_;

    open my $fh, '>:encoding(utf-8)', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $content;
}

sub _build_docs {
    my ($self, $packages, $routes) = @_;

    my @built;
    my %seen;
    for my $pkg (@{$packages}) {
        next if $seen{$pkg}++;

        my $doc = $self->_parse_package($pkg);
        my @methods;
        for my $point (@{$routes->{$pkg}}) {
            my ($http_method, $path, $action) = @$point;
            my ($info) = grep { $_->{name} eq $action } @{$doc->{methods}};
            push @methods, +{
                http_method => $http_method =~ /\Apost\Z/i ? 'POST' : 'GET',
                path => $path,
                %$info,
            };
        }
        push @built, +{
            name => $pkg,
            description => $doc->{description},
            methods     => \@methods,
        };
    }
    return \@built;
}

sub _parse_package {
    my ($self, $module) = @_;

    my $path = $module;
    $path =~ s!::!/!g;
    $path = File::Spec->catfile($self->base_dir, "lib/$path.pm"); # TODO
    open my $fh, '<:encoding(utf8)', $path
        or next;

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
    return +{ description => $description, methods => \@methods };
}

1;
__END__

=encoding utf-8

=head1 NAME

Documania - It's new $module

=head1 SYNOPSIS

    use Documania;

=head1 DESCRIPTION

Documania is ...

=head1 LICENSE

Copyright (C) moznion.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

moznion E<lt>moznion@gmail.comE<gt>

=cut

