package Documania::Dispatcher::Router::Simple;
use strict;
use warnings;
use utf8;
use Router::Simple;

sub analyze_routes {
    my ($class, $dispatcher_class) = @_;

    no warnings 'redefine';
    my $orig = Router::Simple->can('connect');
    my ($packages, $routes);
    local *Router::Simple::connect = sub {
        my ($self, $path, $stuff, $opt) = @_;
        if ($path =~ m{api}) {
            push @$packages, $stuff->{controller};
            push @{$routes->{$stuff->{controller}}}, [$opt->{method}, $path, $stuff->{action}];
        }
        $orig->(@_);
    };

    eval "require '$dispatcher_class'"; ## no critic

    return ($packages, $routes);
}

1;

