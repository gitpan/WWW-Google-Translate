package WWW::Google::Translate;

our $VERSION = '0.05';

use strict;
use warnings;
{
    use Carp;
    use URI;
    use JSON qw( from_json );
    use LWP::UserAgent;
    use HTTP::Status qw( HTTP_BAD_REQUEST );
    use Readonly;
    use English qw( -no_match_vars $EVAL_ERROR );
}

my ( $REST_HOST, $REST_URL, $CONSOLE_URL, %SIZE_LIMIT_FOR );
{
    Readonly $REST_HOST      => 'www.googleapis.com';
    Readonly $REST_URL       => "https://$REST_HOST/language/translate/v2";
    Readonly $CONSOLE_URL    => "https://code.google.com/apis/console";
    Readonly %SIZE_LIMIT_FOR => (
        translate => 2000,    # google states 2K but observed results vary
        detect    => 2000,
        languages => 9999,    # N/A
    );
}

sub new {
    my ( $class, $param_rh ) = @_;

    my %self = (
        key              => 0,
        default_source   => 0,
        default_target   => 0,
        data_format      => 'perl',
        timeout          => 60,
        force_post       => 0,
        rest_url         => $REST_URL,
        agent            => ( sprintf '%s/%s', __PACKAGE__, $VERSION ),
    );

    for my $property ( keys %self ) {

        if ( exists $param_rh->{$property} ) {

            $self{$property} = delete $param_rh->{$property};
        }
    }

    for my $property ( keys %{$param_rh} ) {

        carp "$property is not a supported parameter";
    }

    for my $default (qw( default_source default_target )) {

        if ( !$self{$default} ) {

            delete $self{$default};
        }
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

        my @unsupported
            = grep { $_ ne 'q' && $_ ne 'source' && $_ ne 'target' }
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

    my $url
        = $operation eq 'translate'
        ? $self->{rest_url}
        : $self->{rest_url} . "/$operation";

    my $force_post = $self->{force_post};

    my %form = (
        key => $self->{key},
        %{$arg_rh},
    );

    if ( exists $arg_rh->{source} && !$arg_rh->{source} ) {

        delete $form{source};
        delete $arg_rh->{source};
    }

    my $byte_size = exists $form{q} ? length $form{q} : 0;
    my $get_size_limit = $SIZE_LIMIT_FOR{$operation};

    my ( $method, $response );

    if ( $force_post || $byte_size > $get_size_limit ) {

        $method = 'POST';

        $response = $self->{ua}->post(
            $url,
            'X-HTTP-Method-Override' => 'GET',
            'Content'                => \%form
        );
    }
    else {

        $method = 'GET';

        my $uri = URI->new($url);

        $uri->query_form( \%form );

        $response = $self->{ua}->get($uri);
    }

    if ( $response->code() == HTTP_BAD_REQUEST ) {

        my $dump = join ",\n", map {"$_ => $arg_rh->{$_}"} keys %{$arg_rh};

        warn "request failed: $dump\n";

        require Sys::Hostname;

        my $host = Sys::Hostname::hostname() || 'this machine';
        $host = uc $host;

        die "unsuccessful $operation $method for $byte_size bytes: ",
            $response->status_line(),
            "\n",
            "check that $host is has API Access for this API key",
            "\n",
            "at $CONSOLE_URL\n";
    }
    elsif ( !$response->is_success() ) {

        croak "unsuccessful $operation $method for $byte_size bytes: ",
            $response->status_line(), "\n";
    }

    my $json = $response->content() || "";
    my $cache_control = $response->header('Cache-Control') || "";

    return $json
        if 'json' eq lc $self->{data_format};

    $json =~ s{ NaN }{-1}xmsg;    # prevent from_json failure

    my $trans_rh;

    eval { $trans_rh = from_json( $json, { utf8 => 1 } ); };

    if ($EVAL_ERROR) {
        warn "$json\n$EVAL_ERROR";
        return $json;
    }

    return $trans_rh;
}

1;
