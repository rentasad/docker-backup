# Docker-Backup mit Restic, Rclone und Gotify

[Deutsch](readme.de.md) | [English](readme.md)

![Lizenz: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![BS: Linux](https://img.shields.io/badge/OS-Linux-333?logo=linux)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-121011?logo=gnubash)
![Backup: Restic](https://img.shields.io/badge/Backup-Restic-ffcc00)
![Sync: Rclone](https://img.shields.io/badge/Sync-Rclone-3f79e8)
![Benachrichtigung: Gotify](https://img.shields.io/badge/Notify-Gotify-4caf50)

Automatisiertes Backup für einen Linux Docker-Host mit lokalen Snapshots, Restic-Deduplizierung und Remote-Upload via Rclone.

## Inhaltsverzeichnis

- [Features](#features)
- [Backup-Ablauf](#backup-ablauf)
- [Voraussetzungen](#voraussetzungen)
- [Verzeichnisstruktur](#verzeichnisstruktur)
- [Konfiguration](#konfiguration)
- [Skript-Verhalten](#skript-verhalten)
- [Ausgeschlossene Stacks](#ausgeschlossene-stacks)
- [systemd-Automatisierung](#systemd-automatisierung)
- [Manuelle Ausführung](#manuelle-ausführung)
- [Wiederherstellung (Restore)](#wiederherstellung-restore)
- [Wartung](#wartung)
- [Zusätzliche Dokumentation](#zusätzliche-dokumentation)
- [Projektstatus](#projektstatus)

## Features

- Backup von Docker Compose Stacks (inklusive Volumes und Konfiguration)
- Unterstützung für Vaultwarden-Backups
- MySQL-Dump (`mysqldump` + `gzip`)
- Deduplizierte Offsite-Backups mit Restic
- Gotify-Benachrichtigungen für Start/Erfolg/Fehler/Überspringen
- Ausführungsprotokolle (Info + Fehler) werden in `./log/` geschrieben
- Tägliche Ausführung via `systemd` Timer
- Ausschluss von Infrastruktur-Stacks von Stop/Start-Operationen

## Backup-Ablauf

```text
Docker-Daten
  -> Lokaler Snapshot (/srv/backups/<zeitstempel>)
  -> Restic-Backup
  -> Rclone-Remote (rclone:1blu:restic-repo)
  -> 1blu Speicher
```

## Voraussetzungen

Benötigte Tools:

- `docker`
- `docker compose` (Plugin)
- `restic`
- `rclone`
- `curl`
- `gzip`
- `flock` (aus `util-linux`)
- `pv` (optional, für Fortschrittsanzeige beim Kopieren)

Beispiel-Installation (Debian/Ubuntu):

```bash
apt update
apt install -y docker.io docker-compose-plugin restic rclone curl util-linux pv
```

## Verzeichnisstruktur

```text
/srv/docker                      # Docker-Umgebung
/srv/backups                     # Ziel für lokale Snapshots
/srv/restic/docker-backup.sh     # Backup-Skript
/srv/restic/.env                 # Laufzeit-Konfiguration
/srv/restic/log/                 # Protokolle der Backup-Läufe
/srv/restic/restic-password.txt  # Restic-Passwortdatei
```

Beispiel-Snapshot:

```text
/srv/backups/2026-03-15_22-34
```

## Konfiguration

### 1) `.env` erstellen

Pfad: `/srv/restic/.env`

Beispiel (siehe `.env.example` in diesem Repository):

```env
MYSQL_CONTAINER=mysql
MYSQL_USER=root
MYSQL_PASSWORD=ÄNDERMICH

GOTIFY_URL=https://gotify.example.com/message
GOTIFY_TOKEN=ÄNDERMICH

GOTIFY_PRIORITY_SUCCESS=4
GOTIFY_PRIORITY_ERROR=8
```

### 2) `backup.conf` erstellen

Pfad: `/srv/restic/backup.conf`

Vorlage: `backup.conf.example` (kopieren und für Ihren Host anpassen)
Optional: `LOG_DIR` setzen (sonst Standard `<projekt-root>/log`)

Beispiel:

```bash
BACKUP_ROOT=/srv/backups
DOCKER_DIR=/srv/docker
MYSQL_CONTAINER=mysql
RESTIC_TAG=docker-backup
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

EXCLUDED_STACK_DIRS=(
  "/srv/docker/infrastructure/gotify"
  "/srv/docker/infrastructure/ntpserver"
)

EXCLUDED_CONTAINER_NAMES=(
  "gotify"
)
```

### 3) Restic-Repository initialisieren

```bash
restic -r rclone:1blu:restic-repo \
  --password-file /srv/restic/restic-password.txt \
  init
```

Snapshots auflisten:

```bash
restic -r rclone:1blu:restic-repo \
  --password-file /srv/restic/restic-password.txt \
  snapshots
```

## Skript-Verhalten

Das Skript [`scripts/docker-backup.sh`](scripts/docker-backup.sh) führt folgende Schritte aus:

1. Erkennung aktiver Docker Compose Stacks
2. Ausführung des Vaultwarden-Backups
3. Erstellung des MySQL-Dumps
4. Stoppen aktiver Stacks (außer ausgeschlossene)
5. Kopieren der Docker-Verzeichnisse in den lokalen Snapshot
6. Ausführung des Restic-Backups zum Remote-Repository
7. Anwendung der Aufbewahrungsrichtlinie und Löschen alter Snapshots
8. Neustart der zuvor aktiven Stacks
9. Senden der Ergebnisbenachrichtigung via Gotify
10. Schreiben des vollständigen Protokolls (stdout/stderr) nach `LOG_DIR/docker-backup-<zeitstempel>.log`

## Ausgeschlossene Stacks

Infrastruktur-Stacks können von den Stop/Start-Operationen ausgeschlossen werden.

Wichtig: Diese Ausschlüsse betreffen nur die Dienst-Orchestrierung während des Backups (`docker compose down/up`).
Daten werden dadurch nicht vom Backup ausgeschlossen. Das Skript kopiert weiterhin das gesamte `DOCKER_DIR`.

Ausschlüsse in `/srv/restic/backup.conf` festlegen:

```bash
EXCLUDED_STACK_DIRS=(
  "/srv/docker/infrastructure/gotify"
  "/srv/docker/infrastructure/ntpserver"
)

EXCLUDED_CONTAINER_NAMES=(
  "gotify"
)
```

## systemd-Automatisierung

Beispielhafte Unit-Dateien in diesem Repository:

- [`systemd/docker-backup.service`](systemd/docker-backup.service)
- [`systemd/docker-backup.timer`](systemd/docker-backup.timer)

Diese nach `/etc/systemd/system/` kopieren und anschließend ausführen:

```bash
systemctl daemon-reload
systemctl enable --now docker-backup.timer
systemctl list-timers | grep docker-backup
```

Standard-Zeitplan im Timer:

```ini
OnCalendar=*-*-* 05:30:00
```

## Manuelle Ausführung

```bash
systemctl start docker-backup.service
journalctl -u docker-backup.service -f
```

## Wiederherstellung (Restore)

Detaillierte Anweisungen zur Wiederherstellung finden Sie im Verzeichnis [`restore/`](restore/README.md).

Kurzübersicht:

```bash
cd restore
./restore.sh snapshots  # Snapshots auflisten
./restore.sh ls latest  # Inhalt des neuesten Snapshots zeigen
./restore.sh restore latest /mysql.sql.gz  # Einzelne Datei wiederherstellen
```

## Wartung

Repository prüfen:

```bash
restic -r rclone:1blu:restic-repo \
  --password-file /srv/restic/restic-password.txt \
  check
```

Statistiken anzeigen:

```bash
restic -r rclone:1blu:restic-repo \
  --password-file /srv/restic/restic-password.txt \
  stats
```

## Zusätzliche Dokumentation

- [Architektur](docs/architecture.md)
- [Wiederherstellungs-Leitfaden](docs/restore.md)
- [Fehlerbehebung](docs/troubleshooting.md)

## Projektstatus

- Status: Produktion (Production)
- Tägliches automatisiertes Backup um: `05:30`
- Speicherziel: `1blu` via `rclone`
- Benachrichtigungen: `Gotify`
