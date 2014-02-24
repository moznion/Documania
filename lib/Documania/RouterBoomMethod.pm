package Documania::RouterBoomMethod;
use strict;
use warnings;
use utf8;
use parent qw/Documania/;
use Documania::Module;
use Class::Accessor::Lite::Lazy (
    new => 0,
    rw => [qw/router filter/],
    ro_lazy => [qw/modules/]
);

sub new {
    my ($class, $args) = @_;

    my $self = $class->SUPER::new($args);
    $self->router($args->{router});
    $self->filter($args->{filter});

    return $self;
}

sub _build_modules {
    my $self = shift;

    my @built;
    my %seen;

    my @PKGS;
    my %ROUTES;

    for my $point ($self->router->routes) {
        my ($method, $path, $stuff) = @$point;
        if ((!$self->filter) || $path =~ $self->filter) {
            push @PKGS, $stuff->[0];
            push @{$ROUTES{$stuff->[0]}}, [$method, $path, $stuff];
        }
    }

    for my $pkg (@PKGS) {
        next if $seen{$pkg}++;

        my $doc = Documania::Module->new_from_module($pkg, $self->base_dir);
        my @methods;
        for my $point (@{$ROUTES{$pkg}}) {
            my ($http_method, $path, $stuff) = @$point;

            my ($info) = grep { $_->{name} eq $stuff->[1] } @{$doc->methods};
            push @methods, +{
                http_method => $http_method->[0] eq 'POST' ? 'POST' : 'GET',
                path => $path,
                ($info ? %$info : ()),
            };
        }
        push @built, +{
            name => $pkg,
            description => $doc->description,
            methods     => \@methods,
        };
    }
    return \@built;
}

1;

