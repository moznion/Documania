package Documania::RouterSimple;
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

    my %routes;
    my @packages;
    for my $point (@{$self->router->routes}) {
        my $path  = $point->{pattern};
        my $stuff = $point->{dest};
        if ((!$self->filter) || $path =~ $self->filter) {
            my $controller = $stuff->{controller};
            push @packages, $controller;
            push @{$routes{$controller}}, +{
                path        => $path,
                stuff       => $stuff,
                http_method => $point->{method},
            };
        }
    }

    my %seen;
    my @built;
    for my $package (@packages) {
        next if $seen{$package}++;

        my $doc = Documania::Module->new_from_module($package, $self->base_dir);

        my @methods;
        for my $point (@{$routes{$package}}) {
            my $action      = $point->{stuff}->{action};
            my ($info)      = grep { $_->{name} eq $action } @{$doc->methods};
            my $http_method = shift $point->{http_method};

            push @methods, +{
                http_method => $http_method eq 'POST' ? 'POST' : 'GET',
                path => $point->{path},
                ($info ? %$info : ()),
            };
        }
        push @built, +{
            name        => $package,
            description => $doc->description,
            methods     => \@methods,
        };
    }
    return \@built;
}

1;

