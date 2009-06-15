#!perl

use Test::More skip_all => "Not performing POST";

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
use strict;

END {print "not ok 1\n" unless $::loaded;}
use WWW::Curl::Easy;

$::loaded = 1;

######################### End of black magic.

my $count=0;

use ExtUtils::MakeMaker qw(prompt);

# Read URL to get, defaulting to environment variable if supplied
my $defurl=$ENV{CURL_TEST_URL} || "http://www.google.com/";
my $url = prompt("# Please enter an URL to fetch",$defurl);
if (!$url) {
    print "1..0 # No test URL supplied - skipping test\n";
    exit;
}
print "1..6\n";
print "ok ".++$count."\n";

# Init the curl session
my $curl = WWW::Curl::Easy->new();
if ($curl == 0) {
    print "not ";
}
print "ok ".++$count."\n";

$curl->setopt(CURLOPT_NOPROGRESS, 1);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
$curl->setopt(CURLOPT_TIMEOUT, 30);

open HEAD, ">head.out";
$curl->setopt(CURLOPT_WRITEHEADER, *HEAD);
print "ok ".++$count."\n";

open BODY, ">body.out";
$curl->setopt(CURLOPT_FILE,*BODY);
print "ok ".++$count."\n";

$curl->setopt(CURLOPT_URL, $url);

print "ok ".++$count."\n";

my $read_max=1000;

sub read_callb
{
    my ($maxlen,$sv)=@_;
#    print STDERR "\nperl read_callback has been called!\n";
#    print STDERR "max data size: $maxlen - need $read_max bytes\n";
	if ($read_max > 0) {
		my $len=int($read_max/3)+1;
		my $data = chr(ord('A')+rand(26))x$len;
#		print STDERR "generated max/3=", int($read_max/3)+1, " characters to be uploaded - $data.\n";
		$read_max=$read_max-length($data);
		return $data;
	} else {
		return "";
	}
}  

#
# test post/read callback functions - requires a url which accepts posts, or it fails!
#

$curl->setopt(CURLOPT_READFUNCTION,\&read_callb);
$curl->setopt(CURLOPT_INFILESIZE,$read_max );
$curl->setopt(CURLOPT_UPLOAD,1 );
$curl->setopt(CURLOPT_CUSTOMREQUEST,"POST" );
                                                       
if ($curl->perform() != 0) {
	print "not ";
};
print "ok ".++$count."\n";
