# Restore Guide

## Requirements

Required tools:

-   restic
-   rclone
-   docker
-   access to Restic password

Important files:

/home/matthi/.config/rclone/rclone.conf /srv/restic/restic-password.txt

Repository: rclone:1blu:restic-repo

## Setup

export RCLONE_CONFIG="/home/matthi/.config/rclone/rclone.conf" export
RESTIC_REPOSITORY="rclone:1blu:restic-repo" export
RESTIC_PASSWORD_FILE="/srv/restic/restic-password.txt"

## List Snapshots

restic -r "$RESTIC_REPOSITORY"   --password-file "$RESTIC_PASSWORD_FILE"
snapshots

## Restore Full Snapshot

mkdir /restore

restic -r "$RESTIC_REPOSITORY"   --password-file "$RESTIC_PASSWORD_FILE"
restore latest --target /restore

## Restore Vaultwarden

docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml down

Restore snapshot to temporary path, then copy required data.

docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml up -d

## Restore MySQL

gunzip -c mysql.sql.gz \| docker exec -i mysql mysql -u root -p
