#!/bin/bash
# Nutzt die Backup-Routine von VaultVarden und erzeugt einen DB-Dump
backup_vaultwarden() {
    local vw_dir="$DOCKER_DIR/apps/vaultwarden"
    local vw_compose="$vw_dir/docker-compose.yml"

    log "--- Vaultwarden Backup ---"

    if [ -f "$vw_compose" ]; then
        mkdir -p "$vw_dir/backup"

        (
            flock -n 9 || {
                log "Vaultwarden-Backup laeuft bereits - ueberspringe manuellen Lauf"
                exit 0
            }

            docker compose -f "$vw_compose" run --rm --no-deps vaultwarden-backup manual
        ) 9>/tmp/vaultwarden-backup.lock

        mkdir -p "$TARGET_DIR/vaultwarden"
        cp -a "$vw_dir/backup/." "$TARGET_DIR/vaultwarden/"
    else
        log "Vaultwarden Compose-Datei nicht gefunden - ueberspringe Vaultwarden-Backup"
    fi
}

backup_mysql_dump() {
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
        log "MySQL Container nicht gefunden - ueberspringe MySQL Backup"
    fi
}

backup_copy_docker_dirs() {
    log "--- Kopiere Docker-Verzeichnisse ---"
    mkdir -p "$TARGET_DIR/docker"

    if command -v pv >/dev/null 2>&1; then
        log "Kopiere mit Fortschrittsanzeige (pv)"
        local copy_size_bytes
        copy_size_bytes="$(du -sb "$DOCKER_DIR" 2>/dev/null | awk '{print $1}')"

        if [ -n "${copy_size_bytes:-}" ]; then
            tar -C "$DOCKER_DIR" -cf - . \
                | pv -f -pterb -s "$copy_size_bytes" \
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
}

backup_run_restic() {
    log "--- Restic Backup ---"
    restic -r "$RESTIC_REPOSITORY" \
        "${RESTIC_AUTH_ARGS[@]}" \
        backup "$TARGET_DIR" \
        --tag "$RESTIC_TAG" \
        --verbose
}

backup_prune_restic() {
    log "--- Restic Aufraeumen ---"
    restic -r "$RESTIC_REPOSITORY" \
        "${RESTIC_AUTH_ARGS[@]}" \
        forget --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune
}
