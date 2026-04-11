#!/bin/bash

# Nutzt die Backup-Routine von VaultVarden und erzeugt einen DB-Dump.
# Erwartet, dass Vaultwarden als Docker Compose Projekt existiert.
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

# Ermittelt den freien Speicherplatz am angegebenen Pfad
get_free_space_local() {
    local path="$1"
    df -h "$path" | awk 'NR==2 {print $4}'
}

# Ermittelt den freien Speicherplatz auf dem Rclone-Remote
get_free_space_rclone() {
    local remote="$1"
    # Extrahiere den Remote-Namen aus restic-Stil "rclone:remote:path"
    local rclone_remote
    rclone_remote=$(echo "$remote" | sed 's/^rclone://;s/:.*$//')
    
    if [ -n "$rclone_remote" ]; then
        rclone about "${rclone_remote}:" --json 2>/dev/null | grep -o '"free":[0-9]*' | grep -o '[0-9]*' | awk '{ sum=$1 ; hum[1024**4]="TB";hum[1024**3]="GB";hum[1024**2]="MB";hum[1024]="KB"; for (x=1024**4; x>=1024; x/=1024){ if (sum>=x) { printf "%.2f %s\n",sum/x,hum[x]; break } } if (sum<1024) print sum " B" }'
    fi
}

# Erstellt einen MySQL-Dump für einen bestimmten Container.
# Parameter:
#   $1: Container-Name
#   $2: MySQL-Benutzer
#   $3: MySQL-Passwort
#   $4: Port (Standard: 3306)
#   $5: Zieldatei (Pfad zur .sql.gz)
do_mysql_dump() {
    local container="$1"
    local user="$2"
    local pass="$3"
    local port="${4:-3306}"
    local target_file="$5"

    log "Sichere Instanz: $container (Port: $port) nach $target_file..."

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        mkdir -p "$(dirname "$target_file")"
        if docker exec "$container" \
            mysqldump \
            -u "$user" \
            -p"$pass" \
            --port="$port" \
            --all-databases \
            --single-transaction \
            --quick \
            --lock-tables=false \
            | gzip > "$target_file"; then
            log "Dump erfolgreich erstellt: $target_file"
            return 0
        else
            log "FEHLER: MySQL Dump fuer $container fehlgeschlagen."
            return 1
        fi
    else
        log "WARNUNG: Container $container nicht gefunden oder laeuft nicht - ueberspringe."
        return 1
    fi
}

# Iteriert ueber alle konfigurierten MySQL-Instanzen in MYSQL_INSTANCES
# und erstellt jeweils einen Dump.
backup_mysql_dump() {
    log "--- MySQL Multi-Dump gestartet ---"

    if [ "${#MYSQL_INSTANCES[@]}" -eq 0 ]; then
        log "Keine MySQL-Instanzen zur Sicherung konfiguriert."
        return 0
    fi

    for entry in "${MYSQL_INSTANCES[@]}"; do
        # Splitten des Eintrags (Format: container:user:pass:port)
        local IFS=':'
        read -r c_name c_user c_pass c_port <<< "$entry"
        IFS=$' \t\n' # IFS zuruecksetzen

        # Fallback auf Standardwerte falls Felder leer sind
        local container="${c_name}"
        local user="${c_user:-$MYSQL_DEFAULT_USER}"
        local pass="${c_pass:-$MYSQL_DEFAULT_PASSWORD}"
        local port="${c_port:-3306}"
        
        if [ -z "$container" ]; then
            log "WARNUNG: Ungueltiger MySQL-Eintrag (Container-Name fehlt) - ueberspringe."
            continue
        fi

        local target="$TARGET_DIR/mysql/${container}.sql.gz"
        do_mysql_dump "$container" "$user" "$pass" "$port" "$target" || true
    done
}

# Kopiert die konfigurierten Docker-Verzeichnisse (DOCKER_DIR) in das Zielverzeichnis.
# Nutzt 'pv' fuer eine Fortschrittsanzeige, falls installiert.
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

# Fuehrt das Restic-Backup fuer das gesamte Zielverzeichnis aus.
backup_run_restic() {
    log "--- Restic Backup ---"
    restic -r "$RESTIC_REPOSITORY" \
        "${RESTIC_AUTH_ARGS[@]}" \
        backup "$TARGET_DIR" \
        --tag "$RESTIC_TAG" \
        --verbose
}

# Bereinigt alte Snapshots im Restic-Repository basierend auf der Retention-Policy.
backup_prune_restic() {
    log "--- Restic Aufraeumen ---"
    restic -r "$RESTIC_REPOSITORY" \
        "${RESTIC_AUTH_ARGS[@]}" \
        forget --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune
}
