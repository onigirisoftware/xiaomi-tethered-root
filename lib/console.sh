#!/usr/bin/env bash

# --- Colors ---
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# --- Logging ---

log_info()  { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1" >&2; }
log_fatal() { log_error "$1"; exit 1; }

# --- UI Helpers ---

press_enter() {
    read -rp $'\033[2m  Press Enter to continue...\033[0m'
}

setting_label() {
    if setting_enabled "$1"; then
        echo -e "${GREEN}ON${RESET}"
    else
        echo -e "${DIM}OFF${RESET}"
    fi
}