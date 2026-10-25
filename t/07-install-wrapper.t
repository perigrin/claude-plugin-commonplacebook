#!/usr/bin/env perl
# ABOUTME: Tests for scripts/install-wrapper.sh and the wrappers it generates
# ABOUTME: Verifies the wrappers run a pinned Perl with a private module library, independent of PATH

use 5.034;
use warnings;
use experimental qw(signatures);

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);
use FindBin;
use IPC::Open3 qw(open3);

my $root      = "$FindBin::Bin/..";
my $installer = "$root/scripts/install-wrapper.sh";

# The pinned Perl the wrappers should use. Tests skip if it isn't installed,
# because installing a Perl is outside what this suite should do.
my $pinned_perl = $ENV{CPB_PERL} // "$ENV{HOME}/.local/share/pvm/versions/5.42.0/bin/perl";
plan skip_all => "pinned Perl not installed at $pinned_perl (pvm install 5.42.0)"
    unless -x $pinned_perl;

# Building DBI and DBD::SQLite is slow, so the module library persists across
# test runs in a fixed temp location rather than a per-run tempdir.
my $test_lib = $ENV{CPB_TEST_LIB} // File::Spec->catdir(File::Spec->tmpdir, 'cpb-test-perl5');

# A fake HOME containing a copy of the plugin where the wrapper looks for it.
my $home       = tempdir(CLEANUP => 1);
my $plugin_dir = "$home/.claude/plugins/cache/perigrin-marketplace/commonplacebook/0.0.0";
make_path($plugin_dir);
system('cp', '-R', "$root/bin", "$root/lib", $plugin_dir) == 0
    or BAIL_OUT("could not copy plugin into fake HOME");

my $bin_dir = "$home/.local/bin";

sub run_installer (%env) {
    my %saved = %ENV;
    local %ENV = (%saved, HOME => $home, ZK_SEARCH_BIN_DIR => $bin_dir, %env);
    my $output = `bash $installer 2>&1`;
    return ($? >> 8, $output);
}

sub slurp ($path) {
    open my $fh, '<', $path or return '';
    local $/;
    return <$fh>;
}

# A PATH holding only the tools the wrappers need and no perl, so success
# proves the wrappers don't depend on whatever perl is on PATH.
my $tools_dir = "$home/tools";
make_path($tools_dir);
for my $tool (qw(/bin/bash /usr/bin/env /usr/bin/find /usr/bin/head)) {
    my ($name) = $tool =~ m{([^/]+)$};
    symlink($tool, "$tools_dir/$name") or BAIL_OUT("could not link $tool");
}

# Runs a command with an empty environment and the perl-free PATH, without a
# shell in between, returning its exit status and combined output.
sub run_isolated (@cmd) {
    my $pid = open3(my $in, my $out, undef,
        '/usr/bin/env', '-i', "HOME=$home", "PATH=$tools_dir", @cmd);
    close $in;
    my $output = do { local $/; <$out> } // '';
    waitpid($pid, 0);
    return ($? >> 8, $output);
}

subtest 'installer refuses a missing pinned Perl' => sub {
    my ($exit, $output) = run_installer(CPB_PERL => '/nonexistent/perl', CPB_LIB => $test_lib);
    isnt($exit, 0, 'exits with an error');
    like($output, qr{/nonexistent/perl}, 'names the missing Perl');
    like($output, qr/pvm install/, 'says how to install it');
    ok(!-e "$bin_dir/zk-search", 'does not write a wrapper');
};

my ($exit, $output) = run_installer(CPB_PERL => $pinned_perl, CPB_LIB => $test_lib);
is($exit, 0, 'installer succeeds with the pinned Perl') or diag $output;

for my $tool (qw(zk-search embed-sync)) {
    subtest "$tool wrapper" => sub {
        my $wrapper = "$bin_dir/$tool";
        ok(-x $wrapper, 'is installed and executable');

        my $content = slurp($wrapper);
        like($content, qr/^# ABOUTME: /m, 'has ABOUTME header');
        like($content, qr/\Q$pinned_perl\E/, 'runs the pinned Perl');
        like($content, qr/PERL5LIB=.*\Q$test_lib\E/, 'uses the private module library');
        unlike($content, qr/exec perl\b/, 'does not exec whatever perl is on PATH');
    };
}

subtest 'modules load from the private library' => sub {
    my ($exit, $output) = run_isolated(
        "$pinned_perl", "-Mlib=$test_lib/lib/perl5", '-MDBI', '-MDBD::SQLite',
        '-e', 'print "ok $DBI::VERSION\n"',
    );
    is($exit, 0, 'DBI and DBD::SQLite load under the pinned Perl') or diag $output;
};

subtest 'zk-search runs without any perl on PATH' => sub {
    my ($exit, $output) = run_isolated("$bin_dir/zk-search", '--help');
    ok($exit == 0 || $exit == 1, '--help exits cleanly') or diag $output;
    like($output, qr/SYNOPSIS/, 'shows documentation');
    unlike($output, qr/Can't locate/, 'finds all its modules');
};

subtest 'zk-search keyword search works end to end' => sub {
    my $db = "$home/notebook.db";
    my ($exit, $output) = run_isolated(
        "$pinned_perl", "-Mlib=$test_lib/lib/perl5", '-MDBI', '-e', <<"PERL",
my \$dbh = DBI->connect('dbi:SQLite:dbname=$db', '', '', { RaiseError => 1 });
\$dbh->do(q{CREATE TABLE notes (id INTEGER PRIMARY KEY, path TEXT, title TEXT, body TEXT)});
\$dbh->do(q{CREATE VIRTUAL TABLE notes_fts USING fts5(path, title, body, content = notes, content_rowid = id)});
\$dbh->do(q{INSERT INTO notes (path, title, body) VALUES ('pages/perl.md', 'Perl Programming', 'About Perl.')});
\$dbh->do(q{INSERT INTO notes_fts (rowid, path, title, body) SELECT id, path, title, body FROM notes});
PERL
    );
    is($exit, 0, 'test database created') or diag $output;

    ($exit, $output) = run_isolated("$bin_dir/zk-search", "--db=$db", 'keyword', 'Perl');
    is($exit, 0, 'keyword search exits cleanly') or diag $output;
    like($output, qr/Perl Programming/, 'finds the note');
};

subtest 'embed-sync runs without any perl on PATH' => sub {
    my ($exit, $output) = run_isolated("$bin_dir/embed-sync", '--invalid-arg');
    unlike($output, qr/Can't locate/, 'finds all its modules') or diag $output;
    like($output, qr/Usage:|Unknown option/i, 'reaches its own argument handling');
};

done_testing;
