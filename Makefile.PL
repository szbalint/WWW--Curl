use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::Config;
use ExtUtils::Constant 0.11 'WriteConstants';

my $minimum_libcurl_ver = 0x070a08;

my ( $curl_d, $cflags, $libs ) = ('', '', '');

if ( $^O eq 'MSWin32' ) {
	print	"Sorry, no automated install is available on Windows,\n".
		"please see the README.Win32 file on instructions for a manual install.\n";
	exit 0;
} else {
	( $curl_d, $cflags, $libs ) = get_curl_config();
}


my $constant_names = get_constants(
	$curl_d . "/curl/curl.h",
	-f $curl_d . "/curl/multi.h" ? $curl_d . "/curl/multi.h" : ()
);

{
	my $cn = scalar @$constant_names;
	print "-> found $cn constants\n";
	# there are 622 constants in libcurl 7.21.4
	die "Found only $cn constants, there should be at least 500\n"
		if $cn < 500;
}
my @constant_types = divide_constants();

write_from_template( "Easy", $constant_types[ 0 ] );
write_from_template( "Share", $constant_types[ 1 ] );
write_from_template( "Form", $constant_types[ 2 ] );
#write_from_template( "Multi", $constant_types[ 3 ] );

WriteMakefile(
	NAME 		=> 'WWW::Curl',
	VERSION_FROM	=> 'lib/WWW/Curl.pm',
	ABSTRACT_FROM	=> 'lib/WWW/Curl.pm',
	AUTHOR		=> 'Cris Bailiff <c.bailiff+curl at devsecure.com>',
	META_MERGE	=> {
		author	=> [
			'Balint Szilakszi <szbalint at cpan.org>',
		],
		resources => {
			repository => 'http://github.com/szbalint/WWW--Curl'
		},
	},
	CCFLAGS		=> $cflags,
	LIBS		=> $libs,
	SIGN		=> 1,
	LICENSE		=> 'MPL or MIT/X-derivate',	
	MIN_PERL_VERSION => 5.006001,
	clean		=> {
		FILES => 'const-c.inc const-xs.inc const-defenums.h'
	},
	realclean	=> {
		FILES => 'lib/WWW/Curl/Easy.pm lib/WWW/Curl/Form.pm lib/WWW/Curl/Share.pm'
	},
);

# WriteConstants does not honour enums, so we define those symbols
write_defenums( "const-defenums.h" );
WriteConstants(
	($] > 5.009002 ? (PROXYSUBS => 1) : ()),
	NAME => 'WWW::Curl',
	NAMES => $constant_names,
);

sub get_curl_config
{
	my $curl_config = $ENV{CURL_CONFIG} || 'curl-config';
	my %cc;
	foreach my $opt ( qw(vernum version prefix cflags libs) ) {
		my $ret = `${curl_config} --$opt`;
		chomp $ret;
		$cc{ $opt } = $ret;
		# print "${curl_config} --$opt: $ret\n";
	}

	print "Found libcurl version $cc{version}\n";
	
	if ( $cc{vernum} and hex( $cc{vernum} ) < $minimum_libcurl_ver) {
		print
			"Your currently installed libcurl version - $cc{version} - is too old.\n".
			"This module doesn't seek compatibility with versions older than 7.10.8\n".
			"Proceed manually if you know what you're doing.\n";
		exit 0;
	}

	my @incpath = (
		( defined $curl_d ? $curl_d : () ),
		( $cc{cflags} =~ /-I(\S+)/g ),
		( "$cc{prefix}/include" ),
		( split /\s+/, $Config{usrinc} ),
		( split /\s+/, $Config{locincpth} ),
		qw(
		/usr/include
		/usr/local/include
		/usr/local/curl/include
		/usr/local/include/curl
		)
	);

	my $curl_d;
	foreach my $inc ( @incpath ) {
		if ( -f $inc . "/curl/curl.h") {
			$curl_d = $inc;
			last;
		}
	}

	die "Cannot find curl.h - cannot build constants files  - see Makefile.PL"
		unless defined $curl_d;

	$cc{libs} ||= "-lcurl";
	return ( $curl_d, $cc{cflags}, $cc{libs} );
}

sub get_constants
{
	my %syms;
	foreach my $curl_h ( @_ ) {
		print "Reading $curl_h\n";
		open( H_IN, "-|", "$Config{cpprun} $curl_h" )
			or die "Cannot run $Config{cpprun} $curl_h: $@\n";
		while ( <H_IN> ) {
			if ( /enum\s+(\S+\s+)?{/ .. /}/ ) {
				s/^\s+//;
				next unless /^CURL/;
				chomp;
				s/[,\s].*//;
				s/=.*$//;
				next unless /^\w+$/;
				$syms{ $_ } = 1;
			}
		}
		close H_IN;

		open (H, "<", $curl_h)
			or die "Cannot open $curl_h: ".$!;
		while(<H>) {
			if (/^#define (CURL[A-Za-z0-9_]*)/) {
				$syms{ $1 } = 1;
			}
		}
		close H;
	}

	my @out;
	foreach my $e (sort keys %syms) {
		if($e =~ /(OBSOLETE|^CURL_EXTERN|_LAST\z|_LASTENTRY\z)/) {
			next;
		}
		push @out, $e;
	}

	return \@out;
}

sub divide_constants
{
	my @out = ( [], [], [] );

	foreach ( @$constant_names ) {
		my $list = 0;
		$list = 1 if /^(CURLSHOPT_|CURL_LOCK_)/;
		$list = 2 if /^CURLFORM_/;
		#$list = 3 if /^CURL_(POLL|CSELECT)_/;
		push @{ $out[ $list ] }, $_;
	}
	return @out;
}

sub write_from_template
{
	my $name = shift;
	my $constants = shift;

	print "Writing lib/WWW/Curl/$name.pm from template/$name.pm.tmpl\n";
	open my $fout, ">", "lib/WWW/Curl/$name.pm"
		or die "Can't create lib/WWW/Curl/$name.pm\n";

	open my $fin, "<", "template/$name.pm.tmpl"
		or die "Can't read template/$name.pm.tmpl\n";

	local $_;
	while (<$fin>) {
		if (m/^\s*\@CURLOPT_INCLUDE\@/) {
			print $fout join "\n", @$constants, '';
		} else {
			print $fout $_;
		}
	}
}

sub write_defenums
{
	my $out = shift;

	print "Writing $out\n";
	open my $o, ">", $out;
	foreach ( @$constant_names ) {
		print $o "#ifndef $_\n";
		print $o "# define $_ $_\n";
		print $o "#endif\n";
	}
	close $o;
}
