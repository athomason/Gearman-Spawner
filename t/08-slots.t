use strict;
use warnings;

use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use Gearman::Spawner;
use Gearman::Spawner::TestServer;
use IO::Socket::INET;

if (eval "use Gearman::Spawner::Client::Async; 1") {
    plan tests => 10;
}
else {
    plan skip_all => 'synchronous client not available';
}

my $server = Gearman::Spawner::TestServer->address;

my $number = 10;

my $spawner = Gearman::Spawner->new(
    servers => [$server],
    workers => {
        SlotWorker => {
            count => $number,
        },
    },
);
sleep 1; # give workers a chance to register

my $client = Gearman::Spawner::Client::Async->new(job_servers => [$server]);
my $returned = 0;
my @slots = (1 .. $number);
my %seen = map { $_ => 1 } @slots;
for my $test (@slots) {
    $client->run_method(SlotWorker => slot => undef => {
        on_complete => sub {
            my $slot = shift;
            delete $seen{$slot};
            return Danga::Socket->SetPostLoopCallback(sub { 0 }) if ++$returned >= $number;
        },
        on_fail => sub {
            return Danga::Socket->SetPostLoopCallback(sub { 0 }) if ++$returned >= $number;
        }
    });
};

Danga::Socket->EventLoop;

ok(!exists $seen{$_}, "saw worker $_") for @slots;
