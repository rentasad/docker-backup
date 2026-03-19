#!/bin/bash

###############################################################################
# WARNHINWEIS:
# Dieses Skript dient NUR der EINMALIGEN INITIALISIERUNG des Restic-Repositories.
# Falls das Repository bereits existiert (z.B. auf dem Remote-Speicher), darf
# dieses Skript NICHT erneut erfolgreich ausgeführt werden.
#
# Für reguläre Backups bitte das Skript 'scripts/docker-backup.sh' verwenden.
###############################################################################

# Pfad zur .env-Datei im Root-Verzeichnis (ein Verzeichnis oberhalb von setup/)
ENV_FILE="$(dirname "$0")/../.env"

# Laden der .env-Datei, falls vorhanden
if [ -f "$ENV_FILE" ]; then
    # -a sorgt dafür, dass alle Variablen automatisch exportiert werden (entspricht export VARIABLE)
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Fehler: .env-Datei nicht unter $ENV_FILE gefunden."
    exit 1
fi

# Initialisierung des Restic-Repositories
# restic nutzt automatisch die exportierten Variablen
# RESTIC_REPOSITORY und (optional) RESTIC_PASSWORD_FILE / RESTIC_PASSWORD
restic init