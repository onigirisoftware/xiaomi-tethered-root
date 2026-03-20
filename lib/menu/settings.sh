#!/usr/bin/env bash

menu_settings() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}"
        echo "  ╔══════════════════════════════╗"
        echo "  ║         Settings             ║"
        echo "  ╚══════════════════════════════╝"
        echo -e "${RESET}"
        echo -e "  ${BOLD}1)${RESET}  Zigisk Fix          $(setting_label "$SETTING_ZIGISK_FIX")"
        echo -e "  ${BOLD}2)${RESET}  Open data folder     ${DIM}($DATA_DIR)${RESET}"
        echo -e "  ${BOLD}b)${RESET}  Back"
        echo ""
        read -rp "  Choice: " choice

        case "$choice" in
            1) _settings_toggle_zigisk_fix ;;
            2) _settings_open_data_folder ;;
            b|B) return ;;
            *) log_warn "Invalid option: '$choice'"; sleep 1 ;;
        esac
    done
}

_settings_toggle_zigisk_fix() {
    local new
    new="$(setting_toggle "$SETTING_ZIGISK_FIX")"
    if [[ "$new" == "1" ]]; then
        log_ok "Zigisk Fix enabled."
    else
        log_warn "Zigisk Fix disabled."
    fi
    sleep 1
}

_settings_open_data_folder() {
    clear
    echo -e "${BOLD}${MAGENTA}  --- Data Folder ---${RESET}"
    echo ""
    echo -e "  Path: ${CYAN}$DATA_DIR${RESET}"
    echo ""
    echo "  Manager APKs:"
    if ! ls -lh "$MANAGER_DIR" 2>/dev/null | sed 's/^/    /'; then
        echo -e "${DIM}    (empty)${RESET}"
    fi
    echo ""
    echo "  ksud Binaries:"
    if ! ls -lh "$BINARY_DIR" 2>/dev/null | sed 's/^/    /'; then
        echo -e "${DIM}    (empty)${RESET}"
    fi
    echo ""
    echo "  Settings:"
    if ! cat "$SETTINGS_FILE" 2>/dev/null | sed 's/^/    /'; then
        echo -e "${DIM}    (empty)${RESET}"
    fi
    echo ""

    if command -v xdg-open &>/dev/null; then
        xdg-open "$DATA_DIR" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$DATA_DIR"
    fi

    press_enter
}
