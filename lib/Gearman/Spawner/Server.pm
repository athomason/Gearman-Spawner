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

		require Gearman::Util; # Gearman::Server doesn't itself
		my $server = Gearman::Server->new;
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

1;
