#!/usr/bin/env bash
# ABOUTME: Installs a stable zk-search wrapper to a bin directory
# ABOUTME: The wrapper discovers the current plugin path dynamically

set -euo pipefail

WRAPPER_DIR="${ZK_SEARCH_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
WRAPPER_PATH="${WRAPPER_DIR}/zk-search"

mkdir -p "$WRAPPER_DIR"

cat > "$WRAPPER_PATH" <<'WRAPPER'
#!/usr/bin/env bash
# ABOUTME: Stable wrapper for commonplacebook plugin's zk-search
# ABOUTME: Discovers current plugin install path dynamically

PLUGIN_BIN=$(find "${HOME}/.claude/plugins/cache/perigrin-marketplace/commonplacebook" \
    -name zk-search -path '*/bin/*' 2>/dev/null | head -1)

if [[ -z "$PLUGIN_BIN" ]]; then
    echo "Error: commonplacebook plugin not found. Install with:" >&2
    echo "  /plugin marketplace add perigrin/claude-plugins-marketplace" >&2
    echo "  /plugin install commonplacebook@perigrin-marketplace" >&2
    exit 1
fi

exec perl "$PLUGIN_BIN" "$@"
WRAPPER

chmod +x "$WRAPPER_PATH"
echo "Installed zk-search wrapper to $WRAPPER_PATH"
