#!/usr/bin/env perl
# ABOUTME: Integration tests for bin/zk-search CLI tool
# ABOUTME: Tests help output, error handling, and search functionality with test database

use 5.034;
use warnings;
use experimental qw(signatures try);

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use FindBin;

my $lib_dir = "$FindBin::Bin/../lib";
my $bin_dir = "$FindBin::Bin/../bin";
my $zk_search = "$bin_dir/zk-search";

# Check that zk-search exists
ok(-f $zk_search, "zk-search script exists");

# Test 1: --help exits cleanly (pod2usage exits with 1)
my $help_output = `/usr/bin/perl -I$lib_dir $zk_search --help 2>&1`;
my $help_exit = $? >> 8;
ok($help_exit == 0 || $help_exit == 1, "--help exits cleanly");
like($help_output, qr/SYNOPSIS/, "--help shows documentation");
like($help_output, qr/zk-search/, "--help mentions script name");

# Test 2: No query gives error
my $no_query_output = `/usr/bin/perl -I$lib_dir $zk_search keyword 2>&1`;
my $no_query_exit = $? >> 8;
isnt($no_query_exit, 0, "No query exits with error");
like($no_query_output, qr/Query required/i, "No query shows error message");

# Test 3: Unknown command (but first checks if db exists)
my $unknown_cmd_output = `/usr/bin/perl -I$lib_dir $zk_search --db=/tmp/fake.db badcommand query 2>&1`;
my $unknown_cmd_exit = $? >> 8;
isnt($unknown_cmd_exit, 0, "Unknown command exits with error");
like($unknown_cmd_output, qr/Unknown command|Error|Database not found/i, "Unknown command shows error");

# Setup test database
my $tmpdir = tempdir(CLEANUP => 1);
my $db_path = File::Spec->catfile($tmpdir, 'test.db');

use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
});

# Create minimal zk schema for FTS search
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

# Insert test notes
$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('pages/perl-programming.md', 'Perl Programming', 'This note is about Perl programming language features.', 'raw content', 'abc123', 'pages/perl-programming.md')
});

$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('pages/python-basics.md', 'Python Basics', 'This note covers Python programming fundamentals.', 'raw content 2', 'def456', 'pages/python-basics.md')
});

$dbh->do(q{
    INSERT INTO notes (path, title, body, raw_content, checksum, sortable_path)
    VALUES ('pages/rust-ownership.md', 'Rust Ownership', 'Rust memory management and ownership model.', 'raw content 3', 'ghi789', 'pages/rust-ownership.md')
});

$dbh->disconnect;

# Test 4: Missing database error
my $missing_db = "$tmpdir/nonexistent.db";
my $missing_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$missing_db keyword "test" 2>&1`;
my $missing_exit = $? >> 8;
isnt($missing_exit, 0, "Missing database exits with error");
like($missing_output, qr/Database not found|Error/i, "Missing database shows error message");

# Test 5: Keyword search returns results
my $keyword_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path keyword "Perl" 2>&1`;
my $keyword_exit = $? >> 8;
is($keyword_exit, 0, "Keyword search exits cleanly");
like($keyword_output, qr/Perl Programming/, "Keyword search finds Perl note");
like($keyword_output, qr/Path:.*perl-programming\.md/, "Keyword search shows path");

# Test 6: JSON output mode
my $json_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path --json keyword "Perl" 2>&1`;
my $json_exit = $? >> 8;
is($json_exit, 0, "JSON output exits cleanly");
like($json_output, qr/^\[/, "JSON output starts with array bracket");
like($json_output, qr/"title"/, "JSON output contains title field");
like($json_output, qr/"path"/, "JSON output contains path field");

# Test 7: Paths-only output mode
my $paths_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path --paths keyword "programming" 2>&1`;
my $paths_exit = $? >> 8;
is($paths_exit, 0, "Paths-only output exits cleanly");
like($paths_output, qr/^pages\/.*\.md$/m, "Paths-only shows file paths");
unlike($paths_output, qr/Path:|Title:|Snippet:/, "Paths-only doesn't show formatting");

# Test 8: Limit parameter
my $limit_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path --limit=1 keyword "programming" 2>&1`;
my $limit_exit = $? >> 8;
is($limit_exit, 0, "Limit parameter works");
my @results = ($limit_output =~ /^\d+\. /mg);
is(scalar(@results), 1, "Limit=1 returns only 1 result");

# Test 9: Short command alias (k for keyword)
my $alias_output = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path k "Perl" 2>&1`;
my $alias_exit = $? >> 8;
is($alias_exit, 0, "Short alias 'k' works");
like($alias_output, qr/Perl Programming/, "Short alias finds same results");

# Test 10: No results case
my $no_results = `/usr/bin/perl -I$lib_dir $zk_search --db=$db_path keyword "xyzzynonexistent" 2>&1`;
my $no_results_exit = $? >> 8;
is($no_results_exit, 0, "No results exits cleanly");
like($no_results, qr/No results found|^$/i, "No results shows appropriate message");

done_testing();
