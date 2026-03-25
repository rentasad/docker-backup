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
- `backup_mysql_dump`: Erstellt MySQL-Dump
- `backup_copy_docker_dirs`: Kopiert Docker-Daten (mit `pv`-Fortschritt, falls verfuegbar)
- `backup_run_restic`: Fuehrt Restic-Backup aus
- `backup_prune_restic`: Wendet Retention/Prune auf Restic an

## Design-Prinzip

`docker-backup.sh` bleibt als Orchestrierung schlank und ruft nur noch klar abgegrenzte Funktionen aus den Modulen auf.
