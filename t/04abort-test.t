#!perl

use strict;
use warnings;
use Test::More tests => 8;
use File::Temp qw/tempfile/;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

# Init the curl session
my $curl = WWW::Curl::Easy->new();
ok($curl, 'Curl session initialize returns something');
ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module');

$curl->setopt(CURLOPT_NOPROGRESS, 1);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
$curl->setopt(CURLOPT_TIMEOUT, 30);

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_FILE,$body), "Setting CURLOPT_FILE");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my $body_abort_called = 0;
sub body_abort_callback { $body_abort_called++; return -1 };

$curl->setopt(CURLOPT_WRITEFUNCTION, \&body_abort_callback);

ok( $curl->perform(), "Request fails, Abort succeeds");

ok( $body_abort_called, "Abort function was invoked");
