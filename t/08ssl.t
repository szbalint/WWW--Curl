#!perl

use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use WWW::Curl::Easy;

# list of tests
#         site-url, verifypeer(0,1), verifyhost(0,2), result(0=ok, 1=fail), result-openssl0.9.5
my $url_list=[

        [ 'https://65.205.248.243/',  0, 0, 0 , 0 ], # www.thawte.com
#        [ 'https://65.205.248.243/',  0, 2, 1 , 1 ], # www.thawte.com
	[ 'https://65.205.249.60/',  0, 0, 0 , 0 ], # www.verisign.com
#	[ 'https://65.205.249.60/',  0, 2, 1 , 1 ], # www.verisign.com
	[ 'https://www.microsoft.com/', 0, 0, 0 , 0 ],
	[ 'https://www.microsoft.com/', 0, 0, 0 , 0 ],
	[ 'https://www.verisign.com/', 1, 2, 0 , 0 ], # verisign have had broken ssl - do this first
	[ 'https://www.verisign.com/', 0, 0, 0 , 0 ], 
	[ 'https://www.verisign.com/', 0, 0, 0 , 0 ],
	[ 'https://www.verisign.com/', 0, 2, 0 , 0 ],
        [ 'https://www.thawte.com/',  0, 0, 0 , 0 ],
        [ 'https://www.thawte.com/',  0, 2, 0 , 0 ],

# libcurl < 7.9.3 crashes with more than 5 ssl hosts per handle.

	[ 'https://www.rapidssl.com/',  0, 0, 0 , 0],
	[ 'https://www.rapidssl.com/',  0, 2, 0 , 0],
	[ 'https://www.rapidssl.com/',  1, 0, 1 , 0],
	[ 'https://www.rapidssl.com/',  1, 2, 1 , 0],
];


if (&WWW::Curl::Easy::version() !~ /ssl/i) {
	plan skip_all => 'libcurl was compiled without ssl support, skipping ssl tests';
} else {
	plan tests => scalar(@{$url_list})+7;
}

# Init the curl session
my $curl = WWW::Curl::Easy->new();
ok($curl, 'Curl session initialize returns something'); #1
ok(ref($curl) eq 'WWW::Curl::Easy', 'Curl session looks like an object from the WWW::Curl::Easy module'); #2

ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS"); #3
ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION"); #4
ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT"); #5

my $head = tempfile();
ok(! $curl->setopt(CURLOPT_WRITEHEADER, $head), "Setting CURLOPT_WRITEHEADER"); #6

my $body = tempfile();
ok(! $curl->setopt(CURLOPT_FILE, $body), "Setting CURLOPT_FILE"); #7

my @myheaders;
$myheaders[0] = "User-Agent: Verifying SSL functions in WWW::Curl perl interface for libcURL";
$curl->setopt(CURLOPT_HTTPHEADER, \@myheaders);

$curl->setopt(CURLOPT_FORBID_REUSE, 1);
$curl->setopt(CURLOPT_FRESH_CONNECT, 1);
#$curl->setopt(CURLOPT_SSL_CIPHER_LIST, "HIGH:MEDIUM");

$curl->setopt(CURLOPT_CAINFO,"ca-bundle.crt");                       
$curl->setopt(CURLOPT_DEBUGFUNCTION, \&silence);

sub silence { return 0 }

my $count = 1;

my $sslversion95 = 0;
$sslversion95++ if (&WWW::Curl::Easy::version() =~ m/SSL 0.9.5/); # 0.9.5 has buggy connect with some ssl sites

my $haveca = 0;
if (-f "ca-bundle.crt") { $haveca = 1; }

for my $test_list (@$url_list) {
    my ($url,$verifypeer,$verifyhost,$result,$result95)=@{$test_list};
    if ($verifypeer && !$haveca) { $result = 1 } # expect to fail if no ca-bundle file
    if ($sslversion95) { $result=$result95 }; # change expectation	
 

    $curl->setopt(CURLOPT_SSL_VERIFYPEER,$verifypeer); # do verify 
    $curl->setopt(CURLOPT_SSL_VERIFYHOST,$verifyhost); # check name
    my $retcode;

    $curl->setopt(CURLOPT_URL, $url);

    $retcode = $curl->perform();
    ok(($retcode != 0) == $result, "$url ssl test succeeds");
}

