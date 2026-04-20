# scripts/lib

Diese Bibliothek enthaelt die ausgelagerten Funktionen fuer `scripts/docker-backup.sh`.

## Module

### `common.sh`
- `log`: Einheitliches Timestamp-Logging
- `format_duration`: Formatiert Laufzeiten
- `send_gotify`: Versand von Gotify-Nachrichten
- `init_logging`: Initialisiert `LOG_DIR`/`LOG_FILE` und leitet stdout/stderr ins Log um
- `on_error`: Fehler-Handler fuer `trap ERR`

### `config.sh`
- `load_configuration`: Laedt `.env` und `backup.conf`, setzt Defaults und exportiert Restic/Rclone-Umgebung
- `require_config_var`: Validiert Pflichtvariablen

### `docker.sh`
- `docker_detect_active_stack_dirs`: Ermittelt aktive Compose-Working-Dirs
- `docker_is_excluded_stack`: Prueft Excludes per Stack-Verzeichnis/Containername
- `docker_stop_stacks_from_file`: Stoppt aktive Stacks (mit Exclude-Logik)
- `docker_restart_stacks_from_file`: Startet zuvor aktive Stacks wieder (mit Exclude-Logik)

### `backup.sh`
- `backup_vaultwarden`: Fuehrt Vaultwarden-Backup aus
- `backup_mysql_dump`: Erstellt MySQL/MariaDB-Dumps fuer alle konfigurierten `MYSQL_INSTANCES`
- `do_mysql_dump`: Interner Dump-Helfer fuer eine einzelne Instanz
- `backup_copy_docker_dirs`: Kopiert Docker-Daten (mit `pv`-Fortschritt, falls verfuegbar)
- `backup_run_restic`: Fuehrt Restic-Backup aus
- `backup_prune_restic`: Wendet Retention/Prune auf Restic an
- `backup_sync_to_internxt`: Synchronisiert das Restic-Repository zum Internxt-Remote (optional)
- `backup_cleanup_local`: Bereinigt alte lokale Snapshot-Verzeichnisse gemaess `KEEP_LOCAL_BACKUPS`
- `get_free_space_local`: Gibt freien Speicherplatz eines lokalen Pfades aus
- `get_free_space_rclone`: Gibt freien Speicherplatz eines Rclone-Remotes aus

### `nextcloud.sh`
- `backup_nextcloud`: Vollstaendiges Nextcloud-Backup (Maintenance Mode, DB-Dump, Daten-Sync)
  - Aktiviert Maintenance Mode vor dem Backup (deaktiviert via `trap` auch bei Fehler)
  - Erkennt automatisch `mariadb-dump` vs. `mysqldump` im Container (oder nutzt `NEXTCLOUD_DB_DUMP_CMD`)
  - Sichert die Verzeichnisse `data`, `config`, `custom_apps`, `themes` per rsync

## Design-Prinzip

`docker-backup.sh` bleibt als Orchestrierung schlank und ruft nur klar abgegrenzte Funktionen aus den Modulen auf.
