use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Gearman::Spawner;
use Gearman::Spawner::Server;

use Test::More;

if (eval "use Gearman::Spawner::Client::Sync; 1") {
    plan tests => 10;
}
else {
    plan skip_all => 'synchronous client not available';
}

my $server = Gearman::Spawner::Server->address;
SKIP: {
$@ && skip $@, 10;

my $spawner = Gearman::Spawner->new(
    servers => [$server],
    workers => {
        CountWorker => {
            count => 1,
        },
    },
);

my $client = Gearman::Spawner::Client::Sync->new(job_servers => [$server]);
my $call = sub { $client->run_method(qw( class CountWorker method ), shift) };

my $pid1 = $call->('pid');
is($call->('inc'), 1, 'inc 1');
is($call->('inc'), 2, 'inc 2');
is($call->('pid'), $pid1, 'same worker after incs');

# exception in worker should not kill it
eval { $call->('die') };
is($call->('pid'), $pid1, 'same worker after die');
is($call->('inc'), 3, 'inc 3');

# worker exiting should
eval { $call->('exit') };
my $pid2 = $call->('pid');
isnt($pid2, $pid1, 'new worker after exit');
is($call->('inc'), 1, 'inc 1');

ok(kill('INT', $pid2), 'killed worker 2');
my $pid3 = $call->('pid');
isnt($pid3, $pid2, 'new worker after kill');
is($call->('inc'), 1, 'inc 1');

}
