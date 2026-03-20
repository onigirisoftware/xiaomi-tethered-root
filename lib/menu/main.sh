#!/usr/bin/env bash

main_menu() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}"
        echo "  ╔══════════════════════════════════════════════╗"
        echo "  ║   KernelSU Tethered Root Tool                ║"
        echo "  ║   Xiaomi Qualcomm · Onigiri Software         ║"
        echo "  ╚══════════════════════════════════════════════╝"
        echo -e "${RESET}"

        _print_status

        echo ""
        echo -e "  ${BOLD}1)${RESET}  Root device"
        echo -e "  ${BOLD}2)${RESET}  Select Manager APK"
        echo -e "  ${BOLD}3)${RESET}  Settings"
        echo -e "  ${BOLD}q)${RESET}  Quit"
        echo ""
        read -rp "  Choice: " choice

        case "$choice" in
            1) action_root ;;
            2) action_select_manager ;;
            3) menu_settings ;;
            q|Q) echo "Bye."; exit 0 ;;
            *) log_warn "Invalid option: '$choice'"; sleep 1 ;;
        esac
    done
}


_print_status() {
    local ksud_label lsposed_label

    if [[ -f "$KSUD_PATH" ]]; then
        local sz
        sz="$(wc -c < "$KSUD_PATH")"
        ksud_label="${GREEN}ksud ${DIM}(${sz}B )${RESET}"
    else
        ksud_label="${DIM}none${RESET}"
    fi

    lsposed_label="$(setting_label "$SETTING_LSPOSED_FIX")"

    echo -e "  ksud                : $ksud_label"
    echo -e "  Enable LSPosed fix  : $lsposed_label"
}
