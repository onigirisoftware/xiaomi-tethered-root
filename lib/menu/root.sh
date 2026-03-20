#!/usr/bin/env bash

# --- Constants ---
FIX_SCRIPT_DIR="$SCRIPT_DIR/scripts"
FIX_ZIGISK_SCRIPT_NAME="fix_zygisk.sh"

REMOTE_DIR="/data/local/tmp"

REMOTE_KSUD="$REMOTE_DIR/ksud"
REMOTE_LOG="$REMOTE_DIR/onigiri_software.log"

action_root() {
    if [[ ! -f "$KSUD_PATH" ]]; then
        log_warn "No ksud binary — select a Manager APK first."
        press_enter
        action_select_manager
        
        if [[ ! -f "$KSUD_PATH" ]]; then
            log_error "Still no ksud. Returning to menu."
            press_enter
            return
        fi
    fi

    clear
    echo -e "${BOLD}${GREEN}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║            Starting Root...                  ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    require_tool adb
    require_tool fastboot

    _ensure_fastboot

    _boot_with_permissive_selinux

    _waiting_device_ready
    _verify_permissive_selinux

    _push_ksud_binary
    _do_jailbreak_root

    if setting_enabled "$SETTING_ZIGISK_FIX"; then
        _do_zigisk_fix
    fi

    _wait_for_su_permission

    _do_cleanup_trace
    _done
}

# --- Steps ---

_ensure_fastboot() {
    if adb get-state &>/dev/null; then
        log_info "Device found via ADB..."
        adb reboot bootloader
    else
        log_info "No ADB device found — assuming phone is already in fastboot."
    fi

    log_info "Waiting for fastboot device..."

    for i in {1..60}; do
        if fastboot devices 2>/dev/null | grep -q "fastboot"; then
            log_ok "Fastboot device ready."
            return 0
        fi
        sleep 1
    done

    log_fatal "Timed out after 60s. Check USB connection."
}

_boot_with_permissive_selinux() {
    log_info "Setting SELinux to permissive..."

    if fastboot oem set-gpu-preemption 0 androidboot.selinux=permissive >/dev/null 2>&1; then
        log_ok "Sent permissive boot command."
    else
        log_fatal "set SELinux to permissive command failed."
    fi

    if ! fastboot continue >/dev/null 2>&1; then
        log_fatal "fastboot continue failed."
    fi

    log_ok "Phone is rebooting..."
}

_waiting_device_ready() {
    log_info "Waiting for ADB..."
    adb wait-for-device

    log_ok "ADB connected."
    wait_for_unlock
}

_verify_permissive_selinux() {
    log_info "Verifying SELinux state..."

    local state
    state="$(adb_shell getenforce)"
    state="${state//$'\r'/}"
    
    if [[ "$state" != "Permissive" ]]; then
        log_fatal "SELinux is '$state', expected Permissive. Boot command may have failed."
    fi

    log_ok "SELinux is Permissive."
}

_push_ksud_binary() {
    log_info "Pushing ksud to /data/local/tmp..."
    if ! adb push "$KSUD_PATH" "$REMOTE_KSUD" >/dev/null 2>&1; then
        log_fatal "Push failed. Check ADB connection."
    fi
    adb_shell "chmod 755 \"$REMOTE_KSUD\"" >/dev/null
    log_ok "ksud pushed and marked executable."
}

_do_jailbreak_root() {
    log_info "Triggering KernelSU late-load..."
    if hyperos_exec "$REMOTE_KSUD" "late-load" "$REMOTE_LOG"; then
        log_ok "late-load command sent."
    else
        log_warn "exec may have failed — watch the next steps."
    fi
}

_do_zigisk_fix() {
    log_info "Applying Zigisk Fix..."

    if ! adb push "$FIX_SCRIPT_DIR/$FIX_ZIGISK_SCRIPT_NAME" "$REMOTE_DIR/$FIX_ZIGISK_SCRIPT_NAME" >/dev/null 2>&1; then
        log_fatal "Push failed. Check ADB connection."
    fi


    adb_shell "chmod 755 \"$REMOTE_DIR/$FIX_ZIGISK_SCRIPT_NAME\"" >/dev/null
    log_ok "Zigisk Fix pushed and marked executable."

    adb_shell "su -c \"$REMOTE_DIR/$FIX_ZIGISK_SCRIPT_NAME\""
    log_ok "Zigisk Fix applied."
}

_wait_for_su_permission() {
    log_info "Waiting for Shell Root permission..."
    echo ""
    echo -e "${YELLOW}  1. Open the KernelSU Manager app on your phone"
    echo -e "  2. Go to the Superuser tab"
    echo -e "  3. Grant Root to 'Shell' (com.android.shell)${RESET}"
    echo -e "  ${DIM}(Waiting for SU access...)${RESET}"
    echo ""

    until adb_shell su -c id 2>/dev/null | grep -q "uid=0(root)"; do
        sleep 2
    done

    log_ok "Shell Root permission granted!"
}

_do_cleanup_trace() {
    log_info "Cleaning up trace and restoring SELinux..."

    adb_shell "su -c \"setenforce 1\"" >/dev/null
    adb_shell "su -c \"resetprop -n ro.boot.selinux enforcing\"" >/dev/null
    
    adb_shell "rm $REMOTE_KSUD" >/dev/null || true
    adb_shell "rm $REMOTE_LOG" >/dev/null || true
    adb_shell "rm $REMOTE_DIR/$FIX_ZIGISK_SCRIPT_NAME" >/dev/null || true
}

_done() {
    echo ""
    echo -e "${GREEN}${BOLD}=================================================="
    echo "  Done! Temporary root is active."
    echo -e "==================================================${RESET}"
    echo ""
    echo "  - Root is lost on reboot — run this again to restore it"
    echo ""
    press_enter
}
