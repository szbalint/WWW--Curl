use strict;
use Test::More tests => 1;
use WWW::Curl::Easy;

my $body;

sub body_callback {
    my ( $chunk, $handle ) = @_;
    $body .= $chunk;
    return length $chunk;
}

SKIP: {
    skip 'You need to set CURL_TEST_URL', 1 unless $ENV{CURL_TEST_URL};
    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL,           $ENV{CURL_TEST_URL} );
    $curl->setopt( CURLOPT_WRITEFUNCTION, \&body_callback );
    my $curl2 = $curl->duphandle;
    $curl2->perform;
    ok($body);
}
