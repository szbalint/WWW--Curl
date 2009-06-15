use strict;
use Test::More tests => 1;
use WWW::Curl::Easy;

my $max = 1000;

sub read_callback {
    my ( $maxlen, $sv ) = @_;

    # Create some random data
    my $data = chr( ord('A') + rand(26) ) x ( int( $max / 3 ) + 1 );
    $max = $max - length $data;
    return $data;
}

SKIP: {
    skip 'You need to set CURL_TEST_URL', 1 unless $ENV{CURL_TEST_URL};
    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL,           $ENV{CURL_TEST_URL} );
    $curl->setopt( CURLOPT_READFUNCTION,  \&read_callback );
    $curl->setopt( CURLOPT_INFILESIZE,    $max );
    $curl->setopt( CURLOPT_UPLOAD,        1 );
    $curl->setopt( CURLOPT_CUSTOMREQUEST, 'POST' );
    my $code = $curl->perform;
    ok( $code == 0 );
}
