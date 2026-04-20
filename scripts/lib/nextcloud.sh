#!/bin/bash
# Nextcloud-spezifisches Backup mit Maintenance Mode

backup_nextcloud() {
  log "--- Nextcloud Backup gestartet ---"

  # 1. Maintenance Mode AN
  log "Nextcloud: Aktiviere Maintenance Mode..."
  docker exec "${NEXTCLOUD_APP_CONTAINER}" \
    php occ maintenance:mode --on \
    || { log "FEHLER: Maintenance Mode konnte nicht aktiviert werden"; return 1; }

  # Sicherheitsnetz: Maintenance Mode beim Exit immer deaktivieren
  trap 'docker exec "${NEXTCLOUD_APP_CONTAINER}" php occ maintenance:mode --off 2>/dev/null || true' RETURN

  local NC_BACKUP_DIR="${TARGET_DIR}/nextcloud"
  mkdir -p "${NC_BACKUP_DIR}"

  # 2. DB-Dump
  log "Nextcloud: Erstelle DB-Dump..."
  docker exec "${NEXTCLOUD_DB_CONTAINER}" \
    mysqldump \
      --single-transaction \
      --quick \
      -u"${NEXTCLOUD_DB_USER}" \
      -p"${NEXTCLOUD_DB_PASSWORD}" \
      "${NEXTCLOUD_DB_NAME}" \
    | gzip > "${NC_BACKUP_DIR}/nextcloud-db.sql.gz" \
    || { log "FEHLER: Nextcloud DB-Dump fehlgeschlagen"; return 1; }
  log "Nextcloud: DB-Dump abgeschlossen."

  # 3. Daten sichern
  log "Nextcloud: Sichere Daten-Verzeichnisse..."
  for dir in data config custom_apps themes; do
    local src="${NEXTCLOUD_DATA_DIR}/${dir}"
    local dst="${NC_BACKUP_DIR}/${dir}"
    if [ -d "${src}" ]; then
      rsync -a --delete "${src}/" "${dst}/" \
        || { log "FEHLER: rsync für ${dir} fehlgeschlagen"; return 1; }
      log "Nextcloud: ${dir} gesichert."
    else
      log "WARNUNG: ${src} nicht gefunden, übersprungen."
    fi
  done

  # 4. Maintenance Mode AUS (auch via trap, aber explizit sauberer)
  log "Nextcloud: Deaktiviere Maintenance Mode..."
  docker exec "${NEXTCLOUD_APP_CONTAINER}" php occ maintenance:mode --off

  log "--- Nextcloud Backup abgeschlossen ---"
}