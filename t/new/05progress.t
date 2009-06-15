use strict;
use Test::More tests => 3;
use WWW::Curl::Easy;

my ( $progress, $last );

sub progress_callback {
    my ( $clientp, $dltotal, $dlnow, $ultotal, $ulnow ) = @_;
    $last = $dlnow;
    $progress++;
    return 0;
}

SKIP: {
    skip 'You need to set CURL_TEST_URL', 3 unless $ENV{CURL_TEST_URL};
    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL,              $ENV{CURL_TEST_URL} );
    $curl->setopt( CURLOPT_NOPROGRESS,       1 );
    $curl->setopt( CURLOPT_NOPROGRESS,       0 );
    $curl->setopt( CURLOPT_PROGRESSFUNCTION, \&progress_callback );
    my $code = $curl->perform;
    ok( $code == 0 );
    ok($progress);
    ok($last);
}
