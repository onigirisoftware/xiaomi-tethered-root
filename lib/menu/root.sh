#!/usr/bin/env bash

# --- Constants ---
REMOTE_KSUD="/data/local/tmp/ksud"
REMOTE_LOG="/data/local/tmp/onigiri_software.log"

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

    if setting_enabled "$SETTING_LSPOSED_FIX"; then
        _do_lsposed_fix
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

    local timeout=60 elapsed=0
    until fastboot devices 2>/dev/null | grep -q "fastboot"; do
        sleep 1
        (( elapsed++ ))
        if (( elapsed >= timeout )); then
            log_fatal "Timed out after ${timeout}s. Check USB connection."
        fi
    done

    log_ok "Fastboot device ready."
}

_boot_with_permissive_selinux() {
    log_info "Setting SELinux to permissive..."

    if fastboot oem set-gpu-preemption 0 androidboot.selinux=permissive; then
        log_ok "Sent permissive boot command."
    else
        log_fatal "set SELinux to permissive command failed."
    fi

    if ! fastboot continue; then
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
    if ! adb push "$KSUD_PATH" "$REMOTE_KSUD"; then
        log_fatal "Push failed. Check ADB connection."
    fi
    adb_shell chmod 755 "$REMOTE_KSUD"
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

_do_lsposed_fix() {
    log_info "Applying LSPosed fix..."
    # TODO: implement LSPosed fix
    log_warn "LSPosed fix: not implemented yet."
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

    adb_shell "su -c \"setenforce 1\""
    adb_shell "su -c \"resetprop -n ro.boot.selinux enforcing\""
    
    adb_shell "rm $REMOTE_KSUD 2>/dev/null" || true
    adb_shell "rm $REMOTE_LOG 2>/dev/null" || true
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
