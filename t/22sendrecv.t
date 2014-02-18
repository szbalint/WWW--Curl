#!perl
use strict;
use warnings;
use Test::More;
use WWW::Curl::Easy;

my $vi = WWW::Curl::Easy::version_info();
plan skip_all => "curl $vi->{version} does not support send and recv"
	if $vi->{version_num} < 0x071202;
plan tests => 7;

# host must support keep-alive connections
my $url = $ENV{CURL_TEST_URL} || "http://google.com";

( my $host = $url ) =~ s#^.*?://##;

# make sure nothing blocks
alarm 5;

my $c = WWW::Curl::Easy->new();
$c->setopt( CURLOPT_URL, $url );
$c->setopt( CURLOPT_CONNECT_ONLY, 1 );

my $r = $c->perform();
ok( $r == 0, "perform didn't block" );

my $socket = $c->getinfo( CURLINFO_LASTSOCKET );
ok( $socket > 2, "open socket" );

my $vec = '';
vec( $vec, $socket, 1 ) = 1;
my ($rout, $wout, $eout);

my $cnt;
$cnt = select undef, $wout = $vec, $eout = $vec, 1;
ok( $cnt, "ready to write" );

my $tosend = "GET / HTTP/1.1\r\nHost: $host\r\n\r\n";
my $sent = $c->send( $tosend );

ok( length $tosend == $sent, "sent all data at once" );

$cnt = select $rout = $vec, undef, $eout = $vec, 2;
ok( $cnt, "ready to read" );

my ($buffer, $code);

$code = $c->recv( $buffer, 10240 );
ok( $code == CURLE_OK, "received data" );

$code = $c->recv( $buffer, 10240 );
ok( $code == CURLE_AGAIN, "no more data to read" );

