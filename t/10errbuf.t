#!perl

use strict;
use warnings;
use Test::More tests => 14;
use File::Temp qw/tempfile/;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

# Init the curl session
my $curl = WWW::Curl::Easy->new();
ok($curl, 'Curl session initialize returns something');
ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module');

ok(! $curl->setopt(CURLOPT_VERBOSE, 1), "Setting CURLOPT_VERBOSE");
ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS");
ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION");
ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT");

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_FILE, $body), "Setting CURLOPT_FILE");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my ( $new_error, $tempname ) = tempfile();
ok(! $curl->setopt(CURLOPT_STDERR, $new_error), "Setting CURLOPT_STDERR");

# create a (hopefully) bad URL, so we get an error

ok(! $curl->setopt(CURLOPT_URL, "badprotocol://127.0.0.1:2"), "Setting CURLOPT_URL succeeds, even with a bad protocol");

my $retcode = $curl->perform();

ok($retcode, "Non-zero return code indicates the expected failure");

seek $new_error, 0, 0;
my $line = <$new_error>;
chomp $line;
ok( $line eq "* Protocol badprotocol not supported or disabled in libcurl", "Reading redirected STDERR" );

unlink $tempname;

exit;
