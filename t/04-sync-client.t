use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Gearman::Spawner;
use Gearman::Spawner::TestServer;
use Test::More;

if (eval "use Gearman::Spawner::Client::Sync; 1") {
    plan tests => 15;
}
else {
    plan skip_all => 'synchronous client not available';
}

my $class = 'MethodWorker';

my $server = Gearman::Spawner::TestServer->address;

my $left_hand = 3;
my $right_hand = 5;

my $spawner = Gearman::Spawner->new(
    servers => [$server],
    workers => {
        $class => {
            data => {
                left_hand => $left_hand,
            },
        },
    },
);
sleep 1; # give workers a chance to register

my @tests = (

    [constant => 0, sub {
        my $number = shift;
        is(ref $number, '', 'numeric scalar');
        is($number, 123, 'numeric scalar value');
    }],

    [constant => 1, sub {
        my $string = shift;
        is(ref $string, '', 'string scalar');
        is($string, 'string', 'string scalar value');
    }],

    [echo => undef, sub {
        my $echoed = shift;
        is(ref $echoed, '', 'undef');
        is($echoed, undef, 'undef value');
    }],

    [echo => 'foo', sub {
        my $echoed = shift;
        is(ref $echoed, '', 'scalar');
        is($echoed, 'foo', 'scalar value');
    }],

    [echo => ['foo'], sub {
        my $echoed = shift;
        is(ref $echoed, 'ARRAY', 'arrayref');
        is_deeply($echoed, ['foo'], 'array value');
    }],

    [echo => {'foo' => 'bar'}, sub {
        my $echoed = shift;
        is(ref $echoed, 'HASH', 'hashref');
        is_deeply($echoed, {'foo' => 'bar'}, 'hash value');
    }],

    [echo_ref => \'bar', sub {
        my $echoed_ref = shift;
        is(ref $echoed_ref, 'SCALAR', 'string scalar ref');
        is($$echoed_ref, 'bar', 'string scalar ref value');
    }],

    [add => { right_hand => $right_hand }, sub {
        my $return = shift;
        is($return->{sum}, $left_hand + $right_hand, 'addition');
    }],

);

my $client = Gearman::Spawner::Client::Sync->new(job_servers => [$server]);
for my $test (@tests) {
    my $ret = $client->run_method($class, $test->[0], $test->[1]);
    $test->[2]->($ret);
};
