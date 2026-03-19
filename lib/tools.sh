#!/usr/bin/env bash

require_tool() {
    if ! command -v "$1" &>/dev/null; then
        log_fatal "'$1' is not installed or not in PATH."
    fi
}
