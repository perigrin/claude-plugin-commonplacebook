#!/usr/bin/env perl
# ABOUTME: Test suite for Commonplacebook::EmbeddingService module
# ABOUTME: Validates embedding generation, batch processing, and helper lifecycle

use 5.034;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Spec;

# Test 1: Module loads
use_ok('Commonplacebook::Config') or BAIL_OUT("Cannot load Config");
use_ok('Commonplacebook::EmbeddingService') or BAIL_OUT("Cannot load EmbeddingService");

# Test 2: Constructor
my $config = Commonplacebook::Config->new();
my $bin_dir = File::Spec->catdir($FindBin::Bin, '..', 'bin');

my $service = Commonplacebook::EmbeddingService->new(
    config => $config,
    bin_dir => $bin_dir,
);
ok($service, "EmbeddingService created");
isa_ok($service, 'Commonplacebook::EmbeddingService');

# Test 3: Dimension accessor
is($service->dimension, 384, "dimension returns 384");

# Test 4: Single text embedding
SKIP: {
    # Check if Python helper is available
    my $helper = File::Spec->catfile($bin_dir, 'embed-batch.py');
    skip "embed-batch.py not found at $helper", 2 unless -f $helper;

    my $text = "This is a test sentence.";
    my $embedding = $service->get_embedding_for_text($text);

    ok(defined($embedding), "Embedding generated for single text");

    # Embedding should be packed binary data (4 bytes per float * 384 dimensions)
    is(length($embedding), 384 * 4, "Embedding has correct byte length");
}

# Test 5: Batch embeddings
SKIP: {
    my $helper = File::Spec->catfile($bin_dir, 'embed-batch.py');
    skip "embed-batch.py not found at $helper", 3 unless -f $helper;

    my @texts = (
        "First sentence.",
        "Second sentence.",
        "Third sentence.",
    );

    my $embeddings = $service->get_embeddings_for_texts(\@texts);

    is(scalar(@$embeddings), 3, "Got 3 embeddings for 3 texts");
    ok(defined($embeddings->[0]), "First embedding defined");
    is(length($embeddings->[0]), 384 * 4, "First embedding has correct length");
}

# Test 6: Empty text handling
SKIP: {
    my $helper = File::Spec->catfile($bin_dir, 'embed-batch.py');
    skip "embed-batch.py not found at $helper", 1 unless -f $helper;

    my $embeddings = $service->get_embeddings_for_texts([]);
    is(scalar(@$embeddings), 0, "Empty array returns empty embeddings");
}

# Test 7: Text cleaning (null bytes, length limits)
my $text_with_null = "Test\x00text";
my $cleaned = $service->_clean_text($text_with_null);
unlike($cleaned, qr/\x00/, "Null bytes removed from text");

my $long_text = "a" x 10000;
my $cleaned_long = $service->_clean_text($long_text);
is(length($cleaned_long), 8000, "Long text truncated to 8000 chars");

# Test 8: Default embedding generation (fallback)
my $default_emb = $service->_generate_default_embedding();
is(length($default_emb), 384 * 4, "Default embedding has correct length");

done_testing();
