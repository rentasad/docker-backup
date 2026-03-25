#!/bin/bash
set -Eeuo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENV_FILE="/srv/restic/.env"
CONFIG_FILE="/srv/restic/backup.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    DEFAULT_LOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/log"
else
    DEFAULT_LOG_DIR="$SCRIPT_DIR/log"
fi

LOCK_FILE="/var/lock/docker-backup.lock"
ACTIVE_STACK_FILE=""
BACKUP_OK=0
START_TS="$(date +%s)"
START_TIME="$(date '+%F %T')"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

export RCLONE_CONFIG="/home/matthi/.config/rclone/rclone.conf"
export RESTIC_REPOSITORY="rclone:1blu:restic-repo"
#
is_excluded_stack() {
    local dir="$1"
    local container_name=""

    for excluded in "${EXCLUDED_STACK_DIRS[@]}"; do
        if [ "$dir" = "$excluded" ]; then
            log "Exclude ueber Working Dir: $dir"
            return 0
        fi
    done

    while read -r container_name; do
        [ -z "$container_name" ] && continue

        for excluded_container in "${EXCLUDED_CONTAINER_NAMES[@]}"; do
            if [ "$container_name" = "$excluded_container" ]; then
                log "Exclude ueber Containername: $container_name (Stack: $dir)"
                return 0
            fi
        done
    done < <(
        docker ps -a \
            --filter "label=com.docker.compose.project.working_dir=$dir" \
            --format '{{.Names}}'
    )

    return 1
}

# === .env laden ===
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "ENV-Datei nicht gefunden: $ENV_FILE"
    exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "Config-Datei nicht gefunden: $CONFIG_FILE"
    exit 1
fi

# Defaults fuer optionale Ausschluesse in backup.conf
EXCLUDED_STACK_DIRS=("${EXCLUDED_STACK_DIRS[@]:-}")
EXCLUDED_CONTAINER_NAMES=("${EXCLUDED_CONTAINER_NAMES[@]:-}")
RESTIC_TAG="${RESTIC_TAG:-docker-backup}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

RESTIC_AUTH_ARGS=()
if [ -n "${RESTIC_PASSWORD_FILE:-}" ]; then
    RESTIC_AUTH_ARGS=(--password-file "$RESTIC_PASSWORD_FILE")
elif [ -n "${RESTIC_PASSWORD:-}" ]; then
    RESTIC_AUTH_ARGS=()
else
    echo "Restic Passwort fehlt: Bitte RESTIC_PASSWORD_FILE (backup.conf) oder RESTIC_PASSWORD (.env) setzen."
    exit 1
fi

DATE="$(date +%F_%H-%M)"
TARGET_DIR="$BACKUP_ROOT/$DATE"
LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"
LOG_FILE="$LOG_DIR/docker-backup-$DATE.log"

# === Hilfsfunktionen ===
log() {
    echo "[$(date '+%F %T')] $*"
}

on_error() {
    local exit_code=$?
    log "FEHLER: Kommando fehlgeschlagen (Exit $exit_code) in Zeile ${BASH_LINENO[0]}: ${BASH_COMMAND}"
}
trap on_error ERR

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

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
log "Log-Datei: $LOG_FILE"

restart_stacks() {
    if [ -z "${ACTIVE_STACK_FILE:-}" ] || [ ! -f "$ACTIVE_STACK_FILE" ]; then
        return 0
    fi

    log "--- Starte vorher aktive Docker Compose Stacks ---"

    while read -r DIR; do
        [ -z "$DIR" ] && continue
    
        if is_excluded_stack "$DIR"; then
            log "Ueberspringe ausgeschlossenen Stack in $DIR"
            continue
        fi
            
        if [ -f "$DIR/docker-compose.yml" ]; then
            echo "Starte Stack in $DIR"
            docker compose -f "$DIR/docker-compose.yml" up -d
        elif [ -f "$DIR/compose.yml" ]; then
            echo "Starte Stack in $DIR"
            docker compose -f "$DIR/compose.yml" up -d
        fi
    done < "$ACTIVE_STACK_FILE"
}

