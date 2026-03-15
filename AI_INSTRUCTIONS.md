# KI-Arbeitsregeln für dieses Projekt

Ziel:
Dieses Projekt sichert Docker-Daten konsistent mit Restic auf ein Remote-Repository.

Regeln:
- Bash verwenden
- Immer `set -Eeuo pipefail`
- Keine Secrets im Skript
- Konfiguration nur über `.env` oder Passwortdateien
- systemd Timer statt cron
- Infrastruktur-Stacks wie Gotify nicht stoppen
- Excludes über Working Dirs und optional Containernamen
- Logging immer mit Zeitstempel
- Fehlerbehandlung zentral halten
- Änderungen müssen restore-freundlich bleiben

Wichtige Pfade:
- Script: `/srv/restic/docker-backup.sh`
- Env: `/srv/restic/.env`
- Restic Passwort: `/srv/restic/restic-password.txt`
- Docker Root: `/srv/docker`
- Lokale Snapshots: `/srv/backups`