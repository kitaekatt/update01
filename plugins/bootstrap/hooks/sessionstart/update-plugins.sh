#!/usr/bin/env bash
# update-plugins.sh — Force plugin cache refresh
#
# Runs `claude plugin update` for each managed plugin to ensure
# the local cache reflects the latest marketplace state.
#
# Output: JSON to stdout
# Exit:   0 = success (even if individual updates fail — non-blocking)

# --- JSON Output Helpers ---
if ! declare -f json_escape >/dev/null 2>&1; then
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}
fi

_emit_up_success() {
    local details="$1"
    cat <<EOF
{"status": "ok", "step": "update_plugins", "details": "$(json_escape "$details")"}
EOF
}

_emit_up_error() {
    local message="$1"
    cat <<EOF
{"status": "error", "step": "update_plugins", "message": "$(json_escape "$message")"}
EOF
}

_detect_plugin_scope() {
    local plugin="$1"
    local installed
    installed="$(cygpath -w "$HOME" 2>/dev/null || echo "$HOME")/.claude/plugins/installed_plugins.json"
    [ -f "$installed" ] || return 1
    python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
entries = d.get('plugins', {}).get(sys.argv[2], [])
if isinstance(entries, list) and entries:
    print(entries[0].get('scope', 'user'))
elif isinstance(entries, dict):
    print(entries.get('scope', 'user'))
else:
    print('user')
" "$installed" "$plugin" 2>/dev/null
}

update_plugins() {
    local results=()
    local plugins=(
        "unreal-kit@plugins-kit"
    )

    for plugin in "${plugins[@]}"; do
        local scope
        scope="$(_detect_plugin_scope "$plugin")"
        local output rc
        output=$(claude plugin update --scope "$scope" "$plugin" 2>&1) && rc=0 || rc=$?
        if [ "$rc" -eq 0 ]; then
            results+=("$plugin: updated")
        else
            local trimmed
            trimmed="$(printf '%s' "$output" | head -1 | cut -c1-80)"
            results+=("$plugin: failed(rc=$rc${trimmed:+: $trimmed})")
        fi
    done

    local detail
    detail="$(IFS=', '; printf '%s' "${results[*]}")"
    _emit_up_success "$detail"
    return 0
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_plugins
fi
