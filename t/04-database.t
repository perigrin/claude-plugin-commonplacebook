#!/usr/bin/env perl
# ABOUTME: Test suite for Commonplacebook::Database module
# ABOUTME: Validates database operations, embeddings, and semantic search

use 5.034;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test 1-3: Module loads
use_ok('Commonplacebook::Config') or BAIL_OUT("Cannot load Config");
use_ok('Commonplacebook::EmbeddingService') or BAIL_OUT("Cannot load EmbeddingService");
use_ok('Commonplacebook::Database') or BAIL_OUT("Cannot load Database");

# Setup test database
my $tmpdir = tempdir(CLEANUP => 1);
my $db_path = File::Spec->catfile($tmpdir, 'test.db');

# Create minimal zk schema
use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
});

$dbh->do(q{
    CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        title TEXT DEFAULT('') NOT NULL,
        body TEXT DEFAULT('') NOT NULL,
        raw_content TEXT DEFAULT('') NOT NULL,
        modified DATETIME DEFAULT(CURRENT_TIMESTAMP) NOT NULL,
        checksum TEXT NOT NULL,
        sortable_path TEXT NOT NULL,
        lead TEXT DEFAULT('') NOT NULL,
        word_count INTEGER DEFAULT(0) NOT NULL,
        created DATETIME DEFAULT(CURRENT_TIMESTAMP) NOT NULL,
        metadata TEXT DEFAULT('{}') NOT NULL
    )
});

$dbh->do(q{
    CREATE VIRTUAL TABLE notes_fts USING fts5(
        path, title, body,
        content = notes,
        content_rowid = id
    )
});

# Create triggers to sync FTS
$dbh->do(q{
    CREATE TRIGGER trigger_notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts(rowid, path, title, body) VALUES (new.id, new.path, new.title, new.body);
    END
});

$dbh->do(q{
    CREATE TRIGGER trigger_notes_au AFTER UPDATE ON notes BEGIN
        INSERT INTO notes_fts(notes_fts, rowid, path, title, body) VALUES('delete', old.id, old.path, old.title, old.body);
        INSERT INTO notes_fts(rowid, path, title, body) VALUES (new.id, new.path, new.title, new.body);
    END
});

# Insert test notes
$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('test1.md', 'Test Note 1', 'This is test note one.', 'raw1', 'abc123', 'test1.md')
});

$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('test2.md', 'Test Note 2', 'This is test note two.', 'raw2', 'def456', 'test2.md')
});

$dbh->disconnect;

# Test 4: Database constructor
my $config = Commonplacebook::Config->new(db_path => $db_path);
my $db = Commonplacebook::Database->new(config => $config);
ok($db, "Database created");
isa_ok($db, 'Commonplacebook::Database');

# Test 5: dbh accessor
ok($db->dbh, "dbh accessor returns handle");

# Test 6: get_note_by_path
my $note = $db->get_note_by_path('test1.md');
ok($note, "Note retrieved by path");
is($note->{title}, 'Test Note 1', "Note has correct title");
is($note->{body}, 'This is test note one.', "Note has correct body");

# Test 7: get_note_by_path with non-existent note
my $missing = $db->get_note_by_path('missing.md');
ok(!$missing, "Non-existent note returns undef");

# Test 8: embeddings table created
my $sth = $db->dbh->prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='embeddings'");
$sth->execute();
my ($table_name) = $sth->fetchrow_array();
is($table_name, 'embeddings', "Embeddings table exists");

# Test 9: insert_embedding
my $note_id = $note->{id};
my $embedding = pack("f*", (0.1) x 384);
$db->insert_embedding($note_id, 0, "chunk text", $embedding, 'test-model');

$sth = $db->dbh->prepare("SELECT chunk_text, model FROM embeddings WHERE note_id = ?");
$sth->execute($note_id);
my ($chunk_text, $model) = $sth->fetchrow_array();
is($chunk_text, "chunk text", "Embedding chunk text stored");
is($model, 'test-model', "Embedding model stored");

# Test 10: delete_embeddings_for_note
$db->delete_embeddings_for_note($note_id);
$sth = $db->dbh->prepare("SELECT COUNT(*) FROM embeddings WHERE note_id = ?");
$sth->execute($note_id);
my ($count) = $sth->fetchrow_array();
is($count, 0, "Embeddings deleted for note");

# Test 11: get_notes_needing_embeddings
my $notes_needing = $db->get_notes_needing_embeddings();
ok(scalar(@$notes_needing) > 0, "Notes needing embeddings found");
ok((grep { $_->{path} eq 'test1.md' } @$notes_needing), "test1.md needs embeddings");

# Test 12: keyword search
my $results = $db->search('test note', 10);
ok(scalar(@$results) > 0, "Keyword search returns results");
ok((grep { $_->{title} eq 'Test Note 1' } @$results), "Keyword search finds test1");

# Test 13: cosine_similarity
my $emb1 = pack("f*", (1, 0, 0, 0) x 96);  # 384 dimensions
my $emb2 = pack("f*", (1, 0, 0, 0) x 96);  # identical
my $similarity = $db->cosine_similarity($emb1, $emb2);
is($similarity, 1.0, "Identical embeddings have similarity 1.0");

my $emb3 = pack("f*", (0, 1, 0, 0) x 96);  # orthogonal
my $similarity2 = $db->cosine_similarity($emb1, $emb3);
is($similarity2, 0.0, "Orthogonal embeddings have similarity 0.0");

# Test 14: Transaction methods
eval {
    $db->begin_transaction();
    $db->commit_transaction();
};
ok(!$@, "Transaction methods work");

# Test 15: Disconnect
eval { $db->disconnect(); };
ok(!$@, "Database disconnects cleanly");

done_testing();
