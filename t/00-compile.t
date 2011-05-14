use strict;
use warnings;

use Test::More tests => 3;

use_ok('Gearman::Spawner');

eval { require Gearman::Spawner::Client::Sync };
ok(!$@ || $@ =~ m{Can't locate Gearman/Client.pm}, 'Gearman::Spawner::Client::Sync') || diag $@;

eval { require Gearman::Spawner::Client::Async };
ok(!$@ || $@ =~ m{Can't locate Gearman/Client/Async.pm}, 'Gearman::Spawner::Client::Async') || diag $@;
