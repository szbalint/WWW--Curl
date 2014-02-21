# Makefile.PL for Perl module WWW::Curl
# Check out the README file for more information.

use inc::Module::Install;

name			'WWW-Curl';
abstract		'Perl extension interface for libcurl';
author			'Cris Bailiff <c.bailiff+curl at devsecure.com>';
license			'mit';
perl_version		'5.006001';
no_index		directory => 'template';
repository		'http://github.com/szbalint/WWW--Curl';
# This is a hack. If you have libcurl installed, just specify curl.h below
# and comment out this line.
if ($^O ne 'MSWin32') {
    if (!$ENV{CURL_CONFIG}) {
	    requires_external_bin	'curl-config';
    }
} else {
	print	"Sorry, no automated install is available on Windows,\n".
		"please see the README.Win32 file on instructions for a manual install.\n";
	exit(0);
}

my $curl_config = $ENV{CURL_CONFIG} || 'curl-config';

my $vernum = `${curl_config} --vernum`; chomp $vernum;
my $version = `${curl_config} --version`; chomp $version; 

my $minimum_ver = hex("070a08");

if ($vernum && hex($vernum) <= $minimum_ver) {
	print	"Your currently installed libcurl version - $version - is too old.\n".
		"This module doesn't seek compatibility with versions older than 7.10.8\n".
		"Proceed manually if you know what you're doing.\n";
	exit(0);
}

print "The version is $version\n";

my @includes = qw();
my ($cflags,$lflags, $ldflags) = ('','','');

# You may need to specify where to find curl.h on your platform
# These are guesses only, in case curl-config is not telling us.

if ($^O ne 'MSWin32') {
	push @includes, qw(
		/usr/include
		/usr/local/curl/include
		/usr/local/include/curl
		../../include
		../curl/include
	);
}

#
# Get curl to tell us where it is, if we can.
#

if ($^O ne 'MSWin32') {
	$cflags = `${curl_config} --cflags`;
	$lflags = `${curl_config} --libs`;
}

# can't find link flags, make some guesses
if (!defined($lflags)) {
    $lflags="-lcurl";
    print "Guessing your linker flags as: $lflags\n";
}

my ($flag) = ($cflags =~ m/-I(\S+)/);

if (defined $flag) {
    unshift @includes, $flag;    # first guess
}

# try the path given on the command line, if any
if (defined($ARGV[0])) {
    unshift @includes, $ARGV[0];
};

my $curl_d = "";
my $curl_h;

# otherwise try a list of common locations
foreach my $try (@includes) {
    if (-f $try . "/curl/curl.h") {
        $curl_d = $try;
        $curl_h = $try . "/curl/curl.h";
        last;
    }
}

