package CrashWorker;

use strict;
use warnings;

use base 'Gearman::Spawner::Worker';

sub new {
    my $self = shift;
    $self = fields::new($self) unless ref $self;
    $self->SUPER::new(@_);
    $self->register_method('boom');
    return $self;
}

sub boom {
	my CrashWorker $self = shift;
	$Data::Dumper::Deparse = 1;
	die "died here with silence";
}
1;
