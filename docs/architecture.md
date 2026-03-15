# Architecture

## Purpose

This project provides a reliable backup workflow for a self-hosted
Docker environment. It creates local snapshots of Docker data and
uploads deduplicated backups using Restic via rclone. Notifications are
sent using Gotify and automation is handled by systemd timers.

## High-level Flow

Docker Services ↓ Local Snapshot (/srv/backups/`<timestamp>`{=html}) ↓
Restic Backup ↓ rclone Remote ↓ 1blu Storage ↓ Gotify Notification

## Key Components

### Docker Environment

Main Docker root: /srv/docker

Example stacks: /srv/docker/apps/vaultwarden
/srv/docker/apps/stirlingpdf /srv/docker/infrastructure/gotify

### Local Snapshot

Snapshots are stored locally before upload:

/srv/backups/`<timestamp>`{=html}

Example: /srv/backups/2026-03-15_22-34

### Backup Script

Main script: /srv/restic/docker-backup.sh

Responsibilities: 1. Detect active Docker stacks 2. Run Vaultwarden
backup 3. Create MySQL dump 4. Stop relevant stacks 5. Create snapshot
6. Run Restic backup 7. Apply retention policy 8. Restart stacks 9. Send
Gotify notifications

### Restic Repository

Repository: rclone:1blu:restic-repo

Features: - deduplication - compression - snapshot history - retention
policies

### rclone

Transport layer for remote storage. Config file:
/home/matthi/.config/rclone/rclone.conf

### Gotify

Used for notifications:

-   Backup started
-   Backup successful
-   Backup failed

### systemd Timer

Automation files:

/etc/systemd/system/docker-backup.service
/etc/systemd/system/docker-backup.timer

Timer schedule: 05:30 daily.
