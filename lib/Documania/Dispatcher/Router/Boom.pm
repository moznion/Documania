package Documania::Dispatcher::Router::Boom;
use strict;
use warnings;
use utf8;
use Router::Boom::Method;

sub analyze_routes {
    my ($class, $dispatcher_class) = @_;

    no warnings 'redefine';
    my $orig = Router::Boom::Method->can('add');
    my ($packages, $routes);
    local *Router::Boom::Method::add = sub {
        my ($self, $method, $path, $stuff) = @_;
        if ($path =~ m{api}) {
            push @$packages, $stuff->[0];
            push @{$routes->{$stuff->[0]}}, [$method->[0], $path, $stuff->[1]];
        }
        $orig->(@_);
    };

    eval "require '$dispatcher_class'"; ## no critic

    return ($packages, $routes);
}

1;

