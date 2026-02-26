#!/usr/bin/env perl
# ABOUTME: Test suite for Commonplacebook::Config module
# ABOUTME: Validates configuration loading, path discovery, and defaults

use 5.034;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test 1: Module loads
use_ok('Commonplacebook::Config') or BAIL_OUT("Cannot load Commonplacebook::Config");

# Test 2: Basic constructor with explicit paths
my $config = Commonplacebook::Config->new(
    batch_size => 20,
    debug => 1,
    max_results => 10,
);
ok($config, "Config created with explicit parameters");
isa_ok($config, 'Commonplacebook::Config');

# Test 3: Accessors work
is($config->batch_size, 20, "batch_size accessor works");
is($config->debug, 1, "debug accessor works");
is($config->max_results, 10, "max_results accessor works");
is($config->model, 'sentence-transformers/all-MiniLM-L6-v2', "model has default value");
is($config->embedding_dimension, 384, "embedding_dimension has default value");
is($config->rebuild, 0, "rebuild defaults to 0");

# Test 4: Notebook root discovery from ZK_NOTEBOOK_DIR
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $zk_dir = File::Spec->catdir($tmpdir, '.zk');
    make_path($zk_dir);

    # Create config file
    my $config_file = File::Spec->catfile($zk_dir, 'config.toml');
    open my $fh, '>', $config_file or die "Cannot create config: $!";
    print $fh "[notebook]\n";
    close $fh;

    local $ENV{ZK_NOTEBOOK_DIR} = $tmpdir;
    my $cfg = Commonplacebook::Config->new();

    is($cfg->notebook_root, $tmpdir, "Notebook root discovered from ZK_NOTEBOOK_DIR");
    like($cfg->db_path, qr/\.zk\/notebook\.db$/, "db_path uses notebook_root by default");
}

# Test 5: Notebook root discovery by walking up from cwd
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $subdir = File::Spec->catdir($tmpdir, 'sub', 'deep');
    make_path($subdir);

    my $zk_dir = File::Spec->catdir($tmpdir, '.zk');
    make_path($zk_dir);

    my $config_file = File::Spec->catfile($zk_dir, 'config.toml');
    open my $fh, '>', $config_file or die "Cannot create config: $!";
    print $fh "[notebook]\n";
    close $fh;

    # Change to subdirectory
    my $orig_cwd = Cwd::getcwd();
    chdir($subdir) or die "Cannot chdir: $!";

    local $ENV{ZK_NOTEBOOK_DIR} = undef;
    my $cfg = Commonplacebook::Config->new();

    # Use abs_path to normalize both paths (handles /private/var vs /var on macOS)
    is(Cwd::abs_path($cfg->notebook_root), Cwd::abs_path($tmpdir), "Notebook root discovered by walking up from cwd");

    chdir($orig_cwd);
}

# Test 6: Explicit db_path override
{
    my $custom_db = '/tmp/custom.db';
    my $cfg = Commonplacebook::Config->new(db_path => $custom_db);
    is($cfg->db_path, $custom_db, "Explicit db_path overrides default");
}

# Test 7: ZK_DB_PATH environment variable
{
    local $ENV{ZK_DB_PATH} = '/tmp/env.db';
    my $cfg = Commonplacebook::Config->new();
    is($cfg->db_path, '/tmp/env.db', "ZK_DB_PATH env var sets db_path");
}

# Test 8: notebook_root fallback when .zk not found
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $orig_cwd = Cwd::getcwd();
    chdir($tmpdir) or die "Cannot chdir: $!";

    local $ENV{ZK_NOTEBOOK_DIR} = undef;
    my $cfg = Commonplacebook::Config->new();

    # Should fall back to cwd if no .zk found
    ok($cfg->notebook_root, "notebook_root has fallback value");

    chdir($orig_cwd);
}

done_testing();
