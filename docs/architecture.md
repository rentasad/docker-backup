# Architecture

## Purpose

This project provides a reliable backup workflow for a self-hosted Docker environment. It creates local snapshots of Docker data and uploads deduplicated backups using Restic via rclone. Notifications are sent using Gotify and automation is handled by systemd timers.

## High-level Flow

```text
Docker Services
  -> Vaultwarden backup (pre-stop)
  -> MySQL / MariaDB dumps (pre-stop)
  -> Nextcloud backup (maintenance mode, DB dump, data sync)
  -> Detect and save active stacks to `.active_stacks`
  -> Stop non-excluded stacks
  -> Local Snapshot (/srv/backups/<timestamp>)
  -> Restic Backup (deduplicated, encrypted)
  -> rclone Remote (primary storage, e.g. 1blu)
  -> [Optional] Internxt secondary sync
  -> Prune old Restic snapshots
  -> Clean up old local snapshots
  -> Restart stacks
  -> Gotify Notification
```

## Key Components

### Docker Environment

Main Docker root: `/srv/docker`

Example stacks:
- `/srv/docker/apps/vaultwarden`
- `/srv/docker/apps/nextcloud`
- `/srv/docker/infrastructure/gotify`

### Local Snapshot

Snapshots are stored locally before upload:

```text
/srv/backups/<timestamp>
```

Example: `/srv/backups/2026-03-15_22-34`

The number of retained local snapshots is controlled by `KEEP_LOCAL_BACKUPS` in `backup.conf`.

### Backup Script

Main script: `/opt/docker-backup/scripts/docker-backup.sh`

Responsibilities:
1. Detect active Docker stacks and save to `ACTIVE_STACKS_STATE_FILE`
2. Run Vaultwarden backup
3. Create MySQL / MariaDB dumps (all `MYSQL_INSTANCES`)
4. Run Nextcloud backup (maintenance mode on/off, DB dump, rsync data)
5. Stop non-excluded stacks
6. Create local snapshot
7. Run Restic backup to remote
8. Apply Restic retention policy (prune)
9. [Optional] Sync to Internxt secondary remote
10. Clean up old local snapshot directories
11. Restart stacks
12. Send Gotify notifications

### Restic Repository

Repository configured via `RESTIC_REPOSITORY` in `.env` (e.g. `rclone:1blu:restic-repo`).

Features:
- Deduplication
- Encryption
- Snapshot history
- Configurable retention policies (`KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`)

### rclone

Transport layer for remote storage. Config file path is set via `RCLONE_CONFIG` in `.env`.

Two remotes are typically configured:
- **Primary** (e.g. `1blu`): target for the Restic repository
- **Internxt** (optional): secondary sync target, name configured via `INTERNXT_RCLONE_REMOTE` in `backup.conf`

### Nextcloud Backup

The Nextcloud backup (`scripts/lib/nextcloud.sh`) handles:
- Activating Nextcloud maintenance mode before backup
- DB dump using `mariadb-dump` or `mysqldump` (auto-detected, or set via `NEXTCLOUD_DB_DUMP_CMD`)
- rsync of data directories (`data`, `config`, `custom_apps`, `themes`)
- Deactivating maintenance mode after backup (also via trap for safety)

### Gotify

Used for notifications:
- Backup started
- Backup successful
- Backup failed / skipped

### systemd Timer

Automation files:
- `/etc/systemd/system/docker-backup.service`
- `/etc/systemd/system/docker-backup.timer`

Timer schedule: `05:30` daily.
