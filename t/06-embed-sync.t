#!/usr/bin/env perl
# ABOUTME: Integration tests for bin/embed-sync.pl CLI tool
# ABOUTME: Tests help output, dry-run mode, and basic embedding sync workflow

use 5.034;
use warnings;
use experimental qw(signatures try);

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use FindBin;

my $lib_dir = "$FindBin::Bin/../lib";
my $bin_dir = "$FindBin::Bin/../bin";
my $embed_sync = "$bin_dir/embed-sync.pl";

# Check that embed-sync.pl exists
ok(-f $embed_sync, "embed-sync.pl script exists");

# Test 1: Invalid args show usage
my $invalid_output = `/usr/bin/perl -I$lib_dir $embed_sync --invalid-arg 2>&1`;
my $invalid_exit = $? >> 8;
isnt($invalid_exit, 0, "Invalid args exit with error");
like($invalid_output, qr/Usage:|Unknown option/i, "Invalid args show usage message");

# Setup test database
my $tmpdir = tempdir(CLEANUP => 1);
my $db_path = File::Spec->catfile($tmpdir, 'test.db');

use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
});

# Create minimal zk schema
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

# Create embeddings table
$dbh->do(q{
    CREATE TABLE IF NOT EXISTS embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        chunk_text TEXT NOT NULL,
        embedding BLOB NOT NULL,
        model TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        UNIQUE(note_id, chunk_index)
    )
});

# Insert test notes needing embeddings
$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('pages/test-note-1.md', 'Test Note 1', 'This is a test note about embeddings.', 'This is the raw content for testing embeddings sync.', 'abc123', 'pages/test-note-1.md')
});

$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('pages/test-note-2.md', 'Test Note 2', 'Another test note.', 'More raw content to test chunking and embedding generation.', 'def456', 'pages/test-note-2.md')
});

$dbh->disconnect;

# Test 2: Empty database (no notes) completes cleanly
my $empty_tmpdir = tempdir(CLEANUP => 1);
my $empty_db_path = File::Spec->catfile($empty_tmpdir, 'empty.db');
my $empty_dbh = DBI->connect("dbi:SQLite:dbname=$empty_db_path", "", "", {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
});
$empty_dbh->do(q{
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
$empty_dbh->do(q{
    CREATE TABLE IF NOT EXISTS embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        chunk_text TEXT NOT NULL,
        embedding BLOB NOT NULL,
        model TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        UNIQUE(note_id, chunk_index)
    )
});
$empty_dbh->disconnect;

my $empty_output = `/usr/bin/perl -I$lib_dir $embed_sync --db=$empty_db_path 2>&1`;
my $empty_exit = $? >> 8;
is($empty_exit, 0, "Empty database exits cleanly");
like($empty_output, qr/No notes need embeddings/i, "Empty database shows no notes message");

# Test 3: Dry-run reports notes needing embeddings
my $dry_output = `/usr/bin/perl -I$lib_dir $embed_sync --db=$db_path --dry-run --verbose 2>&1`;
my $dry_exit = $? >> 8;
is($dry_exit, 0, "Dry-run exits cleanly");
like($dry_output, qr/Found \d+ notes needing embeddings/i, "Dry-run reports count");
like($dry_output, qr/DRY RUN/i, "Dry-run shows dry-run marker");
like($dry_output, qr/test-note-1\.md|test-note-2\.md/, "Dry-run lists note files");

# Test 4: Dry-run doesn't modify database
$dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
});
my $sth = $dbh->prepare("SELECT COUNT(*) FROM embeddings");
$sth->execute();
my ($before_count) = $sth->fetchrow_array();

my $dry_output2 = `/usr/bin/perl -I$lib_dir $embed_sync --db=$db_path --dry-run 2>&1`;
$sth->execute();
my ($after_count) = $sth->fetchrow_array();

is($after_count, $before_count, "Dry-run doesn't insert embeddings");

# Test 5: Verbose mode shows progress
my $verbose_output = `/usr/bin/perl -I$lib_dir $embed_sync --db=$db_path --dry-run --verbose 2>&1`;
my $verbose_exit = $? >> 8;
is($verbose_exit, 0, "Verbose mode exits cleanly");
like($verbose_output, qr/Finding notes needing embeddings/i, "Verbose shows progress messages");
like($verbose_output, qr/Processing:|Would chunk/i, "Verbose shows per-note progress");

# Test 6: Notes with embeddings are skipped
# Add an embedding for one note
my $note_id;
$sth = $dbh->prepare("SELECT id FROM notes WHERE path = 'pages/test-note-1.md'");
$sth->execute();
($note_id) = $sth->fetchrow_array();

# Insert a dummy embedding
my $embedding = pack("f*", (0.1) x 384);
$dbh->do("INSERT INTO embeddings (note_id, chunk_index, chunk_text, embedding, model) VALUES (?, 0, 'test chunk', ?, 'test-model')",
    undef, $note_id, $embedding);

my $skip_output = `/usr/bin/perl -I$lib_dir $embed_sync --db=$db_path --dry-run --verbose 2>&1`;
unlike($skip_output, qr/test-note-1\.md/, "Note with embeddings is skipped");
like($skip_output, qr/test-note-2\.md/, "Note without embeddings is included");

$sth->finish();
$dbh->disconnect;

done_testing();
