#!perl

use strict;
use warnings;
use Test::More tests => 7;
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
$curl->setopt(CURLOPT_WRITEHEADER, $head);

my $body = tempfile();
$curl->setopt(CURLOPT_FILE,$body);

$curl->setopt(CURLOPT_URL, $url);

my $header_called = 0;
sub header_callback { $header_called = 1; return length($_[0]) };
my $body_called = 0;
sub body_callback { $body_called++;return length($_[0]) };



ok (! $curl->setopt(CURLOPT_HEADERFUNCTION, \&header_callback), "CURLOPT_HEADERFUNCTION set");
ok (! $curl->setopt(CURLOPT_WRITEFUNCTION, \&body_callback), "CURLOPT_WRITEFUNCTION set");

$curl->perform();
ok($header_called, "CURLOPT_HEADERFUNCTION callback was used");
ok($body_called, "CURLOPT_WRITEFUNCTION callback was used");
