#!/system/bin/sh

PATH=/system/bin:/vendor/bin:/data/adb/ksu/bin:$PATH
export PATH

# --- Configuration ---

MODULE_DIR="/data/adb/modules"

ZYGISKSU_DIR="$MODULE_DIR/zygisksu"

ZYGISK_DEPS=""

# --- Configuration ---

# --- Variable ----
BOOTCP=""
DEX2OAT=""
# --- Variable ----


# --- Helper ---
die() { echo "ERROR: $*"; exit 1; }

find_pid() {
    ps -A -o PID,NAME 2>/dev/null | grep "$1" | awk '{print $1}' | head -1
}

kill_by_name() {
    _k=0
    for _pid in $(ps -A -o PID,NAME 2>/dev/null | grep "$1" | awk '{print $1}'); do
        kill -9 "$_pid" 2>/dev/null && echo "  [*] Killed $1 PID=$_pid" && _k=$((_k+1))
    done
    echo "$_k"
}
# --- Helper ---

check_prerequisites() {
    [ -d "$ZYGISKSU_DIR" ] || die "$ZYGISKSU_DIR not found"
    [ -f "$ZYGISKSU_DIR/bin/zygiskd" ] || die "$ZYGISKSU_DIR/bin/zygiskd not found"
}

kill_zygisk_deps() {
    echo "[*] Killing zygisk deps..."

    _total=0
    for _name in $ZYGISK_DEPS; do
        _total=$((_total + $(kill_by_name "$_name")))
    done

    [ "$_total" -gt 0 ] && sleep 1
    sleep 1
}

read_zygote_env() {
    echo "[*] Reading zygote64 env..."

    ZPID=$(find_pid zygote64)
    [ -z "$ZPID" ] && die "zygote64 not found"

    BOOTCP=$(cat /proc/$ZPID/environ 2>/dev/null | tr '\0' '\n' | grep '^BOOTCLASSPATH=' | head -1)
    DEX2OAT=$(cat /proc/$ZPID/environ 2>/dev/null | tr '\0' '\n' | grep '^DEX2OATBOOTCLASSPATH=' | head -1)

    [ -z "$BOOTCP" ] && die "BOOTCLASSPATH unreadable"
}

inject_zygisk() {
    cd "$ZYGISKSU_DIR" || die "cannot enter: $ZYGISKSU_DIR"

    echo "[*] Starting zygiskd daemon..."
    ./bin/zygiskd daemon >/dev/null 2>&1 &
    sleep 3

    echo "[*] Starting zygiskd service-stage..."
    ./bin/zygiskd service-stage >/dev/null 2>&1 &
    sleep 7
}

restart_zygote() {
    OLD_SS_PID=$(find_pid system_server)
    ZPID=$(find_pid zygote64)

    echo "[*] Killing zygote64 PID=$ZPID..."
    kill -9 "$ZPID"

    if [ -n "$OLD_SS_PID" ]; then
        echo "[+] Waiting old system_server PID=$OLD_SS_PID to die..."
        for i in $(seq 1 15); do
            sleep 1
        kill -0 "$OLD_SS_PID" 2>/dev/null || break
        done
    fi

    echo "[+] Waiting new system_server..."
    for i in $(seq 1 30); do
        sleep 1
        NEW_SS_PID=$(find_pid system_server)
        if [ -n "$NEW_SS_PID" ] && [ "$NEW_SS_PID" != "$OLD_SS_PID" ]; then
            echo "[+] system_server PID=$NEW_SS_PID (after ${i}s)"
            return 0
        fi
    done

    die "new system_server did not start"
}

main() {
    check_prerequisites

    kill_zygisk_deps
    read_zygote_env

    inject_zygisk

    echo "[*] Starting zygisk deps..."

    restart_zygote
    echo "[+] Waiting 15s for system stability..."
    sleep 15
}

main
echo "[+] Done"
exit 0
