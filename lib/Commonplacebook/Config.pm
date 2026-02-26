# ABOUTME: Configuration management for Commonplacebook plugin
# ABOUTME: Discovers notebook root, sets defaults, and provides config accessors

package Commonplacebook::Config;

use 5.034;
use warnings;
use experimental qw(signatures);
use Cwd qw(getcwd abs_path);
use File::Spec;

sub new ($class, %args) {
    my $self = {
        batch_size => $args{batch_size} // 10,
        debug => $args{debug} // 0,
        max_results => $args{max_results} // 5,
        model => $args{model} // 'sentence-transformers/all-MiniLM-L6-v2',
        rebuild => $args{rebuild} // 0,
        embedding_dimension => $args{embedding_dimension} // 384,
    };

    # Discover notebook root (walk up to find .zk/config.toml)
    my $notebook_root;
    if (exists $args{notebook_root}) {
        $notebook_root = $args{notebook_root};
    } elsif ($ENV{ZK_NOTEBOOK_DIR}) {
        $notebook_root = $ENV{ZK_NOTEBOOK_DIR};
    } else {
        $notebook_root = _find_notebook_root(getcwd());
    }

    $self->{notebook_root} = $notebook_root;

    # Set db_path (priority: explicit arg > env > default)
    if (exists $args{db_path}) {
        $self->{db_path} = $args{db_path};
    } elsif ($ENV{ZK_DB_PATH}) {
        $self->{db_path} = $ENV{ZK_DB_PATH};
    } else {
        $self->{db_path} = File::Spec->catfile($notebook_root, '.zk', 'notebook.db');
    }

    # Set repo_path
    $self->{repo_path} = $args{repo_path} // $ENV{REPO_PATH} // $notebook_root;

    return bless $self, $class;
}

# Walk up directory tree to find .zk/config.toml
sub _find_notebook_root ($start_dir) {
    my $current = abs_path($start_dir);
    my $root = File::Spec->rootdir();

    while ($current ne $root) {
        my $zk_config = File::Spec->catfile($current, '.zk', 'config.toml');
        if (-f $zk_config) {
            return $current;
        }

        my $parent = File::Spec->catdir($current, File::Spec->updir());
        $parent = abs_path($parent);

        # Prevent infinite loop if we can't go up
        last if $parent eq $current;
        $current = $parent;
    }

    # Fallback to start directory if not found
    return $start_dir;
}

# Accessor methods
sub batch_size ($self) { $self->{batch_size} }
sub db_path ($self) { $self->{db_path} }
sub debug ($self) { $self->{debug} }
sub max_results ($self) { $self->{max_results} }
sub model ($self) { $self->{model} }
sub rebuild ($self) { $self->{rebuild} }
sub repo_path ($self) { $self->{repo_path} }
sub embedding_dimension ($self) { $self->{embedding_dimension} }
sub notebook_root ($self) { $self->{notebook_root} }

1;
