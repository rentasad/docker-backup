#!/bin/bash
# setEnvironment.sh
# Dieses Skript laedt die Umgebungsvariablen fuer den manuellen Restore-Prozess.
# Nutzung: source ./setEnvironment.sh

# Pfad zur .env-Datei im Projekt-Root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "Lade Konfiguration aus $ENV_FILE..."
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    
    # Pruefen ob wichtige Restic-Variablen gesetzt sind
    if [ -n "${RESTIC_PASSWORD:-}" ]; then
        echo "✅ RESTIC_PASSWORD ist gesetzt."
    elif [ -n "${RESTIC_PASSWORD_FILE:-}" ]; then
        echo "ℹ️ RESTIC_PASSWORD_FILE ist gesetzt: $RESTIC_PASSWORD_FILE"
    else
        echo "⚠️ Warnung: Weder RESTIC_PASSWORD noch RESTIC_PASSWORD_FILE gefunden."
    fi
    
    if [ -n "${RESTIC_REPOSITORY:-}" ]; then
        echo "✅ RESTIC_REPOSITORY: $RESTIC_REPOSITORY"
    fi
    
    echo "Umgebung ist bereit. Du kannst nun 'restic' oder './restore.sh' direkt nutzen."
else
    echo "❌ Fehler: .env-Datei nicht unter $ENV_FILE gefunden."
    echo "Bitte stelle sicher, dass eine .env-Datei existiert."
fi
