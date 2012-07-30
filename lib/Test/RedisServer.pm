package Test::RedisServer;
use strict;
use warnings;
use Any::Moose;

our $VERSION = '0.01';

use Carp;
use File::Temp;
use POSIX qw(SIGTERM WNOHANG);
use Time::HiRes qw(sleep);

has auto_start => (
    is      => 'rw',
    default => 1,
);

has [qw/pid _owner_pid/] => (
    is => 'rw',
);

has conf => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has timeout => (
    is      => 'rw',
    default => 3,
);

has _tmpdir => (
    is         => 'rw',
    lazy_build => 1,
);

no Any::Moose;

sub BUILD {
    my ($self) = @_;

    $self->_owner_pid($$);

    my $tmpdir = $self->_tmpdir;
    unless (defined $self->conf->{port} or defined $self->conf->{unixsocket}) {
        $self->conf->{unixsocket} = "$tmpdir/redis.sock";
    }

    if ($self->conf->{loglevel} and $self->conf->{loglevel} eq 'warning') {
        warn "Test::RedisServer does not support \"loglevel warning\", using \"notice\" instead.\n";
        $self->conf->{loglevel} = 'notice';
    }

    if ($self->auto_start) {
        $self->start;
    }
}

sub DEMOLISH {
    my ($self) = @_;
    $self->stop if defined $self->pid && $$ == $self->_owner_pid;
}

sub start {
    my ($self) = @_;

    return if defined $self->pid;

    my $tmpdir = $self->_tmpdir;
    open my $logfh, '>>', "$tmpdir/redis-server.log"
        or croak "failed to create log file: $tmpdir/redis-server.log";

    my $pid = fork;
    croak "fork(2) failed:$!" unless defined $pid;

    if ($pid == 0) {
        open STDOUT, '>&', $logfh or croak "dup(2) failed:$!";
        open STDERR, '>&', $logfh or croak "dup(2) failed:$!";

        open my $conffh, '>', "$tmpdir/redis.conf" or croak "cannot write conf: $!";
        print $conffh $self->_conf_string;
        close $conffh;

        exec 'redis-server', "$tmpdir/redis.conf"
            or exit($?);
    }
    close $logfh;

    my $ready;
    my $elapsed = 0;
    $self->pid($pid);

    while ($elapsed <= $self->timeout) {
        if (waitpid($pid, WNOHANG) > 0) {
            $self->pid(undef);
            last;
        }
        else {
            my $log = q[];
            if (open $logfh, '<', "$tmpdir/redis-server.log") {
                $log = do { local $/; <$logfh> };
                close $logfh;
            }

            # confirmed this message is included from v1.3.6 (older version in git repo)
            #   to current HEAD (2012-07-30)
            if ($log =~ /The server is now ready to accept connections/) {
                $ready = 1;
                last;
            }
        }

        sleep $elapsed += 0.1;
    }

    unless ($ready) {
        if ($self->pid) {
            $self->pid(undef);
            kill SIGTERM, $pid;
            while (waitpid($self->pid, 0) <= 0) {
            }
        }

        croak "*** failed to launch redis-server ***\n" . do {
            my $log = q[];
            if (open $logfh, '<', "$tmpdir/redis-server.log") {
                $log = do { local $/; <$logfh> };
                close $logfh;
            }
            $log;
        };
    }

    $self->pid($pid);
}

sub stop {
    my ($self, $sig) = @_;

    local $?; # waitpid may change this value :/
    return unless defined $self->pid;

    $sig ||= SIGTERM;

    kill $sig, $self->pid;
    while (waitpid($self->pid, 0) <= 0) {
    }

    $self->pid(undef);
}

sub connect_info {
    my ($self) = @_;

    my $host = $self->conf->{bind} || '0.0.0.0';
    my $port = $self->conf->{port};
    my $sock = $self->conf->{unixsocket};

    if ($port && $port > 0) {
        return (server => $host . ':' . $port);
    }
    else {
        return (sock => $sock);
    }
}

sub _build__tmpdir {
    File::Temp->newdir( CLEANUP => 1 );
}

sub _conf_string {
    my ($self) = @_;

    my $conf = q[];
    my %conf = %{ $self->conf };
    while (my ($k, $v) = each %conf) {
        next unless defined $v;
        $conf .= "$k $v\n";
    }

    $conf;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Test::RedisServer - 

=head1 SYNOPSIS

use Redis;
use Test::RedisServer;
use Test::More;

my $redis_server = Test::RedisServer->new;

my $redis = Redis->new( $redis_server->connect_info );

