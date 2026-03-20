#!/usr/bin/env bash

# Paths
DATA_DIR="$SCRIPT_DIR/ksu-data"

MANAGER_DIR="$DATA_DIR/manager"
BINARY_DIR="$DATA_DIR/binary"
KSUD_PATH="$DATA_DIR/binary/ksud"
SETTINGS_FILE="$DATA_DIR/settings"

# Runtime state
MANAGER_APK=""
TMPDIR_EXTRACT=""

# Setting keys
SETTING_ZIGISK_FIX="zygisk_fix"
