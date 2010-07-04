package WWW::Curl::Form;
use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD);

$VERSION = '4.12';

require WWW::Curl;
require Exporter;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(
CURLFORM_FILE
CURLFORM_COPYNAME
CURLFORM_CONTENTTYPE
);

sub AUTOLOAD {

    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    ( my $constname = $AUTOLOAD ) =~ s/.*:://;
    return constant( $constname, 0 );
}

1;

__END__

