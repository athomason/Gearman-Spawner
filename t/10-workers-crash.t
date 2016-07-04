use strict;
use warnings;

use Test::More tests => 9;

use FindBin '$Bin';
use lib "$Bin/lib";
use lib "$Bin/../lib";

use Gearman::Spawner;
use Gearman::Spawner::Server;
use Gearman::Spawner::Client::AnyEvent;
use IO::Socket::INET;

my $server = Gearman::Spawner::Server->address;

my $class = 'CrashWorker';

my $spawner = Gearman::Spawner->new(
    servers => [$server],
    workers => {
        $class => { },
    },
);
sleep 1; # give workers a chance to register

my $pid = $spawner->pid;
ok(kill(0, $pid), 'spawner is alive');

sub check_workers {
    my $mgmt = IO::Socket::INET->new($server);
    ok($mgmt, 'can connect to server');

    ok($mgmt->print("workers\n"), "can send workers command to server");
    $mgmt->shutdown(1);
    my $buf = '';
    while (<$mgmt>) {
        last if /^\./;
        $buf .= $_;
    }

    return $buf;
}

my $status = check_workers();
like($status, qr/$class/, "$class worker is registered") || diag $status;

my $client = Gearman::Spawner::Client::AnyEvent->new(
	job_servers => [ $server ],
);

my $cv = AnyEvent->condvar;

$client->run_method(
	class => 'CrashWorker',
	method => 'boom',
	success_cb => sub {
		print STDERR "shouldn't be here success_cb\n";
		$cv->send;
	},
	error_cb => sub {
		my $reason = shift;
		ok $reason =~ /died here with silence/, "got reason why we died reason=".length $reason;
		#print "reason=$reason\n";
		#use Data::Dumper;
		#print STDERR "here in error_cb\n";
		#print Dumper(\@_);
		$cv->send;
	},
);
$cv->recv;

my $timed_out = 0;
$SIG{ALRM} = sub { $timed_out++ };
alarm 1;
undef $spawner;
waitpid $pid, 0;
ok(!$timed_out, 'spawner dies on object destruction');

select undef, undef, undef, 0.5;

$status = check_workers();
unlike($status, qr/$class/, "$class worker is no longer registered") || diag $status;
