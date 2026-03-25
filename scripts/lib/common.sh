#!/bin/bash

log() {
    echo "[$(date '+%F %T')] $*"
}

format_duration() {
    local total="$1"
    local h=$((total / 3600))
    local m=$(((total % 3600) / 60))
    local s=$((total % 60))

    if [ "$h" -gt 0 ]; then
        printf '%dh %02dm %02ds' "$h" "$m" "$s"
    elif [ "$m" -gt 0 ]; then
        printf '%dm %02ds' "$m" "$s"
    else
        printf '%ds' "$s"
    fi
}

send_gotify() {
    local title="$1"
    local message="$2"
    local priority="${3:-5}"

    if [ -z "${GOTIFY_URL:-}" ] || [ -z "${GOTIFY_TOKEN:-}" ]; then
        return 0
    fi

    curl -fsS \
        -F "title=$title" \
        -F "message=$message" \
        -F "priority=$priority" \
        "${GOTIFY_URL}?token=${GOTIFY_TOKEN}" \
        >/dev/null || true
}

init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    log "Log-Datei: $LOG_FILE"
}

on_error() {
    local exit_code=$?
    log "FEHLER: Kommando fehlgeschlagen (Exit $exit_code) in Zeile ${BASH_LINENO[0]}: ${BASH_COMMAND}"
}
