#!perl

use strict;
use warnings;

BEGIN {
  use Test::More;
  if(!eval 'require Test::Kwalitee; 1') {
      plan skip_all => "Test::Kwalitee required for this test";
      exit;
  } elsif ( ! $ENV{RELEASE_TESTING} ) {
      plan skip_all => 'these tests are for release candidate testing';
      exit;
  }
};

use Test::Kwalitee qw/ kwalitee_ok /;

kwalitee_ok();

done_testing();
