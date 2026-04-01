#!/bin/bash
set -Eeuo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENV_FILE="/opt/docker-backup/.env"
CONFIG_FILE="/srv/restic/backup.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    DEFAULT_LOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/log"
else
    DEFAULT_LOG_DIR="$SCRIPT_DIR/log"
fi

# shellcheck disable=SC1090
source "$LIB_DIR/common.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/config.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/docker.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/backup.sh"

LOCK_FILE="/var/lock/docker-backup.lock"
ACTIVE_STACK_FILE=""
BACKUP_OK=0
START_TS="$(date +%s)"
START_TIME="$(date '+%F %T')"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

cleanup() {
    local exit_code=$?
    local end_ts end_time duration backup_size

    end_ts="$(date +%s)"
    end_time="$(date '+%F %T')"
    duration="$(format_duration $((end_ts - START_TS)))"

    docker_restart_stacks_from_file "$ACTIVE_STACK_FILE"

    if [ -n "${ACTIVE_STACK_FILE:-}" ] && [ -f "$ACTIVE_STACK_FILE" ]; then
        rm -f "$ACTIVE_STACK_FILE"
    fi

    if [ "$exit_code" -eq 0 ] && [ "$BACKUP_OK" -eq 1 ]; then
        backup_size="$(du -sh "$TARGET_DIR" 2>/dev/null | awk '{print $1}')"
        send_gotify \
            "Backup erfolgreich" \
            "Host: $HOSTNAME
Start: $START_TIME
Ende: $end_time
Dauer: $duration
Ziel: $TARGET_DIR
Groesse: ${backup_size:-unbekannt}" \
            "${GOTIFY_PRIORITY_SUCCESS:-4}"
        log "=== Backup abgeschlossen: $DATE ==="
    else
        send_gotify \
            "Backup FEHLER" \
            "Host: $HOSTNAME
Start: $START_TIME
Fehlerzeit: $end_time
Dauer bis Fehler: $duration
Letztes Ziel: $TARGET_DIR
Bitte Journal/Log pruefen." \
            "${GOTIFY_PRIORITY_ERROR:-8}"
        log "=== Backup fehlgeschlagen: $DATE ==="
    fi
}

load_configuration
init_logging

trap on_error ERR
trap cleanup EXIT

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "Ein anderes Backup laeuft bereits - Abbruch"
    send_gotify \
        "Backup uebersprungen" \
        "Host: $HOSTNAME
Start: $START_TIME
Grund: Es laeuft bereits ein anderes Backup." \
        "${GOTIFY_PRIORITY_ERROR:-8}"
    exit 1
fi

send_gotify \
    "Backup gestartet" \
    "Host: $HOSTNAME
Start: $START_TIME
Ziel: $TARGET_DIR" \
    "${GOTIFY_PRIORITY_SUCCESS:-4}"

mkdir -p "$TARGET_DIR"
ACTIVE_STACK_FILE="$(mktemp /tmp/active_stacks.XXXXXX)"

log "=== Backup gestartet: $DATE ==="

log "--- Erfasse aktive Docker Compose Projekte ---"
ACTIVE_STACK_DIRS="$(docker_detect_active_stack_dirs)"
printf '%s\n' "$ACTIVE_STACK_DIRS" > "$ACTIVE_STACK_FILE"

log "Aktive Stacks:"
cat "$ACTIVE_STACK_FILE"
echo

backup_vaultwarden
backup_mysql_dump
docker_stop_stacks_from_file "$ACTIVE_STACK_FILE"
backup_copy_docker_dirs
backup_run_restic
backup_prune_restic

BACKUP_OK=1
