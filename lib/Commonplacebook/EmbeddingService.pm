# ABOUTME: Embedding generation service using sentence-transformers
# ABOUTME: Manages Python helper process for batch embedding generation

package Commonplacebook::EmbeddingService;

use 5.034;
use warnings;
use experimental qw(signatures try);
use JSON::PP;
use Encode qw(encode_utf8 decode_utf8);
use IPC::Open2;
use FindBin;
use File::Spec;

sub new ($class, %args) {
    my $self = {
        config => $args{config},
        model => 'all-MiniLM-L6-v2',
        dimension => 384,
        bin_dir => $args{bin_dir} // $FindBin::Bin,
        helper_pid => undef,
        helper_in => undef,
        helper_out => undef,
    };

    bless $self, $class;
    $self->_start_helper();
    return $self;
}

sub _start_helper ($self) {
    my $script = File::Spec->catfile($self->{bin_dir}, 'embed-batch.py');
    my $model = $self->{model};

    my ($helper_out, $helper_in);
    my $helper_pid = open2($helper_out, $helper_in, $script, $model);

    $self->{helper_pid} = $helper_pid;
    $self->{helper_in} = $helper_in;
    $self->{helper_out} = $helper_out;
}

sub _ensure_helper ($self) {
    return if $self->{helper_pid} && kill(0, $self->{helper_pid});
    $self->_start_helper();
}

sub get_embeddings_for_texts ($self, $texts, $input_type = 'document') {
    my @embeddings;
    return \@embeddings unless @$texts;

    $self->_ensure_helper();

    my @cleaned = map { $self->_clean_text($_) } @$texts;
    my $json = encode_json(\@cleaned);

    my $helper_in = $self->{helper_in};
    my $helper_out = $self->{helper_out};

    print $helper_in "$json\n";
    $helper_in->flush();

    my $response = <$helper_out>;

    try {
        my $result = decode_json($response);
        for my $emb (@$result) {
            push @embeddings, pack("f*", @$emb);
        }
    } catch ($e) {
        warn "Failed to parse batch embeddings: $e";
        push @embeddings, $self->_generate_default_embedding() for @$texts;
    }

    return \@embeddings;
}

sub _clean_text ($self, $text) {
    return "" unless defined $text;

    $text = decode_utf8(encode_utf8($text));
    $text =~ s/\x00//g;

    my $max_length = 8000;
    if (length($text) > $max_length) {
        $text = substr($text, 0, $max_length);
    }

    return $text;
}

sub _generate_default_embedding ($self) {
    my $dimension = $self->{dimension};
    return pack("f*", (0) x $dimension);
}

sub get_embedding_for_text ($self, $text, $input_type = 'document') {
    my $embeddings = $self->get_embeddings_for_texts([$text], $input_type);
    return $embeddings->[0];
}

sub dimension ($self) { $self->{dimension} }

sub DESTROY ($self) {
    return unless $self->{helper_pid};

    close $self->{helper_in} if $self->{helper_in};
    close $self->{helper_out} if $self->{helper_out};

    kill 'TERM', $self->{helper_pid};
    waitpid($self->{helper_pid}, 0);
    $? = 0;
}

1;
