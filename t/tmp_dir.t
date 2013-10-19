use strict;
use warnings;
use File::Temp;
use Path::Class qw/dir/;
use Test::More;
use Test::TCP;

use Test::RedisServer;

eval { Test::RedisServer->new } or plan skip_all => 'redis-server is required in PATH to run this test';

my $tmp_dir = File::Temp->newdir( CLEANUP => 1 );

my $tmp_root_dir = File::Spec->tmpdir();
my $initial_children_count = dir($tmp_root_dir)->children;

$ENV{TMPDIR} = $tmp_root_dir;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        Test::RedisServer->new(
            auto_start => 0,
            tmpdir     => $tmp_dir,
            conf       => { port => $port },
        )->exec;
    }
);

$server = undef;

my $count = dir($tmp_root_dir)->children;
is $count, $initial_children_count, "no files remained after server shutdown";

done_testing;
