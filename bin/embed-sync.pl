#!/usr/bin/env perl
# ABOUTME: Syncs embeddings for notes that need them in notebook.db
# ABOUTME: Finds new/modified notes, chunks text, generates local embeddings

use 5.034;
use warnings;
use experimental qw(signatures try);

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use Commonplacebook::Config;
use Commonplacebook::Database;
use Commonplacebook::EmbeddingService;

sub chunk_text {
    my ($text, $chunk_size, $overlap) = @_;
    $chunk_size //= 1000;
    $overlap //= 200;
    my @chunks;
    my $text_length = length($text // '');
    return \@chunks unless $text_length > 0;
    for (my $start = 0; $start < $text_length; $start += ($chunk_size - $overlap)) {
        my $end = $start + $chunk_size;
        $end = $text_length if $end > $text_length;
        my $chunk = substr($text, $start, $end - $start);
        push @chunks, $chunk;
        last if $end >= $text_length;
    }
    return \@chunks;
}

my $db_path;
my $verbose = 0;
my $dry_run = 0;
my $batch_size = 50;
my $model = 'all-MiniLM-L6-v2';

GetOptions(
    'db=s'       => \$db_path,
    'verbose'    => \$verbose,
    'dry-run'    => \$dry_run,
    'batch=i'    => \$batch_size,
    'model=s'    => \$model,
) or die "Usage: $0 [--db=PATH] [--verbose] [--dry-run] [--batch=N] [--model=NAME]\n";

my %config_args = (
    batch_size => $batch_size,
    debug      => $verbose,
);
$config_args{db_path} = $db_path if defined $db_path;

my $config = Commonplacebook::Config->new(%config_args);
my $db = Commonplacebook::Database->new(config => $config);

my $embedding_service;
unless ($dry_run) {
    $embedding_service = Commonplacebook::EmbeddingService->new(
        config  => $config,
        bin_dir => $FindBin::Bin,
    );
}

say "Finding notes needing embeddings..." if $verbose;
my $notes = $db->get_notes_needing_embeddings();

if (@$notes == 0) {
    say "No notes need embeddings.";
    $db->disconnect;
    exit 0;
}

say "Found " . scalar(@$notes) . " notes needing embeddings";

my $processed = 0;
my $total = scalar(@$notes);

for my $note (@$notes) {
    $processed++;
    my $note_id = $note->{id};
    my $path = $note->{path};
    my $content = $note->{raw_content} // '';

    say "[$processed/$total] Processing: $path" if $verbose;

    if ($dry_run) {
        say "  [DRY RUN] Would chunk and embed note $note_id";
        next;
    }

    my $chunks = chunk_text($content);

    if (@$chunks == 0) {
        say "  Skipping empty note: $path" if $verbose;
        next;
    }

    say "  Chunked into " . scalar(@$chunks) . " chunks" if $verbose;

    try {
        # Delete old embeddings
        $db->delete_embeddings_for_note($note_id);

        # Generate embeddings in batches
        my @batch;
        my @batch_indices;

        for my $i (0 .. $#$chunks) {
            push @batch, $chunks->[$i];
            push @batch_indices, $i;

            if (@batch >= $batch_size || $i == $#$chunks) {
                say "  Generating embeddings for batch of " . scalar(@batch) . " chunks..." if $verbose;

                my $embeddings = $embedding_service->get_embeddings_for_texts(\@batch);

                for my $j (0 .. $#batch) {
                    my $chunk_index = $batch_indices[$j];
                    my $chunk_text = $batch[$j];
                    my $embedding = $embeddings->[$j];

                    $db->insert_embedding(
                        $note_id,
                        $chunk_index,
                        $chunk_text,
                        $embedding,
                        $model
                    );
                }

                @batch = ();
                @batch_indices = ();
            }
        }

        say "  Successfully embedded $note_id" if $verbose;
    }
    catch ($e) {
        warn "  Error processing note $note_id: $e\n";
    }
}

say "Embedding sync complete. Processed $processed notes.";
$db->disconnect;

__END__

=head1 NAME

embed-sync.pl - Sync embeddings for zk notebook

=head1 SYNOPSIS

embed-sync.pl [options]

=head1 DESCRIPTION

Finds notes that are new or modified since their last embedding, chunks the
text, and generates embeddings using sentence-transformers locally.

=head1 OPTIONS

=over 4

=item B<--db>=PATH

Path to notebook.db (default: auto-discovered from .zk/notebook.db)

=item B<--verbose>

Print detailed progress information

=item B<--dry-run>

Show what would be done without making changes

=item B<--batch>=N

Number of chunks to embed in each batch (default: 50)

=item B<--model>=NAME

Sentence transformer model to use (default: all-MiniLM-L6-v2)

=back

=head1 EXAMPLES

    # Sync all notes needing embeddings
    embed-sync.pl

    # Verbose output
    embed-sync.pl --verbose

    # Dry run to see what would happen
    embed-sync.pl --dry-run --verbose

    # Custom batch size
    embed-sync.pl --batch=100

=head1 AUTHOR

Chris Prather

=cut
