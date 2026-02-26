# ABOUTME: Database interface for Commonplacebook plugin
# ABOUTME: Manages notes, embeddings, and semantic search operations

package Commonplacebook::Database;

use 5.034;
use warnings;
use experimental qw(signatures try);
use DBI;
use DBD::SQLite;
use Commonplacebook::EmbeddingService;
use Commonplacebook::Logger;

sub new ($class, %args) {
    my $config = $args{config};
    my $logger = Commonplacebook::Logger->new();

    my $db_path = $config->db_path;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
    });

    $dbh->do("PRAGMA foreign_keys = ON");

    my $self = {
        dbh => $dbh,
        config => $config,
        logger => $logger,
    };

    bless $self, $class;
    $self->_ensure_embeddings_table();
    return $self;
}

sub _ensure_embeddings_table ($self) {
    my $dbh = $self->{dbh};

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS embeddings (
            id INTEGER PRIMARY KEY,
            note_id INTEGER NOT NULL,
            chunk_index INTEGER NOT NULL,
            chunk_text TEXT NOT NULL,
            embedding BLOB NOT NULL,
            model TEXT DEFAULT 'voyage-3',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
            UNIQUE (note_id, chunk_index)
        )
    });

    $dbh->do(q{
        CREATE INDEX IF NOT EXISTS idx_embeddings_note_id ON embeddings(note_id)
    });
}

sub dbh ($self) { $self->{dbh} }

sub disconnect ($self) { $self->{dbh}->disconnect; }

sub begin_transaction ($self) { $self->{dbh}->begin_work; }

sub commit_transaction ($self) { $self->{dbh}->commit; }

sub rollback_transaction ($self) { $self->{dbh}->rollback; }

sub get_note_by_path ($self, $path) {
    my $sth = $self->{dbh}->prepare("SELECT id, path, title, body, raw_content, modified FROM notes WHERE path = ?");
    $sth->execute($path);
    return $sth->fetchrow_hashref;
}

sub get_notes_needing_embeddings ($self) {
    my $sth = $self->{dbh}->prepare(q{
        SELECT n.id, n.path, n.title, n.raw_content, n.modified
        FROM notes n
        LEFT JOIN (
            SELECT note_id, MAX(created_at) as last_embedded
            FROM embeddings
            GROUP BY note_id
        ) e ON n.id = e.note_id
        WHERE e.note_id IS NULL OR n.modified > e.last_embedded
    });

    $sth->execute();

    my @notes;
    while (my $row = $sth->fetchrow_hashref) {
        push @notes, $row;
    }

    return \@notes;
}

sub insert_embedding ($self, $note_id, $chunk_index, $chunk_text, $embedding, $model = 'voyage-3') {
    my $sth = $self->{dbh}->prepare(q{
        INSERT OR REPLACE INTO embeddings (note_id, chunk_index, chunk_text, embedding, model)
        VALUES (?, ?, ?, ?, ?)
    });
    $sth->execute($note_id, $chunk_index, $chunk_text, $embedding, $model);
}

sub delete_embeddings_for_note ($self, $note_id) {
    my $sth = $self->{dbh}->prepare("DELETE FROM embeddings WHERE note_id = ?");
    $sth->execute($note_id);
}

sub search ($self, $query, $limit = 10) {
    my $logger = $self->{logger};
    $logger->log("Performing keyword search for: $query (limit: $limit)");

    my $sth = $self->{dbh}->prepare(q{
        SELECT n.id, n.title, n.path, snippet(notes_fts, 2, '<b>', '</b>', '...', 15) as snippet, n.body
        FROM notes_fts
        JOIN notes n ON notes_fts.rowid = n.id
        WHERE notes_fts MATCH ?
        ORDER BY rank
        LIMIT ?
    });

    $sth->execute($query, $limit);

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        my $max_content = 1000;
        if (defined $row->{body} && length($row->{body}) > $max_content) {
            $row->{body} = substr($row->{body}, 0, $max_content) . "...";
        }
        push @results, $row;
    }

    $logger->log("Search found " . scalar(@results) . " results");
    return \@results;
}

sub semantic_search ($self, $query, $limit = 10) {
    my $logger = $self->{logger};
    $logger->log("Performing semantic search for: $query (limit: $limit)");

    my $embedding_service = Commonplacebook::EmbeddingService->new(config => $self->{config});
    my $query_embedding = $embedding_service->get_embedding_for_text($query, 'query');

    return $self->search_similar($query_embedding, $limit);
}

sub search_similar ($self, $query_embedding, $limit = 10) {
    my $sth = $self->{dbh}->prepare(q{
        SELECT e.note_id, e.chunk_index, e.chunk_text, e.embedding, n.title, n.path
        FROM embeddings e
        JOIN notes n ON e.note_id = n.id
    });

    $sth->execute();

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        my $similarity = $self->cosine_similarity($query_embedding, $row->{embedding});
        push @results, {
            note_id => $row->{note_id},
            chunk_index => $row->{chunk_index},
            chunk_text => $row->{chunk_text},
            title => $row->{title},
            path => $row->{path},
            similarity => $similarity,
        };
    }

    my @sorted = sort { $b->{similarity} <=> $a->{similarity} } @results;

    my $end = $limit - 1 < $#sorted ? $limit - 1 : $#sorted;
    return $end >= 0 ? [@sorted[0 .. $end]] : [];
}

sub find_similar_notes ($self, $path, $limit = 10) {
    my $note = $self->get_note_by_path($path);
    return [] unless $note;

    my $sth = $self->{dbh}->prepare(q{
        SELECT embedding FROM embeddings WHERE note_id = ? ORDER BY chunk_index LIMIT 1
    });
    $sth->execute($note->{id});

    my ($embedding) = $sth->fetchrow_array;
    return [] unless $embedding;

    my $results = $self->search_similar($embedding, $limit + 1);

    # Filter out the query note itself
    return [grep { $_->{path} ne $path } @$results];
}

sub cosine_similarity ($self, $embedding1, $embedding2) {
    my @vec1 = unpack("f*", $embedding1);
    my @vec2 = unpack("f*", $embedding2);

    my ($dot_product, $norm1, $norm2) = (0, 0, 0);

    for (my $i = 0; $i < @vec1; $i++) {
        $dot_product += $vec1[$i] * $vec2[$i];
        $norm1 += $vec1[$i] * $vec1[$i];
        $norm2 += $vec2[$i] * $vec2[$i];
    }

    $norm1 = sqrt($norm1);
    $norm2 = sqrt($norm2);

    return 0 if $norm1 == 0 || $norm2 == 0;
    return $dot_product / ($norm1 * $norm2);
}

1;
