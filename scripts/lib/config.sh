#!/bin/bash

require_config_var() {
    local var_name="$1"

    if [ -z "${!var_name:-}" ]; then
        echo "Pflichtwert fehlt in Konfiguration: $var_name"
        return 1
    fi
}

load_configuration() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +a
    else
        echo "ENV-Datei nicht gefunden: $ENV_FILE"
        return 1
    fi

    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        echo "Config-Datei nicht gefunden: $CONFIG_FILE"
        return 1
    fi

    EXCLUDED_STACK_DIRS=("${EXCLUDED_STACK_DIRS[@]:-}")
    EXCLUDED_CONTAINER_NAMES=("${EXCLUDED_CONTAINER_NAMES[@]:-}")
    RESTIC_TAG="${RESTIC_TAG:-docker-backup}"
    KEEP_DAILY="${KEEP_DAILY:-7}"
    KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
    KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

    require_config_var "BACKUP_ROOT" || return 1
    require_config_var "DOCKER_DIR" || return 1
    require_config_var "MYSQL_CONTAINER" || return 1

    RESTIC_AUTH_ARGS=()
    if [ -n "${RESTIC_PASSWORD_FILE:-}" ]; then
        RESTIC_AUTH_ARGS=(--password-file "$RESTIC_PASSWORD_FILE")
    elif [ -n "${RESTIC_PASSWORD:-}" ]; then
        RESTIC_AUTH_ARGS=()
    else
        echo "Restic Passwort fehlt: Bitte RESTIC_PASSWORD_FILE (backup.conf) oder RESTIC_PASSWORD (.env) setzen."
        return 1
    fi

    DATE="$(date +%F_%H-%M)"
    TARGET_DIR="$BACKUP_ROOT/$DATE"
    LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"
    LOG_FILE="$LOG_DIR/docker-backup-$DATE.log"

    export RCLONE_CONFIG="${RCLONE_CONFIG:-/home/matthi/.config/rclone/rclone.conf}"
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-rclone:1blu:restic-repo}"
}
