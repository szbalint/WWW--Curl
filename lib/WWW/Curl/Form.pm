package WWW::Curl::Form;
use strict;
use warnings;
use Carp;

our $VERSION = '4.12';

use WWW::Curl ();
use Exporter  ();

our @ISA = qw(Exporter);

our @EXPORT = qw(
CURLFORM_FILE
CURLFORM_COPYNAME
CURLFORM_CONTENTTYPE
);

sub AUTOLOAD {
    our $AUTOLOAD;
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    ( my $constname = $AUTOLOAD ) =~ s/.*:://;
    my $value = constant( $constname, 0 );
    if($!) {
        croak("Undefined subroutine &$AUTOLOAD caclled");
    }
    return $value;
}

1;

__END__

