#!/system/bin/sh

PATH=/system/bin:/vendor/bin:/data/adb/ksu/bin:$PATH
export PATH

# --- Configuration ---

MODULE_DIR="/data/adb/modules"

ZYGISKSU_DIR="$MODULE_DIR/zygisksu"
LSPOSED_DIR="$MODULE_DIR/zygisk_lsposed"

ZYGISK_DEPS="lspd"

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
# --- LSPosed ---
LSPD_DATA_DIR="/data/adb/lspd"
LSPOSED_LOG_DIR="$LSPD_DATA_DIR/log"

launch_lsposed() {
    echo "[*] Starting lsposed..."
    rm -f "$LSPD_DATA_DIR/monitor" "$LSPD_DATA_DIR/lock" 2>/dev/null

    _java_opts="-Djava.class.path=$LSPOSED_DIR/daemon.apk -Xnoimage-dex2oat"
    setsid nsenter -t 1 -m -- /system/bin/sh -c "
        cd $LSPOSED_DIR
        export $BOOTCP
        export $DEX2OAT
        export PATH=$PATH
        exec /system/bin/app_process $_java_opts /system/bin --nice-name=lspd org.lsposed.lspd.Main
    " </dev/null >/dev/null 2>&1 &
    sleep 3

    LSPD_PID=$(find_pid lspd)
    [ -n "$LSPD_PID" ] || die "lspd failed to start"

    sleep 5
    LSPD_PID=$(find_pid lspd)
    [ -n "$LSPD_PID" ] || die "lspd crashed during init"
}

fix_lsposed_permission() {
    chmod 644 "$LSPD_DATA_DIR/monitor" 2>/dev/null
}

ensure_lsposed_running() {
    _retry=${1:-0}
    if [ "$_retry" -ge 3 ]; then
        echo "ERROR: bridge failed after 3 attempts, giving up"
        return 1
    fi

    SS_PID=$(find_pid system_server)
    _bridge=""

    for _i in $(seq 1 60); do
        sleep 1
        _log=$(ls -t "$LSPOSED_LOG_DIR"/verbose_*.log 2>/dev/null | head -1)
        if [ -n "$_log" ]; then
            _bridge=$(grep "binder received" "$_log" 2>/dev/null | grep "$SS_PID" | tail -1)
            if [ -n "$_bridge" ]; then
                return 0
            fi
        fi
    done

    echo "WARNING: bridge not established, retrying (attempt $((_retry + 1))/3)..."
    _log=$(ls -t "$LSPOSED_LOG_DIR"/verbose_*.log 2>/dev/null | head -1)
    [ -n "$_log" ] && tail -15 "$_log"

    kill -9 "$SS_PID"
    sleep 3
    ensure_lsposed_running $((_retry + 1))
}
# --- LSPosed ---


main() {
    check_prerequisites

    kill_zygisk_deps
    read_zygote_env

    inject_zygisk

    echo "[*] Starting zygisk deps..."

    if [ -d "$LSPOSED_DIR" ]; then
        launch_lsposed
    fi

    restart_zygote

    echo "[*] Running pre-fix..."
    if [ -d "$LSPOSED_DIR" ]; then
        echo "[*] Fixing LSPosed..."
        fix_lsposed_permission
    fi

    echo "[+] Waiting 15s for system stability..."
    sleep 15

    echo "[*] Running post-fix..."
    if [ -d "$LSPOSED_DIR" ]; then
        echo "[*] Fixing LSPosed..."
        fix_lsposed_permission
    fi
}

main
echo "[+] Done"
exit 0