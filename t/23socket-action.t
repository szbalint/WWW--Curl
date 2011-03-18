#!perl

use strict;
use warnings;
use Test::More tests => 18;
use WWW::Curl::Easy;
use WWW::Curl::Multi;

my ($head1, $head2, $body1, $body2 );
open my $_head1, ">", \$head1;
open my $_body1, ">", \$body1;
open my $_head2, ">", \$head2;
open my $_body2, ">", \$body2;

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

my $sock_read = 0;
my $sock_write = 0;
my $sock_read_all = 0;
my $sock_write_all = 0;
my $sock_change = 0;

my $vec_read = '';
my $vec_write = '';

my ($vec_r, $vec_w, $vec_e);

my $timer_change = 0;
my $timeout = undef;

sub on_socket
{
	my ( $user_data, $socket, $what ) = @_;
	#warn "on_socket( $socket, $what )\n";

	$sock_change = 0;
	if ( $what == CURL_POLL_NONE ) {
		#warn "on_socket: register, not interested in readiness\n";
		vec( $vec_read, $socket, 1 ) = 0;
		vec( $vec_write, $socket, 1 ) = 0;
	} elsif ( $what == CURL_POLL_IN ) {
		#warn "on_socket: register, interested in read readiness\n";
		$sock_read++;
		$sock_read_all++;
		vec( $vec_read, $socket, 1 ) = 1;
		vec( $vec_write, $socket, 1 ) = 0;
	} elsif ( $what == CURL_POLL_OUT ) {
		#warn "on_socket: register, interested in write readiness\n";
		$sock_write++;
		$sock_write_all++;
		vec( $vec_read, $socket, 1 ) = 0;
		vec( $vec_write, $socket, 1 ) = 1;
	} elsif ( $what == CURL_POLL_INOUT ) {
		#warn "on_socket: register, interested in both read and write readiness\n";
		$sock_read++;
		$sock_read_all++;
		$sock_write++;
		$sock_write_all++;
		vec( $vec_read, $socket, 1 ) = 1;
		vec( $vec_write, $socket, 1 ) = 1;
	} elsif ( $what == CURL_POLL_REMOVE ) {
		#warn "on_socket: unregister\n";
		$sock_read--;
		$sock_write--;
		vec( $vec_read, $socket, 1 ) = 0;
		vec( $vec_write, $socket, 1 ) = 0;
	} else {
		die "on_socket: unknown action code\n";
	}
}

sub on_timer
{
	my ( $user_data, $timeout_ms ) = @_;
	#warn "on_timer( $timeout_ms )\n";
	$timer_change++;
	if ( $timeout_ms < 0 ) {
		$timeout = 1.0;
	} else {
		$timeout = $timeout_ms / 1000;
	}
}

my $curl1 = WWW::Curl::Easy->new();
$curl1->setopt( CURLOPT_URL, $url );
$curl1->setopt( CURLOPT_WRITEHEADER, $_head1 );
$curl1->setopt( CURLOPT_WRITEDATA, $_body1 );
$curl1->setopt( CURLOPT_PRIVATE, "one" );

my $curl2 = WWW::Curl::Easy->new();
$curl2->setopt( CURLOPT_URL, $url );
$curl2->setopt( CURLOPT_WRITEHEADER, $_head2 );
$curl2->setopt( CURLOPT_WRITEDATA, $_body2 );
$curl2->setopt( CURLOPT_PRIVATE, "two" );

my $curlm = WWW::Curl::Multi->new();
$curlm->setopt( CURLMOPT_SOCKETFUNCTION, \&on_socket );
$curlm->setopt( CURLMOPT_TIMERFUNCTION, \&on_timer );
$curlm->add_handle( $curl1 );
$curlm->add_handle( $curl2 );

# init
my $active = $curlm->socket_action();
ok( defined $timeout, "timeout set" );
ok( $timeout > 1, "timeout set: at least 1 second" );
ok( $timer_change > 1, "timeout set: changed more than once" );
$timer_change = 0;
ok( $sock_read == 2, "registered 2 sockets for reading" );
ok( $sock_read_all == 2, "registered 2 sockets for reading" );

$sock_read_all = 0;

#warn "main loop\n";
do {
	my $active_now;
	my ($cnt, $timeout) = select $vec_r = $vec_read, $vec_w = $vec_write,
		$vec_e = $vec_read | $vec_write, $timeout;
	if ( $cnt ) {
		my $maxfd = 8 * length( $vec_e ) - 1;
		foreach my $i ( 0..$maxfd ) {
			my $bitmask = 0;
			$bitmask |= CURL_CSELECT_IN
				if vec $vec_r, $i, 1;
			$bitmask |= CURL_CSELECT_OUT
				if vec $vec_w, $i, 1;
			$bitmask |= CURL_CSELECT_ERR
				if vec $vec_e, $i, 1;

			next unless $bitmask;

			#warn "socket_action( $i, $bitmask );\n";
			$active_now = $curlm->socket_action( $i, $bitmask );
		}
	} else {
		#warn "socket_action( CURL_SOCKET_TIMEOUT, 0 );\n";
		$active_now = $curlm->socket_action( CURL_SOCKET_TIMEOUT, 0 );
	}

	if ( $active_now != $active ) {
		while (my ($id,$value) = $curlm->info_read) {
			#warn "Reaped child: $id, $value\n";
			ok( $value == 0, "child $id exited correctly" );
		}
		$active = $active_now;
	}
} while ( $active );

#warn "done\n";
ok( $timer_change > 0, "timeout updated" );
ok( $sock_read_all == 2, "registered 2 sockets for reading" );
ok( $sock_write_all == 2, "registered 2 sockets for writing" );
ok( $sock_read <= 0, "deregistered all sockets for reading" );
ok( $sock_write <= 0, "deregistered all sockets for writing" );

$timer_change = 0;
$sock_change = 0;

$curlm->socket_action( CURL_SOCKET_TIMEOUT, 0 );
ok( $timer_change == 0, "nothing unexpected happened: timer" );
ok( $sock_change == 0, "nothing unexpected happened: socket" );

ok( length $head1, "received head1" );
ok( length $head2, "received head2" );
ok( length $body1, "received body1" );
ok( length $body2, "received body2" );
