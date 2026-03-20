#!/usr/bin/env bash

action_select_manager() {
    clear
    echo -e "${BOLD}${CYAN}  --- Select KernelSU Manager APK ---${RESET}"
    echo ""
    echo -e "  ${DIM}Tip: drag-and-drop an APK onto this terminal and press Enter.${RESET}"
    echo ""

    local apks=()
    while IFS= read -r -d '' f; do
        apks+=("$f")
    done < <(find "$MANAGER_DIR" -maxdepth 1 -name "*.apk" -print0 2>/dev/null | sort -z)

    if [[ ${#apks[@]} -gt 0 ]]; then
        echo "  Stored APKs:"
        local i=1
        for apk in "${apks[@]}"; do
            local sz
            sz="$(wc -c < "$apk" | awk '{printf "%.0fK", $1/1024}')"
            printf "  ${BOLD}%2d)${RESET} %-45s ${DIM}%s${RESET}\\n" \
                "$i" "$(basename "$apk")" "$sz"
            (( i++ ))
        done
        echo ""
    fi

    echo -e "  ${BOLD}p)${RESET} Paste / type APK path"
    if [[ -f "$KSUD_PATH" ]]; then
        echo -e "  ${BOLD}s)${RESET} Skip — keep existing ksud"
    fi
    echo -e "  ${BOLD}b)${RESET} Back"
    echo ""
    read -rp "  Choice (number / p / s / b): " choice

    case "$choice" in
        b|B) return ;;
        s|S)
            if [[ -f "$KSUD_PATH" ]]; then
                log_ok "Keeping existing ksud."; press_enter
            else
                log_warn "No existing ksud found."; press_enter
            fi
            return
            ;;
        p|P|"")
            local raw_path
            read -rp "  APK path: " raw_path

            raw_path="${raw_path//\'/}"
            raw_path="${raw_path//\"/}"
            raw_path="${raw_path/#\~/$HOME}"
            raw_path="$(echo "$raw_path" | xargs)" 
            if [[ ! -f "$raw_path" ]]; then
                log_error "File not found: $raw_path"
                press_enter
                return
            fi

            _copy_and_extract_apk "$raw_path"
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#apks[@]} )); then
                _copy_and_extract_apk "${apks[$((choice-1))]}"
            else
                log_warn "Invalid choice."; press_enter
            fi
            ;;
    esac
}

_copy_and_extract_apk() {
    local src="$1"
    local dest="$MANAGER_DIR/$(basename "$src")"

    if [[ "$src" != "$dest" ]]; then
        echo -e "${DIM}  Copying APK to $MANAGER_DIR ...${RESET}"
        cp "$src" "$dest"
    fi

    extract_ksud_from_apk "$dest"
    _prompt_install_apk "$dest"

    press_enter
}


_prompt_install_apk() {
    local apk="$1"
    echo ""
    read -rp "  Install Manager APK to device via ADB? [y/N]: " yn
    if [[ "$(echo "$yn" | tr '[:upper:]' '[:lower:]')" != "y" ]]; then
        return 0
    fi

    require_tool adb

    echo -e "${DIM}  Running: adb install -r \"$(basename "$apk")\"${RESET}"
    if adb install -r "$apk"; then
        log_ok "Manager APK installed on device."
    else
        log_warn "Install failed — device may not be connected or ADB is unauthorized."
    fi
}


extract_ksud_from_apk() {
    local apk="$1"
    echo ""
    echo -e "${CYAN}Extracting ksud from:${RESET} $(basename "$apk")"

    require_tool unzip
    require_tool strings

    TMPDIR_EXTRACT="$(mktemp -d)"

    local so_entries
    if ! so_entries="$(unzip -Z1 "$apk" 'lib/*/libksud.so' 2>/dev/null)"; then
        # unzip returns error if no files match
        true
    fi

    if [[ -z "$so_entries" ]]; then
        log_error "No libksud.so found in the APK. Is this a KernelSU Manager?"
        return 1
    fi

    local preferred=""
    for abi in "arm64-v8a" "armeabi-v7a" "x86_64" "x86"; do
        if echo "$so_entries" | grep -q "lib/$abi/"; then
            preferred="$(echo "$so_entries" | grep "lib/$abi/" | head -1)"
            break
        fi
    done
    if [[ -z "$preferred" ]]; then
        preferred="$(echo "$so_entries" | head -1)"
    fi

    echo -e "  ${DIM}Extracting: $preferred${RESET}"
    unzip -q "$apk" "$preferred" -d "$TMPDIR_EXTRACT"

    local extracted="$TMPDIR_EXTRACT/$preferred"
    if [[ ! -f "$extracted" ]]; then
        log_error "Extraction failed: $preferred"
        return 1
    fi

    if ! validate_ksud "$extracted"; then
        return 1
    fi

    cp "$extracted" "$KSUD_PATH"
    chmod 755 "$KSUD_PATH"
    log_ok "ksud saved to: $KSUD_PATH"
}

validate_ksud() {
    local bin="$1"
    echo ""
    echo -e "${CYAN}Validating ksud binary...${RESET}"

    local size
    size="$(wc -c < "$bin")"
    echo -e "  ${DIM}Size: ${size} bytes${RESET}"

    echo -e "  ${DIM}Checking for 'late-load' support...${RESET}"
    if strings "$bin" | grep "late-load" > /dev/null; then
        log_ok "'late-load' found — this ksud supports jailbreak root."
    else
        echo ""
        log_warn "'late-load' not found in ksud binary."
        echo -e "${YELLOW}  This version may not support the jailbreak root method.${RESET}"
        echo ""
        read -rp "  Continue anyway? [y/N]: " yn
        if [[ "$(echo "$yn" | tr '[:upper:]' '[:lower:]')" != "y" ]]; then
            return 1
        fi
    fi
}
