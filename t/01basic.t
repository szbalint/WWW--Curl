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
ok(! $curl->setopt(CURLOPT_ENCODING, undef), "Setting CURLOPT_ENCODING to undef");
ok(! $curl->setopt(CURLOPT_RESUME_FROM_LARGE, 0), "Setting CURLOPT_RESUME_FROM_LARGE to 0");
$curl->setopt(CURLOPT_HEADER, 1);

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEDATA,$body), "Setting CURLOPT_WRITEDATA");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my @myheaders;
$myheaders[0] = "Server: www";
$myheaders[1] = "User-Agent: Perl interface for libcURL";
ok(! $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders), "Setting CURLOPT_HTTPHEADER");
ok(! $curl->pushopt(CURLOPT_HTTPHEADER, ["Random: header"]));

$curl->setopt(CURLOPT_COOKIEFILE, "");
my $retcode = $curl->perform();

ok(! $retcode, "Curl return code ok");
diag("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n") if ($retcode);
my $bytes = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
ok( $bytes, "getinfo returns non-zero number of bytes");
my $realurl = $curl->getinfo(CURLINFO_EFFECTIVE_URL);
ok( $realurl, "getinfo returns CURLINFO_EFFECTIVE_URL");
my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
ok( $httpcode, "getinfo returns CURLINFO_HTTP_CODE");

SKIP: {
    skip "Only testing cookies against google.com", 2 unless $url eq "http://www.google.com";
    my $cookielist_const = $curl->const_string("CURLINFO_COOKIELIST");
    skip "libcurl doesn't have the CURLINFO_COOKIELIST constant", 2 unless $cookielist_const;
    my $cookies = $curl->getinfo($cookielist_const);
    is(ref $cookies, "ARRAY", "Returned array reference");
    ok(@$cookies > 0, "Got 1 or more cookies");
}

#diag ("Bytes: $bytes");
#diag ("realurl: $realurl");
#diag ("httpcode: $httpcode");
