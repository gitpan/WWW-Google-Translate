#!/usr/bin/perl -Tw

use strict;
use warnings;
use lib qw( lib );
use Data::Dumper;
use WWW::Google::Translate;

my ( $key, $method, $source, $target, $q ) = ("") x 5;

ARG:
while ( my $arg = shift @ARGV ) {

    if ( $arg =~ m{\A --(translate|detect|languages) \z}xmsi ) {

        $method = lc $1;

        next ARG;
    }
    if ( $arg eq '--q' ) {

        while ( @ARGV && $ARGV[0] !~ m{\A -- }xms ) {

            $q .= shift @ARGV;
            $q .= ' ';
        }

        chomp $q;

        next ARG;
    }
    if ( $arg eq '--target' ) {

        if (@ARGV) {

            $target = shift @ARGV;
        }

        next ARG;
    }
    if ( $arg eq '--source' ) {

        if (@ARGV) {

            $source = shift @ARGV;
        }

        next ARG;
    }
    if ( $arg eq '--key' ) {

        if (@ARGV) {

            $key = shift @ARGV;
        }

        next ARG;
    }
}

my $gt = WWW::Google::Translate->new( {
        key            => $key,
        default_source => 'en',
        default_target => 'ja',
} );

my $r;

if ( $method eq 'translate' ) {

    $r = $gt->translate( { q => $q } );
}
elsif ( $method eq 'languages' ) {

    $r = $gt->languages( { target => $target } );
}
elsif ( $method eq 'detect' ) {

    $r = $gt->detect( { q => $q } );
}

print Dumper($r);

__END__
