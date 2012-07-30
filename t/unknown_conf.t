use strict;
use warnings;
use Test::More;

use Test::RedisServer;

my $server;
eval {
    $server = Test::RedisServer->new( conf => {
        'unknown_key' => 'unknown_val',
    });
};

ok !$server, 'server does not initialize ok';
like $@, qr/\*\*\* FATAL CONFIG FILE ERROR \*\*\*/, 'error msg ok';

done_testing;
