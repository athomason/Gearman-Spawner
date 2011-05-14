package Gearman::Spawner::Client::Sync;

use strict;
use warnings;

use Gearman::Client;
use base 'Gearman::Client';

use Gearman::Spawner::Util;
use Storable qw( nfreeze thaw );

sub new {
    my $ref = shift;
    my $class = ref $ref || $ref;

    my Gearman::Spawner::Client::Sync $self = fields::new($class)->SUPER::new(@_);

    return $self;
}

sub run_method {
    my Gearman::Spawner::Client::Sync $self = shift;
    my ($class, $methodname, $arg) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    my $serialized_arg = \nfreeze([$arg]);

    my $ref_to_serialized_retval = $self->do_task($function => $serialized_arg);

    if (!$ref_to_serialized_retval || ref $ref_to_serialized_retval ne 'SCALAR') {
        die "marshaling error";
    }

    my $rets = eval { thaw($$ref_to_serialized_retval) };
    die "unmarshaling error: $@" if $@;
    die "unmarshaling error (incompatible clients?)" if ref $rets ne 'ARRAY';

    return wantarray ? @$rets : $rets->[0];
}

sub run_method_background {
    my Gearman::Spawner::Client::Sync $self = shift;
    my ($class, $methodname, $arg) = @_;

    my $function = Gearman::Spawner::Util::method2function($class, $methodname);

    my $serialized_arg = \nfreeze([$arg]);

    $self->dispatch_background($function => $serialized_arg);

    return;
}

1;
