#!/bin/bash
set -Eeuo pipefail

###############################################################################
# Restic Restore Skript
#
# Dieses Skript unterstützt die selektive Wiederherstellung von Daten
# aus dem Restic-Repository.
###############################################################################

# Pfad zur .env-Datei im Root-Verzeichnis
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
CONFIG_FILE="$ROOT_DIR/backup.conf"

# === .env und config laden ===
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    echo "Fehler: .env-Datei nicht unter $ENV_FILE gefunden."
    exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "Warnung: backup.conf nicht gefunden. Nutze Standardwerte."
    # shellcheck disable=SC2034
    BACKUP_ROOT="/srv/backups"
    # shellcheck disable=SC2034
    DOCKER_DIR="/srv/docker"
fi

# Restic Umgebungsvariablen sicherstellen (falls nicht in .env)
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
# Falls RESTIC_PASSWORD_FILE genutzt wird (Kompatibilität)
if [ -z "$RESTIC_PASSWORD" ] && [ -n "${RESTIC_PASSWORD_FILE:-}" ]; then
    export RESTIC_PASSWORD_FILE="$RESTIC_PASSWORD_FILE"
fi

# Hilfsfunktion für Restic-Aufrufe
restic_cmd() {
    restic "$@"
}

show_usage() {
    echo "Nutzung: $0 [BEFEHL]"
    echo ""
    echo "Befehle:"
    echo "  snapshots             Listet alle verfügbaren Snapshots auf"
    echo "  ls <snapshot_id>      Listet den Inhalt eines Snapshots auf"
    echo "  restore <id> <pfad> [ziel] Stellt einen bestimmten Pfad aus einem Snapshot wieder her"
    echo "                        (Pfad relativ zum Root des Snapshots, z.B. /mysql.sql.gz)"
    echo "                        [ziel] ist optional (Standard: ./restore-out-...)"
    echo "  mount <mountpoint>    Mountet das Repository als Dateisystem (erfordert fuse)"
    echo ""
    echo "Beispiele selektiver Restore:"
    echo "  $0 restore latest /docker/apps/my-app"
    echo "  $0 restore latest /mysql.sql.gz /tmp/restore-mysql"
}

case "${1:-}" in
    snapshots)
        restic_cmd snapshots
        ;;
    ls)
        if [ -z "${2:-}" ]; then
            echo "Fehler: Snapshot-ID erforderlich (oder 'latest')."
            exit 1
        fi
        echo "Zeige Inhalt von Snapshot '$2'..."
        restic_cmd ls "$2"
        ;;
    restore)
        ID="${2:-}"
        PATH_TO_RESTORE="${3:-}"
        TARGET_USER_DIR="${4:-}"

        if [ -z "$ID" ] || [ -z "$PATH_TO_RESTORE" ]; then
            echo "Fehler: Snapshot-ID und Pfad erforderlich."
            echo "Beispiel: $0 restore latest /docker/apps/immich-app"
            exit 1
        fi
        
        # Zielverzeichnis bestimmen
        if [ -n "$TARGET_USER_DIR" ]; then
            # Benutzerdefiniertes Zielverzeichnis (über Parameter)
            RESTORE_TARGET="$TARGET_USER_DIR"
        elif [ -n "${RESTORE_DEFAULT_PATH:-}" ]; then
            # Standardpfad aus .env
            RESTORE_TARGET="$RESTORE_DEFAULT_PATH"
        else
            # Fallback: Lokales Verzeichnis mit Zeitstempel
            # Absoluter Pfad wird bevorzugt, um Verwirrung zu vermeiden
            RESTORE_TARGET="$(pwd)/restore-out-$(date +%F_%H-%M)"
        fi

        mkdir -p "$RESTORE_TARGET"
        
        echo "==============================================================================="
        echo "RESTORING DATA"
        echo "-------------------------------------------------------------------------------"
        echo "Snapshot:   $ID"
        echo "Pfad intern: $PATH_TO_RESTORE"
        echo "Ziel lokal:  $RESTORE_TARGET"
        echo "==============================================================================="
        echo ""

        # Restic Aufruf
        # Wir nutzen --include und stellen sicher, dass der Pfad korrekt behandelt wird
        restic_cmd restore "$ID" --target "$RESTORE_TARGET" --include "$PATH_TO_RESTORE"
        
        echo ""
        echo "-------------------------------------------------------------------------------"
        echo "Wiederherstellung abgeschlossen."
        echo "Die Dateien befinden sich in: $RESTORE_TARGET"
        echo "Hinweis: Restic stellt die komplette Ordnerstruktur ab dem Snapshot-Root her."
        echo "==============================================================================="
        ;;
    mount)
        MOUNT_POINT="${2:-/mnt/restic}"
        mkdir -p "$MOUNT_POINT"
        echo "Mounting repository to $MOUNT_POINT..."
        restic_cmd mount "$MOUNT_POINT"
        ;;
    *)
        show_usage
        ;;
esac
