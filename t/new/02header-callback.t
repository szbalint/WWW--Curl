use strict;
use Test::More tests => 1;
use WWW::Curl::Easy;

my $header;

sub header_callback {
    my $chunk = shift;
    $header .= $chunk;
    return length $chunk;
}

SKIP: {
    skip 'You need to set CURL_TEST_URL', 1 unless $ENV{CURL_TEST_URL};
    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL,            $ENV{CURL_TEST_URL} );
    $curl->setopt( CURLOPT_HEADERFUNCTION, \&header_callback );
    $curl->perform;
    ok($header);
}
