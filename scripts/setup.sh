#!/usr/bin/env bash
# ABOUTME: Verifies commonplacebook plugin dependencies and generates zk config snippet
# ABOUTME: Checks Perl, DBI/DBD::SQLite, uv, zk, sqlite3, and embeddings table setup

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_WARNING=2

# Status symbols
readonly CHECK_PASS="✅"
readonly CHECK_WARN="⚠️"
readonly CHECK_FAIL="❌"

# Track overall status
OVERALL_STATUS=$EXIT_SUCCESS

# Helper functions
update_status() {
    local new_status=$1
    # Priority: FAILURE > WARNING > SUCCESS
    if [[ $new_status -eq $EXIT_FAILURE ]]; then
        OVERALL_STATUS=$EXIT_FAILURE
    elif [[ $new_status -eq $EXIT_WARNING && $OVERALL_STATUS -ne $EXIT_FAILURE ]]; then
        OVERALL_STATUS=$EXIT_WARNING
    fi
}

# Compare versions in pure bash
# Returns 0 if version1 >= version2, 1 otherwise
version_gte() {
    local version1=$1
    local version2=$2

    # Split versions into arrays
    IFS='.' read -ra v1 <<< "$version1"
    IFS='.' read -ra v2 <<< "$version2"

    # Compare major version
    if [[ ${v1[0]:-0} -gt ${v2[0]:-0} ]]; then
        return 0
    elif [[ ${v1[0]:-0} -lt ${v2[0]:-0} ]]; then
        return 1
    fi

    # Compare minor version
    if [[ ${v1[1]:-0} -ge ${v2[1]:-0} ]]; then
        return 0
    else
        return 1
    fi
}

print_check() {
    local symbol=$1
    local message=$2
    echo "  $symbol $message"
}

print_section() {
    echo ""
    echo "$1"
    echo "$(printf '%.0s-' {1..60})"
}

