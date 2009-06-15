#!perl

use strict;
use warnings;
use lib 'inc';
use lib 'blib/lib';
use lib 'blib/arch';
use Test::More tests => 25;
use File::Temp qw/tempfile/;
use WWW::Curl::Easy;

my $url = $ENV{CURL_TEST_URL} || "http://www.google.com";
my $other_handle;
my $head = tempfile();
my $hcall;
my $body_called = 0;
my $head_called = 0;
{
	# Init the curl session
	my $curl = WWW::Curl::Easy->new();
	ok($curl, 'Curl session initialize returns something'); #1
	ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module'); #2

	ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS"); #3
	ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION"); #4
	ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT"); #5

	ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER"); #6

	my $body = tempfile();
	ok(! $curl->setopt(CURLOPT_FILE, $body), "Setting CURLOPT_FILE"); #7


	my @myheaders;
	$myheaders[0] = "Server: www";
	$myheaders[1] = "User-Agent: Perl interface for libcURL";
	ok(! $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders), "Setting CURLOPT_HTTPHEADER"); #8


	sub body_callback {
    		my ($chunk,$handle)=@_;
    		$body_called++;
    		return length($chunk); # OK
	}

	sub head_callback {
		my ($chunk,$handle)=@_;
		$head_called++;
		return length($chunk); # OK
	}

	$hcall = \&head_callback;
	ok(! $curl->setopt(CURLOPT_WRITEFUNCTION, \&body_callback), "Setting CURLOPT_WRITEFUNCTION callback"); #9
	ok(! $curl->setopt(CURLOPT_HEADERFUNCTION, $hcall), "Setting CURLOPT_HEADERFUNCTION callback"); #10

	ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL"); #11

	# duplicate the handle
	$other_handle = $curl->duphandle();
	ok($other_handle, 'duphandle seems to return something'); #12
	ok(ref($other_handle) eq 'WWW::Curl::Easy', 'Dup handle looks like an object from the WWW::Curl::Easy module'); #13

	foreach my $x ($curl,$other_handle) {
		my $retcode=$x->perform();
		ok(!$retcode, "Handle return code check"); #14-15
		if ($retcode == 0) {
			my $bytes	= $x->getinfo(CURLINFO_SIZE_DOWNLOAD);
			my $realurl	= $x->getinfo(CURLINFO_EFFECTIVE_URL);
			my $httpcode	= $x->getinfo(CURLINFO_HTTP_CODE);
		}
	}
	ok( $head_called >= 2, "Header callback seems to have worked"); #16
	ok( $body_called >= 2, "Body callback seems to have worked"); #17
}

ok(! $other_handle->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL"); #18

my $retcode=$other_handle->perform();
ok(!$retcode, "Handle return code check");
ok( 1, "We survive DESTROY time for the original handle");
ok( head_callback('1',undef), "We can still access the callbacks");
my $third = $other_handle->duphandle();
ok($third, 'duphandle seems to return something again');
ok(ref($third) eq 'WWW::Curl::Easy', 'Dup handle looks like an object from the WWW::Curl::Easy module');

foreach my $x ($other_handle,$third) {
	my $retcode=$x->perform();
	ok(!$retcode, "Handle return code check");
	if ($retcode == 0) {
		my $bytes	= $x->getinfo(CURLINFO_SIZE_DOWNLOAD);
		my $realurl	= $x->getinfo(CURLINFO_EFFECTIVE_URL);
		my $httpcode	= $x->getinfo(CURLINFO_HTTP_CODE);
	}
}
