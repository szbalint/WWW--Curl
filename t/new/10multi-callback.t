use strict;
use Test::More tests => 4;
use WWW::Curl::Easy;
use WWW::Curl::Multi;

my ( $header, $body, $header2, $body2 );

sub header_callback {
    my $chunk = shift;
    $header .= $chunk;
    return length($chunk);
}

sub body_callback {
    my ( $chunk, $handle ) = @_;
    $body .= $chunk;
    return length($chunk);
}

sub header_callback2 {
    my $chunk = shift;
    $header2 .= $chunk;
    return length($chunk);
}

sub body_callback2 {
    my ( $chunk, $handle ) = @_;
    $body2 .= $chunk;
    return length($chunk);
}

SKIP: {
    skip 'You need to set CURL_TEST_URL', 4 unless $ENV{CURL_TEST_URL};

    my $curl = new WWW::Curl::Easy;
    $curl->setopt( CURLOPT_URL,            $ENV{CURL_TEST_URL} );
    $curl->setopt( CURLOPT_HEADERFUNCTION, \&header_callback );
    $curl->setopt( CURLOPT_WRITEFUNCTION,  \&body_callback );

    my $curl2 = new WWW::Curl::Easy;
    $curl2->setopt( CURLOPT_URL,            $ENV{CURL_TEST_URL} );
    $curl2->setopt( CURLOPT_HEADERFUNCTION, \&header_callback2 );
    $curl2->setopt( CURLOPT_WRITEFUNCTION,  \&body_callback2 );

    my $curlm = new WWW::Curl::Multi;
    $curlm->add_handle($curl);
    $curlm->add_handle($curl2);
    $curlm->perform;

    ok($header);
    ok($body);
    ok($header2);
    ok($body2);
}
