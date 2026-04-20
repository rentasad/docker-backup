#!/bin/bash
# Nextcloud-spezifisches Backup mit Maintenance Mode

# Debug-Modus: auf 1 setzen fuer ausfuehrliche Ausgaben (PW wird maskiert)
NC_DEBUG="${NC_DEBUG:-1}"

_nc_debug() {
  [ "$NC_DEBUG" = "1" ] && log "[NC_DEBUG] $*"
}

backup_nextcloud() {
  log "--- Nextcloud Backup gestartet ---"

  _nc_debug "NEXTCLOUD_APP_CONTAINER='${NEXTCLOUD_APP_CONTAINER}'"
  _nc_debug "NEXTCLOUD_DB_CONTAINER='${NEXTCLOUD_DB_CONTAINER}'"
  _nc_debug "NEXTCLOUD_DB_USER='${NEXTCLOUD_DB_USER}'"
  _nc_debug "NEXTCLOUD_DB_PASSWORD='${NEXTCLOUD_DB_PASSWORD:0:2}***${NEXTCLOUD_DB_PASSWORD: -1}' (Laenge: ${#NEXTCLOUD_DB_PASSWORD})"
  _nc_debug "NEXTCLOUD_DB_NAME='${NEXTCLOUD_DB_NAME}'"
  _nc_debug "NEXTCLOUD_DATA_DIR='${NEXTCLOUD_DATA_DIR}'"
  _nc_debug "TARGET_DIR='${TARGET_DIR}'"

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

  if [ "$NC_DEBUG" = "1" ]; then
    _nc_debug "Pruefe mysqldump Verfuegbarkeit in Container '${NEXTCLOUD_DB_CONTAINER}'..."
    local mysqldump_check
    mysqldump_check=$(docker exec "${NEXTCLOUD_DB_CONTAINER}" mysqldump --version 2>&1) \
      && _nc_debug "mysqldump OK: ${mysqldump_check}" \
      || _nc_debug "WARNUNG: mysqldump nicht gefunden (Exit $?): ${mysqldump_check}"
    _nc_debug "Kommando: docker exec ${NEXTCLOUD_DB_CONTAINER} mysqldump --single-transaction --quick -u${NEXTCLOUD_DB_USER} -p[MASKED] ${NEXTCLOUD_DB_NAME}"
  fi

  local dump_stderr_file
  dump_stderr_file=$(mktemp)
  local dump_exit=0

  docker exec "${NEXTCLOUD_DB_CONTAINER}" \
    mysqldump \
      --single-transaction \
      --quick \
      -u"${NEXTCLOUD_DB_USER}" \
      -p"${NEXTCLOUD_DB_PASSWORD}" \
      "${NEXTCLOUD_DB_NAME}" \
    2>"${dump_stderr_file}" \
    | gzip > "${NC_BACKUP_DIR}/nextcloud-db.sql.gz" \
    || dump_exit=$?

  if [ -s "${dump_stderr_file}" ]; then
    _nc_debug "mysqldump stderr: $(cat "${dump_stderr_file}")"
  fi
  rm -f "${dump_stderr_file}"

  _nc_debug "mysqldump Exit-Code: ${dump_exit}"
  if [ "$dump_exit" -ne 0 ]; then
    log "FEHLER: Nextcloud DB-Dump fehlgeschlagen (Exit ${dump_exit})"
    return 1
  fi
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