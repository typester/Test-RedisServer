use strict;
use warnings;

BEGIN {
    my @devmods = qw(
        Module::Install::AuthorTests
        Module::Install::ReadmeFromPod
        Module::Install::Repository
    );
    my @not_available;

    eval qq{use inc::Module::Install; 1;} or push @not_available, 'inc::Module::Install';
    for my $mod (@devmods) {
        eval qq{require $mod} or push @not_available, $mod;
    }
    if (@not_available) {
        print qq{# The following modules are not available.\n};
        print qq{# `$^X $0 | cpanm` will install them:\n};
        print $_, "\n" for @not_available;
        print "\n";
        exit -1;
    }
}

use inc::Module::Install;

name 'Test-RedisServer';
all_from 'lib/Test/RedisServer.pm';

test_requires 'Redis';
test_requires 'Test::More' => '0.86';
test_requires 'Test::TCP'  => '1.17';

requires 'perl'       => '5.008001';
requires 'File::Temp' => '0.19'; # newdir
requires 'Any::Moose' => '0.18';

readme_from 'lib/Test/RedisServer.pm';
author_tests 'xt';
auto_set_repository;

WriteAll;
