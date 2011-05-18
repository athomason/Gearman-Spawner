use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use ClientTest;

use Test::More;

if (eval "use Gearman::Spawner::Client::AnyEvent; 1") {
    plan tests => 15;
}
else {
    plan skip_all => 'AnyEvent client not available';
}

my $tester = eval { ClientTest->new };
SKIP: {
$@ && skip $@, 15;

my @tests = $tester->tests;

my $cv = AnyEvent->condvar;
my $client = Gearman::Spawner::Client::AnyEvent->new(job_servers => [$tester->server]);
my $next_test;
$next_test = sub {
    return $cv->send unless @tests;
    my $test = shift @tests;
    $client->run_method(
        class => $tester->class,
        method => $test->[0],
        data => $test->[1],
        success_cb => sub {
            $test->[2]->(@_);
            $next_test->();
        },
        error_cb => sub {
            my $err = shift;
            fail("$test->[0] tripped on_failure: $err"),
            $next_test->();
        },
        timeout => 3,
    );
};
$next_test->();
$cv->recv;

}
