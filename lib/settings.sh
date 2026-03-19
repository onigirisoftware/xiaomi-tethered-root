#!/usr/bin/env bash

# --- Persistent Settings ---
setting_get() {
    local key="$1"
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo ""
        return
    fi
    if ! grep -E "^${key}=" "$SETTINGS_FILE" | tail -1 | cut -d'=' -f2-; then
        echo ""
    fi
}

setting_set() {
    local key="$1" value="$2"

    if ! touch "$SETTINGS_FILE" 2>/dev/null; then
        true
    fi

    local tmp
    tmp="$(mktemp)"

    if ! grep -v "^${key}=" "$SETTINGS_FILE" > "$tmp"; then
        true
    fi
    echo "${key}=${value}" >> "$tmp"

    mv "$tmp" "$SETTINGS_FILE"
}

setting_toggle() {
    local key="$1"

    local cur
    cur="$(setting_get "$key")"

    local new
    if [[ "$cur" == "1" ]]; then
        new="0"
    else
        new="1"
    fi

    setting_set "$key" "$new"
    echo "$new"
}

setting_enabled() {
    [[ "$(setting_get "$1")" == "1" ]]
}

# --- Data Dir + Cleanup ---

init_data_dir() {
    mkdir -p "$MANAGER_DIR" "$BINARY_DIR"
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        touch "$SETTINGS_FILE" 2>/dev/null
    fi
}

cleanup() {
    if [[ -n "$TMPDIR_EXTRACT" && -d "$TMPDIR_EXTRACT" ]]; then
        rm -rf "$TMPDIR_EXTRACT"
    fi
}
trap cleanup EXIT
