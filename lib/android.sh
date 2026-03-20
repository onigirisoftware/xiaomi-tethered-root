#!/usr/bin/env bash

adb_shell() {
    adb shell "$@" 2>/dev/null
}

hyperos_exec() {
    local command="$1"
    local args="$2"
    local output="$3"

    adb_shell "service call miui.mqsas.IMQSNative 21 i32 1 s16 \"$command\" i32 1 s16 \"$args\" s16 \"$output\" i32 60" >/dev/null
}

wait_for_unlock() {
    echo -e "${YELLOW}[@] Waiting for screen unlock...${RESET}"
    until adb_shell test -d /sdcard/Android; do
        sleep 1
    done
    log_ok "Screen unlocked."
}
