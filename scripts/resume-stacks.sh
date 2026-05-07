#!/bin/bash
set -Eeuo pipefail

# Skript zum manuellen Wiederanfahren der Docker-Stacks nach einem fehlgeschlagenen Backup.
# Nutzt die persistente Statusdatei, die vom Hauptskript angelegt wurde.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="/opt/docker-backup/.env"
CONFIG_FILE="/opt/docker-backup/backup.conf"

# shellcheck disable=SC1090
source "$LIB_DIR/common.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/config.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/docker.sh"

load_configuration
init_logging

log "=== Resume Docker Stacks gestartet ==="

if [ ! -f "$ACTIVE_STACKS_STATE_FILE" ]; then
    log "Keine Statusdatei gefunden unter: $ACTIVE_STACKS_STATE_FILE"
    log "Entweder waren keine Stacks aktiv oder sie wurden bereits erfolgreich wieder gestartet."
    exit 0
fi

log "Gefundene Stacks in $ACTIVE_STACKS_STATE_FILE:"
cat "$ACTIVE_STACKS_STATE_FILE"
echo

docker_restart_stacks_from_file "$ACTIVE_STACKS_STATE_FILE"

log "Moechten Sie die Statusdatei jetzt loeschen? (y/n)"
# Da wir in einer nicht-interaktiven Umgebung sein koennten, 
# prüfen wir ob stdin ein Terminal ist.
if [ -t 0 ]; then
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        rm -f "$ACTIVE_STACKS_STATE_FILE"
        log "Statusdatei geloescht."
    else
        log "Statusdatei wurde behalten."
    fi
else
    log "Nicht-interaktiver Modus: Statusdatei wird NICHT automatisch geloescht."
    log "Bitte loeschen Sie diese manuell mit: rm $ACTIVE_STACKS_STATE_FILE"
fi

log "=== Resume Docker Stacks abgeschlossen ==="
