package WWW::Google::Translate;

our $VERSION = '0.01';

use strict;
use warnings;
{
    use Carp;
    use URI;
    use JSON qw( from_json );
    use LWP::UserAgent;
    use Readonly;
}

my ( $REST_HOST, $REST_URL );
{
    Readonly $REST_HOST => 'www.googleapis.com';
    Readonly $REST_URL  => "https://$REST_HOST/language/translate/v2";
}

sub new {
    my ( $class, $param_rh ) = @_;

    my %self = (
        key            => 0,
        default_source => 'en',
        default_target => 'es',
        data_format    => 'perl',
        timeout        => 60,
        rest_url       => $REST_URL,
        agent          => ( sprintf '%s/%s', __PACKAGE__, $VERSION ),
    );

    for my $property ( keys %self ) {

        if ( exists $param_rh->{$property} ) {

            $self{$property} = delete $param_rh->{$property};
        }
    }

    for my $property ( keys %{$param_rh} ) {

        carp "$property is not a supported parameter";
    }

    croak "key is a required parameter"
        if !$self{key};

    croak "data_format must either be Perl or JSON"
        if $self{data_format} !~ m{\A (?: perl|json ) \z}xmsi;

    $self{ua} = LWP::UserAgent->new();
    $self{ua}->agent( delete $self{agent} );

    return bless \%self, $class;
}

sub translate {
    my ( $self, $arg_rh ) = @_;

    croak 'q is a required parameter'
        if !exists $arg_rh->{q};

    my $result;

    if ( $arg_rh->{q} ) {

        $arg_rh->{source} ||= $self->{default_source};
        $arg_rh->{target} ||= $self->{default_target};

        $self->{default_source} = $arg_rh->{source};
        $self->{default_target} = $arg_rh->{target};

        my @unsupported = grep { $_ ne 'q' && $_ ne 'source' && $_ ne 'target' }
            keys %{$arg_rh};

        croak "unsupported parameters: ", ( join ',', @unsupported )
            if @unsupported;

        $result = $self->_rest( 'translate', $arg_rh );
    }

    return $result;
}

sub languages {
    my ( $self, $arg_rh ) = @_;

    croak 'target is a required parameter'
        if !exists $arg_rh->{target};

    my $result;

    if ( $arg_rh->{target} ) {

        my @unsupported = grep { $_ ne 'target' } keys %{$arg_rh};

        croak "unsupported parameters: ", ( join ',', @unsupported )
            if @unsupported;

        $result = $self->_rest( 'languages', $arg_rh );
    }

    return $result;
}

sub detect {
    my ( $self, $arg_rh ) = @_;

    croak 'q is a required parameter'
        if !exists $arg_rh->{q};

    my $result;

    if ( $arg_rh->{q} ) {

        my @unsupported = grep { $_ ne 'q' } keys %{$arg_rh};

        croak "unsupported parameters: ", ( join ',', @unsupported )
            if @unsupported;

        $result = $self->_rest( 'detect', $arg_rh );
    }

    return $result;
}

sub _rest {
    my ( $self, $operation, $arg_rh ) = @_;

    my $url = $self->{rest_url};

    my $uri = URI->new( $operation eq 'translate' ? $url : "$url/$operation" );

    my %form = (
        key => $self->{key},
        %{$arg_rh},
    );
    $uri->query_form( \%form );

    my $response = $self->{ua}->get($uri);

    croak "unsuccessful $operation call: ", $response->status_line()
        if !$response->is_success();

    my $json = $response->content();

    return from_json($json)
        if 'perl' eq lc $self->{data_format};

    return $json;
}

1;
