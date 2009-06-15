#!perl

use strict;
use warnings;
use Test::More tests => 19;
use File::Temp qw/tempfile/;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

# Init the curl session
my $curl = WWW::Curl::Easy->new();
ok($curl, 'Curl session initialize returns something');
ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module');

ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS");
ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION");
ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT");

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_FILE, $body), "Setting CURLOPT_FILE");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my @myheaders;
$myheaders[0] = "Server: www";
$myheaders[1] = "User-Agent: Perl interface for libcURL";
ok(! $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders), "Setting CURLOPT_HTTPHEADER");

my $retcode;
$retcode = $curl->perform();
ok(! $retcode,"Checking perform return code");

if ($retcode == 0) {
    my $bytes = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
    ok($bytes, "Non-zero bytesize check");
    my $realurl = $curl->getinfo(CURLINFO_EFFECTIVE_URL);
    ok($realurl, "URL definedness check");
    my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
    ok($httpcode, "HTTP status code check");
}

my $start = $curl->getinfo(CURLINFO_STARTTRANSFER_TIME);
ok ($start, "Valid transfer start time");
my $total = $curl->getinfo(CURLINFO_TOTAL_TIME);
ok ($total, "defined total transfer time");
my $dns = $curl->getinfo(CURLINFO_NAMELOOKUP_TIME);
ok ($dns, "NSLOOKUP time is defined");
my $conn = $curl->getinfo(CURLINFO_CONNECT_TIME);
ok ($conn, "Connect time defined");
my $pre = $curl->getinfo(CURLINFO_PRETRANSFER_TIME);
ok ($pre, "Pre-transfer time nonzero, defined");

exit;
