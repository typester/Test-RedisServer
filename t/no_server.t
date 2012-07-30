use strict;
use warnings;
use Test::More;

use Test::RedisServer;

local $ENV{PATH} = '';

my $server;
eval {
    $server = Test::RedisServer->new;
};
ok !$server, 'server does not created ok';
like $@, qr/^Can't exec "redis-server": No such file or directory/m, 'error msg ok';

done_testing;
