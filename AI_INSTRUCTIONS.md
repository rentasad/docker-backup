# KI-Arbeitsregeln für dieses Projekt

Ziel:
Dieses Projekt sichert Docker-Stacks konsistent mit Restic auf ein Remote-Repository.

Regeln:
- Shell: bash
- Immer `set -Eeuo pipefail` verwenden
- Keine Passwörter oder Tokens hart im Skript hinterlegen
- Secrets nur über `.env` oder Passwortdateien
- systemd Timer statt cron bevorzugen
- Vor dem Stoppen von Stacks Excludes beachten
- Infrastruktur-Stacks wie Gotify dürfen nicht gestoppt werden
- Änderungen müssen restore-freundlich sein
- Logging immer mit Zeitstempel
- Fehlerbehandlung zentral halten
- Keine unnötigen externen Abhängigkeiten einführen

Wichtige Pfade:
- Script: `/srv/restic/docker-backup.sh`
- Env: `/srv/restic/.env`
- Restic Passwort: `/srv/restic/restic-password.txt`
- Docker Root: `/srv/docker`
- Lokale Snapshots: `/srv/backups`

Bei Änderungen immer mitdenken:
- Läuft der Restore noch sauber?
- Werden Stacks bei Fehlern wieder gestartet?
- Bleibt Gotify während des Backups erreichbar?
- Werden nur relevante Dienste gestoppt?