# Determine plugin root (one level up from scripts/)
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check functions
check_perl_version() {
    local required="5.34"

    if ! command -v perl &> /dev/null; then
        print_check "$CHECK_FAIL" "Perl not found"
        echo "    → Install: brew install perl"
        return $EXIT_FAILURE
    fi

    local version=$(perl -v 2>&1 | grep -oE 'v5\.[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
    local major_minor=$(echo "$version" | grep -oE '^5\.[0-9]+')

    if version_gte "$major_minor" "$required"; then
        print_check "$CHECK_PASS" "Perl $version (>= $required)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "Perl $version (< $required required)"
        return $EXIT_FAILURE
    fi
}

check_dbi() {
    if perl -MDBI -e1 2>/dev/null; then
        local version=$(perl -MDBI -e 'print $DBI::VERSION' 2>/dev/null)
        print_check "$CHECK_PASS" "DBI installed (v$version)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "DBI not installed"
        echo "    → Install: cpanm DBI"
        return $EXIT_FAILURE
    fi
}

check_dbd_sqlite() {
    if perl -MDBD::SQLite -e1 2>/dev/null; then
        local version=$(perl -MDBD::SQLite -e 'print $DBD::SQLite::VERSION' 2>/dev/null)
        print_check "$CHECK_PASS" "DBD::SQLite installed (v$version)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "DBD::SQLite not installed"
        echo "    → Install: cpanm DBD::SQLite"
        return $EXIT_FAILURE
    fi
}

check_uv() {
    if command -v uv &> /dev/null; then
        local version=$(uv --version 2>&1)
        print_check "$CHECK_PASS" "uv installed ($version)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "uv not found"
        echo "    → Install: brew install uv"
        return $EXIT_FAILURE
    fi
}

check_zk() {
    if command -v zk &> /dev/null; then
        local version=$(zk --version 2>&1 | head -1)
        print_check "$CHECK_PASS" "zk installed ($version)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "zk not found"
        echo "    → Install: brew install zk"
        return $EXIT_FAILURE
    fi
}

check_sqlite3() {
    if command -v sqlite3 &> /dev/null; then
        local version=$(sqlite3 --version 2>&1 | awk '{print $1}')
        print_check "$CHECK_PASS" "sqlite3 installed (v$version)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_FAIL" "sqlite3 not found"
        echo "    → Install: brew install sqlite3"
        return $EXIT_FAILURE
    fi
}

check_embeddings_table() {
    # Find zk notebook root
    local notebook_root=""

    # Try current directory first
    if [[ -f ".zk/notebook.db" ]]; then
        notebook_root="."
    # Try parent directories
    elif [[ -f "../.zk/notebook.db" ]]; then
        notebook_root=".."
    elif [[ -f "../../.zk/notebook.db" ]]; then
        notebook_root="../.."
    else
        print_check "$CHECK_WARN" "No .zk/notebook.db found in current or parent directories"
        echo "    → Run this from within a zk notebook directory"
        return $EXIT_WARNING
    fi

    local db_path="$notebook_root/.zk/notebook.db"

    if ! command -v sqlite3 &> /dev/null; then
        print_check "$CHECK_WARN" "Cannot verify embeddings table (sqlite3 not available)"
        return $EXIT_WARNING
    fi

    # Check if embeddings table exists
    local has_embeddings=$(sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='embeddings';" 2>/dev/null)

    if [[ -n "$has_embeddings" ]]; then
        local count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM embeddings;" 2>/dev/null)
        print_check "$CHECK_PASS" "Embeddings table exists ($count embeddings)"
        return $EXIT_SUCCESS
    else
        print_check "$CHECK_WARN" "Embeddings table not found, creating..."

        # Create embeddings table
        sqlite3 "$db_path" <<'EOF'
CREATE TABLE IF NOT EXISTS embeddings (
    id INTEGER PRIMARY KEY,
    note_id INTEGER NOT NULL,
    model TEXT NOT NULL,
    embedding BLOB NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_embeddings_note ON embeddings(note_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_model ON embeddings(model);
EOF

        if [[ $? -eq 0 ]]; then
            print_check "$CHECK_PASS" "Embeddings table created successfully"
            return $EXIT_SUCCESS
        else
            print_check "$CHECK_FAIL" "Failed to create embeddings table"
            return $EXIT_FAILURE
        fi
    fi
}

print_config_snippet() {
    echo ""
    echo "=============================="
    echo "Configuration"
    echo "=============================="
    echo ""
    echo "Add the following to your .zk/config.toml:"
    echo ""
    cat "$PLUGIN_ROOT/scripts/zk-config-snippet.toml" | sed "s|PLUGIN_ROOT|$PLUGIN_ROOT|g"
}

main() {
    echo "Commonplace Book Plugin Setup"
    echo "=============================="
    echo ""
    echo "Plugin root: $PLUGIN_ROOT"

    print_section "Dependency Checks"
    check_perl_version && update_status $? || update_status $?
    check_dbi && update_status $? || update_status $?
    check_dbd_sqlite && update_status $? || update_status $?
    check_uv && update_status $? || update_status $?
    check_zk && update_status $? || update_status $?
    check_sqlite3 && update_status $? || update_status $?

    print_section "Database Setup"
    check_embeddings_table && update_status $? || update_status $?

    echo ""
    echo "=============================="
    case $OVERALL_STATUS in
        $EXIT_SUCCESS)
            echo "Status: $CHECK_PASS All checks passed"
            print_config_snippet
            ;;
        $EXIT_WARNING)
            echo "Status: $CHECK_WARN Some warnings detected"
            print_config_snippet
            ;;
        $EXIT_FAILURE)
            echo "Status: $CHECK_FAIL Some checks failed"
            echo ""
            echo "Fix the failures above before continuing."
            ;;
    esac
}

main

exit $OVERALL_STATUS
