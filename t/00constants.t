#!perl
use strict;
use warnings;
use Test::More;
use WWW::Curl::Easy;

my $ver_num_raw = WWW::Curl::Easy::version();
my ($ver_num) = $ver_num_raw =~ m!libcurl/(\d\.\d+\.\d+)!;
my ($major, $minor, $bugfix) = split(/\./, $ver_num);

open(my $fh, '<', 't/symbols-in-versions') or die($!);

my @consts;
for my $row (<$fh>) {
	chomp($row);
	next if ($row =~ m/^#/);
	my ($name, $intro, $dep, $remov) = split(/\s+/, $row);
	push @consts, [$name, $intro, $dep, $remov];
}

# In case we can't use cpp to extract symbols, skipping the multi constant tests for now.
my $skip_multi;
my $value = WWW::Curl::Easy::constant('CURL_LAST');
$skip_multi++ if (! $!);

my @checklist;
for my $row (@consts) {
	my ($name, $intro, $depr, $outro) = @{$row};
	my $check = 0;
	if (!$outro && $intro) {
		my ($maj_in, $min_in, $bf_in) = split(/\./, $intro);
		if ($maj_in eq '-' || $major > $maj_in) {
			$check = 1;	
		} elsif ($major == $maj_in) {
			if ($minor > $min_in) { $check = 1
			} elsif ($minor == $min_in ) {
				if ($bugfix > $bf_in) {
					$check = 1;
				} elsif ($bugfix == $bf_in) {
					$check = 1;
				} else {
					next
				}
			} else {
				next;
			}
		} else {
			next;
		}
	}
	if ($check) {
		next if ($skip_multi && $name =~ m/^CURLM/);
		push @checklist, [$name, $depr];
	}
}
plan tests => scalar(@checklist);
for my $row (@checklist) {
		my $value = WWW::Curl::Easy::constant($row->[0]);
		ok(!$! && (defined($value) || $row->[1]), "$row->[0] is defined alright - $!");
}
