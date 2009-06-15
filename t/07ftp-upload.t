#!perl

use strict;
use warnings;
use Test::More skip_all => "Not performing ftp upload tests";

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

my $count=1;


# Read URL to get, defaulting to environment variable if supplied
my $url=$ENV{CURL_TEST_URL_FTP} || "";
if (!$url) {
    print "1..0 # No test ftp URL supplied - skipping test\n";
    exit;
}

print "1..8\n"; 

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

open BODY, ">body.out";
$curl->setopt(CURLOPT_FILE, \*body);
print "ok ".++$count."\n";

$curl->setopt(CURLOPT_URL, $url);

print "ok ".++$count."\n";

# Now do an ftp upload:

$curl->setopt(CURLOPT_UPLOAD, 1);


my $read_max=1000;
$curl->setopt(CURLOPT_INFILESIZE,$read_max );   
print "ok ".++$count."\n";
 
sub read_callb
{
    my ($maxlen,$sv)=@_;
    print "# perl read_callback has been called!\n";
    print "# max data size: $maxlen - $read_max bytes needed\n";

	if ($read_max > 0) {
                my $len=int($read_max/3)+1;
                my $data = chr(ord('A')+rand(26))x$len;
                print "# generated max/3=", int($read_max/3)+1, " characters to be uploaded - $data.\n";
                $read_max=$read_max-length($data);
                return $data;
        } else {
                return "";
        }
}
               
# Use perl read callback to read data to be uploaded
$curl->setopt(CURLOPT_READFUNCTION, \&read_callb);

# Use perl passwd callback to read password for login to ftp server
$curl->setopt(CURLOPT_USERPWD, "ftp\@");

print "ok ".++$count."\n";

# Go get it
my $code;
if (($code=$curl->perform()) == 0) {
    my $bytes=$curl->getinfo(CURLINFO_SIZE_UPLOAD);
    print "ok ".++$count." $bytes bytes transferred\n";
} else {
    # We can acces the error message in $errbuf here
    print "not ok ".++$count." ftpcode= $code, errbuf=".$curl->errbuf."\n";
}
