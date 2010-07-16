#!perl -w
use strict;
use Test::More tests => 4;

use WWW::Curl::Easy;
use WWW::Curl::Share;
use WWW::Curl::Multi;
use WWW::Curl::Form;

eval { WWW::Curl::Easy->no_such_method0 };
like $@, qr/\b no_such_method0 \b/xms;

eval { WWW::Curl::Share->no_such_method1 };
like $@, qr/\b no_such_method1 \b/xms;

eval { WWW::Curl::Multi->no_such_method2 };
like $@, qr/\b no_such_method2 \b/xms;

eval { WWW::Curl::Form->no_such_method3 };
like $@, qr/\b no_such_method3 \b/xms;
