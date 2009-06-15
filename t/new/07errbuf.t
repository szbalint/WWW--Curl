use strict;
use Test::Simple tests => 1;
use WWW::Curl::Easy;

my $curl = new WWW::Curl::Easy;
$curl->setopt( CURLOPT_URL, 'badprotocol://127.0.0.1:2' );
$curl->perform;
my $err = $curl->errbuf;
ok($err);