cleanup() {
    local exit_code=$?
    local end_ts end_time duration backup_size

    end_ts="$(date +%s)"
    end_time="$(date '+%F %T')"
    duration="$(format_duration $((end_ts - START_TS)))"

    restart_stacks

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

trap cleanup EXIT

# === globales Lock gegen parallele Läufe ===
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "Ein anderes Backup läuft bereits - Abbruch"
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

# 1. Aktive Docker-Compose-Projekte erfassen
log "--- Erfasse aktive Docker Compose Projekte ---"

ACTIVE_STACK_DIRS="$(
    docker ps --format '{{.ID}}' | while read -r CID; do
        docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$CID" 2>/dev/null
    done | sort -u | grep -v '^$' || true
)"

printf '%s\n' "$ACTIVE_STACK_DIRS" > "$ACTIVE_STACK_FILE"

log "Aktive Stacks:"
cat "$ACTIVE_STACK_FILE"
echo

# 2. Vaultwarden Backup
log "--- Vaultwarden Backup ---"

VW_DIR="$DOCKER_DIR/apps/vaultwarden"
VW_COMPOSE="$VW_DIR/docker-compose.yml"

if [ -f "$VW_COMPOSE" ]; then
    mkdir -p "$VW_DIR/backup"

    (
        flock -n 9 || {
            log "Vaultwarden-Backup läuft bereits - überspringe manuellen Lauf"
            exit 0
        }

        docker compose -f "$VW_COMPOSE" run --rm --no-deps vaultwarden-backup manual
    ) 9>/tmp/vaultwarden-backup.lock

    mkdir -p "$TARGET_DIR/vaultwarden"
    cp -a "$VW_DIR/backup/." "$TARGET_DIR/vaultwarden/"
else
    log "Vaultwarden Compose-Datei nicht gefunden - überspringe Vaultwarden-Backup"
fi

# 3. MySQL Dump
log "--- MySQL Dump ---"

if docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
    docker exec "$MYSQL_CONTAINER" \
        mysqldump \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        | gzip > "$TARGET_DIR/mysql.sql.gz"

    log "MySQL Dump erstellt: $TARGET_DIR/mysql.sql.gz"
else
    log "MySQL Container nicht gefunden - überspringe MySQL Backup"
fi

# 4. Nur vorher aktive Docker Compose Stacks stoppen
log "--- Stoppe vorher aktive Docker Compose Stacks ---"

while read -r DIR; do
    [ -z "$DIR" ] && continue

    if is_excluded_stack "$DIR"; then
        echo "Ueberspringe ausgeschlossenen Stack in $DIR"
        continue
    fi

    if [ -f "$DIR/docker-compose.yml" ]; then
        echo "Stoppe Stack in $DIR"
        docker compose -f "$DIR/docker-compose.yml" down || true
    elif [ -f "$DIR/compose.yml" ]; then
        echo "Stoppe Stack in $DIR"
        docker compose -f "$DIR/compose.yml" down || true
    fi
done < "$ACTIVE_STACK_FILE"

# 5. Docker-Verzeichnisse sichern
log "--- Kopiere Docker-Verzeichnisse ---"
mkdir -p "$TARGET_DIR/docker"

if command -v pv >/dev/null 2>&1; then
    log "Kopiere mit Fortschrittsanzeige (pv)"
    COPY_SIZE_BYTES="$(du -sb "$DOCKER_DIR" 2>/dev/null | awk '{print $1}')"

    if [ -n "${COPY_SIZE_BYTES:-}" ]; then
        tar -C "$DOCKER_DIR" -cf - . \
            | pv -f -pterb -s "$COPY_SIZE_BYTES" \
            | tar -C "$TARGET_DIR/docker" -xpf -
    else
        tar -C "$DOCKER_DIR" -cf - . \
            | pv -f -pterb \
            | tar -C "$TARGET_DIR/docker" -xpf -
    fi
else
    log "pv nicht gefunden, kopiere ohne Fortschrittsanzeige"
    cp -a "$DOCKER_DIR/." "$TARGET_DIR/docker/"
fi

# 6. Restic Backup
log "--- Restic Backup ---"
restic -r "$RESTIC_REPOSITORY" \
    "${RESTIC_AUTH_ARGS[@]}" \
    backup "$TARGET_DIR" \
    --tag "$RESTIC_TAG" \
    --verbose

# 7. Alte Snapshots aufräumen
log "--- Restic Aufräumen ---"
restic -r "$RESTIC_REPOSITORY" \
    "${RESTIC_AUTH_ARGS[@]}" \
    forget --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune

BACKUP_OK=1
