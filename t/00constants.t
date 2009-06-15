#!perl
use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok( 'WWW::Curl::Easy' ); }

ok (CURLOPT_URL == 10000+2, "Constant loaded ok");
ok (CURLE_URL_MALFORMAT, "CURLE_ error constant can be used");
