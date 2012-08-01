use strict;
use warnings;
use Test::More;

use Redis;
use Test::RedisServer;
use POSIX qw/SIGTERM/;

eval { Test::RedisServer->new } or plan skip_all => 'redis-server is required in PATH to run this test';

my $server = Test::RedisServer->new;

my $pid = fork;
die 'fork failed' unless defined $pid;

if ($pid == 0) {
    sleep 1;
    kill SIGTERM, $server->pid;
    exit(0);
}

$server->wait_exit;

pass 'process exited';
is $server->pid, undef, 'no pid ok';

done_testing;
    
