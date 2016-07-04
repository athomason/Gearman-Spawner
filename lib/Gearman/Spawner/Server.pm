package Gearman::Spawner::Server;

use strict;
use warnings;

use Gearman::Spawner::Process;
use IO::Socket::INET;
use IO::Handle ();

use base 'Gearman::Spawner::Process';

my ($ADDRESS, $INSTANCE);
sub address {
    my $class = shift;

    return $ADDRESS if $ADDRESS;
    return $ADDRESS = $ENV{GEARMAN_SERVER} if $ENV{GEARMAN_SERVER};

    $INSTANCE = $class->create;
    return $ADDRESS = $INSTANCE->address;
}

sub create {
    my $class = shift;

    unless (eval "require Gearman::Server; 1") {
        die "need server to run against; either set GEARMAN_SERVER or install Gearman::Server\n";
    }

    return Gearman::Spawner::Server::Instance->new($class->fork_gearmand());
}

# start up a gearmand that exits when its parent process does. returns the
# address of the listening server and its pid
sub fork_gearmand {
    my $class = shift;

    # NB: this relies on Gearman::Spawner::Process allowing use of fork,
    # run_periodically, exit_with_parent, and loop as class methods instead of
    # object methods

    pipe(my $piperead, my $pipewrite); # open pipe so child can communicate with me, because i'm the parent
    $pipewrite->autoflush(1);

    $Gearman::Spawner::Process::CHECK_PERIOD = 0.5;
    my $proc_name = $0;
    my $pid = $class->fork("[Gearman::Server] $0", 1);

    if ($pid) { # parent
        close $pipewrite;
        # wait for the child to announce the address
        chomp(my $address = <$piperead>);
        close $piperead;
        # wait until server is contactable
        for (1 .. 50) {
            my $sock = IO::Socket::INET->new($address);
            return ($address, $pid) if $sock;
            select undef, undef, undef, 0.1;
        }
        die "couldn't contact server at $address: $!";
    } else { # child
        close $piperead;

        my $server = Gearman::Spawner::Server::Shadow->new;
        my $sock = $server->create_listening_sock;

        my $address = $sock->sockhost.":".$sock->sockport;
        $0 = "[Gearman::Server $address] $proc_name"; # set child name again
        print $pipewrite $address;
        close $pipewrite;

        $class->loop;
    }
}

package Gearman::Spawner::Server::Instance;

use strict;
use warnings;

sub new {
    my $class = shift;
    my ($address, $pid) = @_;
    return bless {
        address => $address,
        pid => $pid,
        me => $$,
    }, $class;
}

sub address {
    my $self = shift;
    return $self->{address};
}

sub DESTROY {
    my $self = shift;
    kill 'INT', $self->{pid} if $$ == $self->{me};
}

package Gearman::Spawner::Server::Shadow;

use strict;
use warnings;

use parent 'Gearman::Server';

use Gearman::Util;

sub new {
    my ($class, %opts) = @_;
    my $self = ref $class ? $class : fields::new($class);

    $self->{client_map}    = {};
    $self->{sleepers}      = {};
    $self->{sleepers_list} = {};
    $self->{job_queue}     = {};
    $self->{job_of_handle} = {};
    $self->{max_queue}     = {};
    $self->{job_of_uniq}   = {};
    $self->{listeners}     = [];
    $self->{wakeup}        = 3;
    $self->{wakeup_delay}  = .1;
    $self->{wakeup_timers} = {};

    $self->{handle_ct} = 0;
    $self->{handle_base} = "H:" . Sys::Hostname::hostname() . ":";

    my $port = delete $opts{port};

    my $wakeup = delete $opts{wakeup};

    if (defined $wakeup) {
        die "Invalid value passed in wakeup option"
            if $wakeup < 0 && $wakeup != -1;
        $self->{wakeup} = $wakeup;
    }

    my $wakeup_delay = delete $opts{wakeup_delay};

    if (defined $wakeup_delay) {
        die "Invalid value passed in wakeup_delay option"
            if $wakeup_delay < 0 && $wakeup_delay != -1;
        $self->{wakeup_delay} = $wakeup_delay;
    }

    croak("Unknown options") if %opts;

    # NOTE: Commented this out versus Gearman::Server, because of duplicate
    # listeners/calls to create_listening_sock
    # $self->create_listening_sock($port);

    return $self;
}

sub new_client {
    my ($self, $sock) = @_;
    my $client = Gearman::Server::Client->new($sock, $self);

    # Force Enable Exceptions
    # TODO: This should be configurable, because exceptions can be disabled on
    # server side
    $client->{options}->{exceptions} = 1;

    $client->watch_read(1);
    $self->{client_map}{$client->{fd}} = $client;
}


1;
