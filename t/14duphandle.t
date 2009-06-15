#!perl

use strict;
use warnings;
use lib 'inc';
use lib 'blib/lib';
use lib 'blib/arch';
use Test::More tests => 17;
use File::Temp qw/tempfile/;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";

{
my $other_handle;
my $head = tempfile();
my $body = tempfile();

	{
		# Init the curl session
		my $curl = WWW::Curl::Easy->new();
		ok($curl, 'Curl session initialize returns something');
		ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module');

		ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS");
		ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION");
		ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT");

		ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER");

		ok(! $curl->setopt(CURLOPT_FILE, $body), "Setting CURLOPT_FILE");

		ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

		my @myheaders;
		$myheaders[0] = "Server: www";
		$myheaders[1] = "User-Agent: Perl interface for libcURL";
		ok(! $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders), "Setting CURLOPT_HTTPHEADER");

		# duplicate the handle
		$other_handle = $curl->duphandle();
		ok ($other_handle && ref($other_handle) eq 'WWW::Curl::Easy', "Duplicated handle seems to be an object in the right namespace");

		foreach my $x ($other_handle,$curl) {
			my $retcode = $x->perform();
			ok(!$retcode, "Perform returns without an error");
			if ($retcode == 0) {
				my $bytes	= $x->getinfo(CURLINFO_SIZE_DOWNLOAD);
				my $realurl	= $x->getinfo(CURLINFO_EFFECTIVE_URL);
				my $httpcode	= $x->getinfo(CURLINFO_HTTP_CODE);
			}
		}
	}

ok(1, "Survived original curl handle DESTROY");

ok(! $other_handle->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");
my $retcode = $other_handle->perform();
ok(!$retcode, "Perform returns without an error");
if ($retcode == 0) {
	my $bytes=$other_handle->getinfo(CURLINFO_SIZE_DOWNLOAD);
	my $realurl=$other_handle->getinfo(CURLINFO_EFFECTIVE_URL);
	my $httpcode=$other_handle->getinfo(CURLINFO_HTTP_CODE);
}



}
ok(1, "Survived dup curl handle DESTROY");
exit;
