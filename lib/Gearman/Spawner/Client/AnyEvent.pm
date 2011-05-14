package Gearman::Spawner::Client::AnyEvent;

use strict;
use warnings;

use Any::Moose;
extends 'AnyEvent::Gearman::Client';
no Any::Moose;

use Gearman::Spawner::Util;

use Carp qw( croak );
use Storable qw( nfreeze thaw );

sub run_method {
    my $self = shift;
    my ($class, $methodname, $arg, $options) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    if (ref $options eq 'CODE') {
        $options = { on_complete => $options };
    }

    # wrap callback with marshaling of arguments
    if (my $cb = delete $options->{on_complete}) {
        $options->{on_complete} = sub {
            my $task = shift;
            my $frozen_retval = shift;

            if (!$frozen_retval) {
                $options->{on_fail}->('marshaling error') if exists $options->{on_fail};
                return;
            }

            my $rets = eval { thaw($frozen_retval) };
            if ($@) {
                $options->{on_fail}->($@) if exists $options->{on_fail};
                return;
            }
            elsif (ref $rets ne 'ARRAY') {
                $options->{on_fail}->('marshaling error') if exists $options->{on_fail};
                return;
            }

            $cb->(@$rets);
        };
    }

    my $serialized = nfreeze([$arg]);
    $self->add_task($function, $serialized, %$options);
}

sub run_method_background {
    my $self = shift;
    my ($class, $methodname, $arg) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    my $serialized = nfreeze([$arg]);

    $self->add_task_bg($function => $serialized);

    return;
}

1;
