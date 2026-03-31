# Docker Backup with Restic, Rclone, and Gotify

[Deutsch](readme.de.md) | [English](readme.md)

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![OS: Linux](https://img.shields.io/badge/OS-Linux-333?logo=linux)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-121011?logo=gnubash)
![Backup: Restic](https://img.shields.io/badge/Backup-Restic-ffcc00)
![Sync: Rclone](https://img.shields.io/badge/Sync-Rclone-3f79e8)
![Notify: Gotify](https://img.shields.io/badge/Notify-Gotify-4caf50)

Automated backup for a Linux Docker host using local snapshots, Restic deduplication, and remote upload via Rclone.

## Table of Contents

- [Features](#features)
- [Backup Flow](#backup-flow)
- [Requirements](#requirements)
- [Directory Layout](#directory-layout)
- [Configuration](#configuration)
- [Script Behavior](#script-behavior)
- [Excluded Stacks](#excluded-stacks)
- [systemd Automation](#systemd-automation)
- [Run Manually](#run-manually)
- [Restore](#restore)
- [Maintenance](#maintenance)
- [Additional Documentation](#additional-documentation)
- [Project Status](#project-status)

## Features

- Backup of Docker Compose stacks (including volumes and config)
- Vaultwarden backup support
- MySQL dump (`mysqldump` + `gzip`)
- Deduplicated offsite backups with Restic
- Gotify notifications for start/success/error/skip
- Run logs (info + errors) written to `./log/`
- Daily execution via `systemd` timer
- Exclusion of infrastructure stacks from stop/start operations

## Backup Flow

```text
Docker data
  -> Local snapshot (/srv/backups/<timestamp>)
  -> Restic backup
  -> Rclone remote (rclone:1blu:restic-repo)
  -> 1blu storage
```

## Requirements

Required tools:

- `docker`
- `docker compose` (plugin)
- `restic`
- `rclone`
- `curl`
- `gzip`
- `flock` (from `util-linux`)
- `pv` (optional, for copy progress display)

Example install (Debian/Ubuntu):

```bash
apt update
apt install -y docker.io docker-compose-plugin restic rclone curl util-linux pv
```

## Directory Layout

```text
/srv/docker                      # Docker environment
/srv/backups                     # Local snapshot targets
/opt/docker-backup/docker-backup.sh     # Backup script
/opt/docker-backup/.env                 # Runtime configuration (including Restic password)
/opt/docker-backup/log/                 # Backup run logs
```

Example snapshot:

```text
/srv/backups/2026-03-15_22-34
```

## Configuration

### 1) Create `.env`

Path: `/opt/docker-backup/.env`

Example (see `.env.example` in this repo):

```env
MYSQL_CONTAINER=mysql
MYSQL_USER=root
MYSQL_PASSWORD=CHANGEME

GOTIFY_URL=https://gotify.example.com/message
GOTIFY_TOKEN=CHANGEME

GOTIFY_PRIORITY_SUCCESS=4
GOTIFY_PRIORITY_ERROR=8
```

### 2) Create `backup.conf`

Path: `/opt/docker-backup/backup.conf`

Template: `backup.conf.example` (copy and adjust for your host)
Optional: set `LOG_DIR` (otherwise default is `<project-root>/log`)

Example:

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

### 3) Initialize the Restic repository

```bash
restic -r rclone:1blu:restic-repo init
```

List snapshots:

```bash
restic -r rclone:1blu:restic-repo snapshots
```

## Script Behavior

The script [`scripts/docker-backup.sh`](scripts/docker-backup.sh) performs:

1. Detect active Docker Compose stacks
2. Run Vaultwarden backup
3. Create MySQL dump
4. Stop active stacks (except excluded ones)
5. Copy Docker directories to local snapshot
6. Run Restic backup to remote repository
7. Apply retention policy and prune old snapshots
8. Restart previously active stacks
9. Send result notification via Gotify
10. Write complete run log (stdout/stderr) to `LOG_DIR/docker-backup-<timestamp>.log`

## Excluded Stacks

Infrastructure stacks can be excluded from stop/start operations.

Important: These exclusions only affect service orchestration during backup (`docker compose down/up`).
They do not exclude data from backup content. The script still copies the full `DOCKER_DIR`.

Set exclusions in `/opt/docker-backup/backup.conf`:

```bash
EXCLUDED_STACK_DIRS=(
  "/srv/docker/infrastructure/gotify"
  "/srv/docker/infrastructure/ntpserver"
)

EXCLUDED_CONTAINER_NAMES=(
  "gotify"
)
```

## systemd Automation

Example unit files in this repository:

- [`systemd/docker-backup.service`](systemd/docker-backup.service)
- [`systemd/docker-backup.timer`](systemd/docker-backup.timer)

Copy them to `/etc/systemd/system/`, then run:

```bash
systemctl daemon-reload
systemctl enable --now docker-backup.timer
systemctl list-timers | grep docker-backup
```

Default schedule in timer:

```ini
OnCalendar=*-*-* 05:30:00
```

## Run Manually

```bash
systemctl start docker-backup.service
journalctl -u docker-backup.service -f
```

## Restore

Detaillierte Anweisungen zur Wiederherstellung finden Sie im Verzeichnis [`restore/`](restore/README.md).

Kurzübersicht:

```bash
cd restore
./restore.sh snapshots  # Snapshots auflisten
./restore.sh ls latest  # Inhalt des neuesten Snapshots zeigen
./restore.sh restore latest /mysql.sql.gz  # Einzelne Datei wiederherstellen
```

## Maintenance

Check repository:

```bash
restic -r rclone:1blu:restic-repo check
```

Show stats:

```bash
restic -r rclone:1blu:restic-repo stats
```

## Additional Documentation

- [Architecture](docs/architecture.md)
- [Restore Guide](docs/restore.md)
- [Troubleshooting](docs/troubleshooting.md)

## Project Status

- Status: production
- Daily automated backup at: `05:30`
- Storage target: `1blu` via `rclone`
- Notifications: `Gotify`
