package Gearman::Spawner::Client::Async;

use strict;
use warnings;

use Gearman::Client::Async;
use base 'Gearman::Client::Async';

use Gearman::Spawner::Util;

use Carp qw( croak );
use Storable qw( nfreeze thaw );

sub new {
    my $ref = shift;
    my $class = ref $ref || $ref;

    my Gearman::Spawner::Client::Async $self = fields::new($class)->SUPER::new(@_);
    return $self;
}

sub run_method {
    my Gearman::Spawner::Client::Async $self = shift;
    my ($class, $methodname, $arg, $options) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    if (ref $options eq 'CODE') {
        $options = { on_complete => $options };
    }

    # wrap callback with marshaling of arguments
    if (my $cb = delete $options->{on_complete}) {
        $options->{on_complete} = sub {
            my $ref_to_frozen_retval = shift;

            if (!$ref_to_frozen_retval || ref $ref_to_frozen_retval ne 'SCALAR') {
                $options->{on_fail}->('marshaling error') if exists $options->{on_fail};
                return;
            }

            my $rets = eval { thaw($$ref_to_frozen_retval) };
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
    $self->add_task(Gearman::Task->new($function, \$serialized, $options));
}

sub run_method_background {
    my Gearman::Spawner::Client::Async $self = shift;
    my ($class, $methodname, $arg) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    my $serialized = nfreeze([$arg]);

    $self->dispatch_background($function => \$serialized);

    return;
}

1;
