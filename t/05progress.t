#!perl

use strict;
use warnings;
use Test::More tests => 16;
use File::Temp qw/tempfile/;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

# Init the curl session
my $curl = WWW::Curl::Easy->new();
ok($curl, 'Curl session initialize returns something');
ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module');

ok(! $curl->setopt(CURLOPT_NOPROGRESS, 0), "Setting CURLOPT_NOPROGRESS");
ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION");
ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT");

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_FILE,$body), "Setting CURLOPT_FILE");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my @myheaders;
$myheaders[0] = "Server: www";
$myheaders[1] = "User-Agent: Perl interface for libcURL";
ok(! $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders), "Setting CURLOPT_HTTPHEADER");

ok(! $curl->setopt(CURLOPT_PROGRESSDATA,"making progress!"), "Setting CURLOPT_PROGRESSDATA");

my $progress_called = 0;
my $last_dlnow = 0;
sub prog_callb
{
    my ($clientp,$dltotal,$dlnow,$ultotal,$ulnow)=@_;
    $last_dlnow=$dlnow;
    $progress_called++;
    return 0;
}                        

ok (! $curl->setopt(CURLOPT_PROGRESSFUNCTION, \&prog_callb), "Setting CURLOPT_PROGRESSFUNCTION");

ok (! $curl->setopt(CURLOPT_NOPROGRESS, 0), "Turning progress meter back on");

ok (! $curl->perform(), "Performing perform");

ok ($progress_called, "Progress callback called");

ok ($last_dlnow, "Last downloaded chunk non-zero");