if (!defined($curl_h)) {
     die "Cannot find curl.h - cannot build constants files  - see Makefile.PL";
} else {
     my %constants;
     $curl_d = "-I" . $curl_d;
     print "Found curl.h in $curl_h\n";
     my @syms;
     my $has_cpp = 0;
     open(H_IN, "-|", "cpp", $curl_h) and $has_cpp++;
     unless ($has_cpp) {
         warn "No working cpp ($!).  Parsing curl.h in Perl";
         open(H_IN, "<", $curl_h) or die("Can't open curl.h at path $curl_h, because: ".$!);
     }
     while ( <H_IN> ) {
         if ( /enum\s+(\S+\s+)?{/ .. /}/ ) {
             s/^\s+//;
             next unless /^CURL/;
             chomp;
             s/^(CURL[A-Za-z0-9_]*_) ([A-Za-z0-9_])/$1$2/;  # Strip intervening space from ISO CPP macro
             s/[,\s].*//;
             s/=.*$//;
             next unless /^\w+$/;
             push @syms, $_;
         }
    }
    close H_IN;
    open (H, "<", $curl_h) or die ("Cannot open $curl_h: ".$!);
    while(<H>) {
        if (/^#define (CURL[A-Za-z0-9_]*)/) {
            push @syms, $1;
        }
    }
    close H;

    for my $e (sort @syms) {
       if($e =~ /(OBSOLETE|^CURL_EXTERN|_LAST\z|_LASTENTRY\z)/) {
          next;
       }
       my ($group) = $e =~ m/^([^_]+_)/;
       $constants{$group}->{$e} = $e;
    }
    unless ($has_cpp) {
    open(CURL_H, "<" . $curl_h) or die "Can't open curl.h\n";
    while (<CURL_H>) {
        if ($_ =~ m/CINIT\(/ and $_ !~ m/#/) {
            my ($option, $type, $code) = m/.*CINIT\((\w*)\s*,\s*(\w+)\s*,\s*(\d+).*/;
	    $constants{"CURLOPT_"}->{"CURLOPT_".$option} = "CURLOPT_".$option;
	} elsif ($_ =~ m/^#define CURLOPT_\w+\s+CURLOPT_\w+/) {
            my ($option, $value) =
                m/^#define CURLOPT_(\w+)\s+CURLOPT_(\w+)/;
	    $constants{"CURLOPT_"}->{"CURLOPT_".$option} = "CURLOPT_".$value;
        } elsif ($_ =~ m/^\s*((CURLINFO_|CURLSHOPT_|CURLE_)\w+)/) {
	    $constants{$2}->{$1}= $1;
        } elsif ($_ =~ m/^\s*((CURL_)(?:\w+))(?:[,\s]*)(?:\/\*.*)?$/) {
	    $constants{$2}->{$1} = $1;
        } elsif ($_ =~ m/^\s*((CURLPROXY_)(?:\w+))\s*=\s*\d+/) {
            $constants{$2}->{$1} = $1;
        } elsif ($_ =~ m/CFINIT\(/ and $_ !~ m/#/) {
            my ($option) = m/.*CFINIT\((\w*)\s*.*/;
	    $constants{"CURLFORM_"}->{"CURLFORM_".$option} = "CURLFORM_".$option;
        }
    }
    close(CURL_H);
    }
    print "Building curlopt-constants.c for your libcurl version\n";

    open(CURL_XS, ">curlopt-constants.c")
        or die "Can't write curlopt-constants.c\n";

    # boilerplate xs constant function here
    print CURL_XS <<HERE
static int
constant(const char *name)
{
    errno = 0;
HERE
        ;
for my $group (reverse sort keys %constants) {
	my $grouplength = length($group);
	my $groupref = $constants{$group};
	my @constants = keys %{$constants{$group}};
	print CURL_XS <<HERE2

    if (strncmp(name, "$group", $grouplength) == 0) {
        name += $grouplength;
        switch (*name) {
HERE2
        ;

    for my $next_initial ('A' .. 'Z') {
        print CURL_XS "        case '$next_initial':\n";
        my $count = 0;
        foreach my $option (sort @constants) {
            my $remainder = substr($option, length($group), length($option));
            my $initial = substr($remainder, 0, 1);
            if ($next_initial eq $initial) {

                print CURL_XS
"            if (strEQ(name, \"$remainder\")) return "."$groupref->{$option};\n";

                $count++;
            }
        }
        if ($count or $next_initial eq 'Z') {
            print CURL_XS "            break;\n";
        }
    }

    print CURL_XS "    };\n";
    print CURL_XS "    }\n";
}

    print CURL_XS <<HERE

    errno = EINVAL;
    return 0;
}
HERE
        ;

    close(CURL_XS);

    print "Building Easy.pm constants for your libcurl version\n";

    open(EASY_PM,    ">lib/WWW/Curl/Easy.pm")    or die "Can't create lib/WWW/Curl/Easy.pm\n";
    open(EASY_PM_IN, "template/Easy.pm.tmpl") or die "Can't read template/Easy.pm.tmpl\n";
    while (my $line = <EASY_PM_IN>) {
        if ($line !~ m/^\@CURLOPT_INCLUDE\@/) {
			print EASY_PM $line;
        } else {
	for my $group (reverse sort keys %constants) {	
            for my $option (sort keys %{$constants{$group}}) {
                next unless $option;
                print EASY_PM $option."\n";
            }
        }
	}
    }
    close(EASY_PM);
    close(EASY_PM_IN);

	print "Building Share.pm constants for your libcurl version\n";

    open(SHARE_PM,   ">lib/WWW/Curl/Share.pm")    or die "Can't create lib/WWW/Curl/Share.pm\n";
    open(SHARE_PM_IN, "template/Share.pm.tmpl") or die "Can't read template/Share.pm.tmpl\n";
    while (my $line = <SHARE_PM_IN>) {
        if ($line !~ m/^(.*?)\@CURLSHOPT_INCLUDE\@/) {
            print SHARE_PM $line;
        } else {
            foreach my $option (sort keys %{$constants{CURLSHOPT_}}) {
                print SHARE_PM $1 . $option . "\n";
            }
            foreach my $option (sort keys %{$constants{CURL_LOCK_}}) {
                print SHARE_PM $1 . $option . "\n";
            }
        }
    }
    close(SHARE_PM);
    close(SHARE_PM_IN);
}

# Let Module::Install generate META.yml and other necessary files.
WriteMakefile(
    'NAME'         => 'WWW::Curl',
    'VERSION_FROM' => 'lib/WWW/Curl.pm',      # finds $VERSION
    'LIBS'         => "$ldflags $lflags",        # e.g., '-lm'
    'INC'          => $curl_d,        # e.g., '-I/usr/include/other'
    'clean' => { FILES => "curlopt-constants.c head.out body.out" }
);

