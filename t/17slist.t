#!perl

use Test::More skip_all => "Not performing printenv cgi tests";

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
use strict;

use WWW::Curl::Easy;

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

# we need the real printenv cgi for these tests, so skip if
# our test URL is not a printenv variant (or test.cgi from
# mdk apache2). We basically need something which will echo
# back sent headers in the output
#


if ($url !~ m/printenv|test.cgi/) {
	print "1..0 # need a real 'printenv' cgi script for this test";
	exit;
}
print "1..5\n";


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
$curl->setopt(CURLOPT_WRITEHEADER, \*HEAD);
print "ok ".++$count."\n";


sub body_callback {
    my ($chunk,$handle)=@_;
    ${$handle}.=$chunk;
    return length($chunk); # OK
}
$curl->setopt(CURLOPT_WRITEFUNCTION, \&body_callback);

my $body="";
$curl->setopt(CURLOPT_FILE,\$body);
print "ok ".++$count."\n";

$curl->setopt(CURLOPT_URL, $url);

print "ok ".++$count."\n";
# Add some additional headers to the http-request:
# Check that the printenv script sends back FOO=bar somewhere
# This checks that all headers were sent.
my @myheaders;
$myheaders[0] = "Baz: xyzzy";
$myheaders[1] = "Foo: bar";
$curl->setopt(CURLOPT_HTTPHEADER, \@myheaders);
                                                                        
# Go get it
my $retcode=$curl->perform();
if ($retcode == 0) {
	if ($body !~ m/FOO\s*=\s*"?bar"?/) {            
		print "not ";
	}
} else {
   # We can acces the error message in $errbuf here
#    print STDERR "$retcode / ".$curl->errbuf."\n";
    print "not ";
}
print "ok ".++$count."\n";

exit;
