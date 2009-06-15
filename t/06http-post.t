#!perl

use strict;
use warnings;
use Test::More skip_all => "Not performing http POST/upload tests";
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

my $read_max=1000;

sub read_callb
{
    my ($maxlen,$sv)=@_;
	if ($read_max > 0) {
		my $len=int($read_max/3)+1;
		my $data = chr(ord('A')+rand(26))x$len;
		$read_max=$read_max-length($data);
		return $data;
	} else {
		return "";
	}
}  

#
# XXX - Outdated POST mechanism!
#

ok(! $curl->setopt(CURLOPT_READFUNCTION,\&read_callb), "Setting CURLOPT_READFUNCTION");
ok(! $curl->setopt(CURLOPT_INFILESIZE,$read_max ), "Setting CURLOPT_INFILESIZE");
ok(! $curl->setopt(CURLOPT_UPLOAD,1 ), "Setting CURLOPT_UPLOAD");
ok(! $curl->setopt(CURLOPT_CUSTOMREQUEST,"POST" ), "Setting CURLOPT_CUSTOMREQUEST");
                                                       
ok(! $curl->perform(), "Performing perform");
