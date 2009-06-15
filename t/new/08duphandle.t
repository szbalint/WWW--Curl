use strict;
use Test::More tests => 1;
use WWW::Curl::Easy;

SKIP: {
    skip 'You need to set CURL_TEST_URL', 1 unless $ENV{CURL_TEST_URL};
    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL, $ENV{CURL_TEST_URL} );
    my @headers = ( 'Server: cURL', 'User-Agent: WWW::Curl/3.00' );
    $curl->setopt( CURLOPT_HTTPHEADER, \@headers );
    my $curl2 = $curl->duphandle;
    my $code  = $curl2->perform;
    ok( $code == 0 );
}
