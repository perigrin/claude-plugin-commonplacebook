#!/usr/bin/env bash
# ABOUTME: Installs stable zk-search and embed-sync wrappers to a bin directory
# ABOUTME: Wrappers discover the plugin path dynamically and run it under a pinned Perl with a private module library

set -euo pipefail

WRAPPER_DIR="${ZK_SEARCH_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"

# The Perl the wrappers run. Pinned to a pvm-managed version so that whatever
# `perl` happens to be first on PATH (e.g. Homebrew's) is never used.
CPB_PERL="${CPB_PERL:-$HOME/.local/share/pvm/versions/5.42.0/bin/perl}"

# Private module library holding DBI and DBD::SQLite, built for CPB_PERL.
CPB_LIB="${CPB_LIB:-${XDG_DATA_HOME:-$HOME/.local/share}/commonplacebook/perl5}"

if [[ ! -x "$CPB_PERL" ]]; then
    echo "Error: pinned Perl not found at $CPB_PERL" >&2
    echo "  Install it with: pvm install 5.42.0" >&2
    echo "  Or point CPB_PERL at another Perl 5.34+" >&2
    exit 1
fi

install_modules() {
    if env -i PATH=/usr/bin:/bin "$CPB_PERL" -Mlib="$CPB_LIB/lib/perl5" \
        -MDBI -MDBD::SQLite -e1 2>/dev/null; then
        return 0
    fi

    local cpanm
    cpanm="$(command -v cpanm || true)"
    if [[ -z "$cpanm" ]]; then
        echo "Error: cpanm not found; it is needed once to install DBI and DBD::SQLite" >&2
        echo "  Install it with: brew install cpanminus" >&2
        exit 1
    fi

    mkdir -p "$CPB_LIB"
    local log="$CPB_LIB/install.log"
    echo "Installing DBI and DBD::SQLite into $CPB_LIB (this takes a few minutes)..."
    # Run cpanm under the pinned Perl so XS modules are built for it, with a
    # clean module environment so nothing leaks in from another Perl.
    if ! env -u PERL5LIB -u PERL_MM_OPT -u PERL_MB_OPT -u PERL_LOCAL_LIB_ROOT \
        "$CPB_PERL" "$cpanm" --quiet -L "$CPB_LIB" DBI DBD::SQLite >"$log" 2>&1; then
        echo "Error: module installation failed; see $log" >&2
        exit 1
    fi
}

write_wrapper() {
    local name="$1" script="$2"
    local path="${WRAPPER_DIR}/${name}"

    cat > "$path" <<WRAPPER
#!/usr/bin/env bash
# ABOUTME: Stable wrapper for commonplacebook plugin's ${script}
# ABOUTME: Discovers current plugin install path dynamically and runs it under a pinned Perl

PLUGIN_BIN=\$(find "\${HOME}/.claude/plugins/cache/perigrin-marketplace/commonplacebook" \\
    -name ${script} -path '*/bin/*' 2>/dev/null | head -1)

if [[ -z "\$PLUGIN_BIN" ]]; then
    echo "Error: commonplacebook plugin not found. Install with:" >&2
    echo "  /plugin marketplace add perigrin/claude-plugins-marketplace" >&2
    echo "  /plugin install commonplacebook@perigrin-marketplace" >&2
    exit 1
fi

export PERL5LIB="${CPB_LIB}/lib/perl5"
exec "${CPB_PERL}" "\$PLUGIN_BIN" "\$@"
WRAPPER

    chmod +x "$path"
    echo "Installed ${name} wrapper to $path"
}

install_modules

mkdir -p "$WRAPPER_DIR"
write_wrapper zk-search zk-search
write_wrapper embed-sync embed-sync.pl
