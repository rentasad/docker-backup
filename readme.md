# Docker Backup mit Restic, Rclone und Gotify

## Überblick

Dieses Projekt automatisiert das Backup einer Docker-Umgebung auf einem Linux-Server. Das Backup umfasst:

* Docker Compose Stacks
* Docker Volumes und Konfigurationsdateien
* Vaultwarden Backup
* MySQL Dump

Die Daten werden lokal als Snapshot gespeichert und anschließend mit Restic dedupliziert in ein Remote-Repository übertragen.

Benachrichtigungen über erfolgreiche oder fehlgeschlagene Backups erfolgen über Gotify.

Das Backup läuft automatisiert über einen systemd Timer.

---

## Architektur

Backup Ablauf:

Docker Daten
↓
Lokaler Snapshot (/srv/backups/<timestamp>)
↓
Restic Backup
↓
rclone Remote
↓
1blu Storage

Wichtige Eigenschaften:

* Restic arbeitet deduplizierend
* Es werden nur geänderte Daten übertragen
* Snapshots bleiben vollständig wiederherstellbar
* Infrastrukturcontainer können vom Stoppen ausgeschlossen werden

---

## Verzeichnisstruktur

Docker Umgebung:

/srv/docker

Beispiele:

/srv/docker/apps/vaultwarden
/srv/docker/apps/stirlingpdf
/srv/docker/infrastructure/gotify
/srv/docker/smarthome/homeassistant

Backup Verzeichnis:

/srv/backups

Beispiel Snapshot:

/srv/backups/2026-03-15_22-34

Backup Script:

/srv/restic/docker-backup.sh

Konfiguration:

/srv/restic/.env

Restic Passwort:

/srv/restic/restic-password.txt

---

## Benötigte Software

Folgende Tools werden benötigt:

* docker
* docker compose
* restic
* rclone
* curl
* gzip
* flock

Installation (Debian/Ubuntu Beispiel):

apt install docker.io docker-compose-plugin restic rclone curl

---

## Restic Repository

Remote Repository:

rclone:1blu:restic-repo

Repository initialisieren:

restic -r rclone:1blu:restic-repo 
--password-file /srv/restic/restic-password.txt 
init

Snapshots anzeigen:

restic -r rclone:1blu:restic-repo 
--password-file /srv/restic/restic-password.txt 
snapshots

---

## Konfiguration (.env)

Datei:

/srv/restic/.env

Beispiel:

MYSQL_CONTAINER=mysql
MYSQL_USER=root
MYSQL_PASSWORD=DEIN_PASSWORT

GOTIFY_URL=[https://gotify.example.com/message](https://gotify.example.com/message)
GOTIFY_TOKEN=DEIN_TOKEN

GOTIFY_PRIORITY_SUCCESS=4
GOTIFY_PRIORITY_ERROR=8

Diese Datei wird vom Backup Script automatisch geladen.

---

## Backup Script

Script:

/srv/restic/docker-backup.sh

Aufgaben des Scripts:

1. Aktive Docker Compose Stacks ermitteln
2. Vaultwarden Backup ausführen
3. MySQL Dump erstellen
4. Aktive Stacks stoppen
5. Docker Daten lokal kopieren
6. Restic Backup ausführen
7. Alte Snapshots bereinigen
8. Stacks wieder starten
9. Gotify Benachrichtigung senden

---

## Excluded Stacks

Bestimmte Infrastrukturcontainer sollen nicht gestoppt werden.

Beispiel:

* Gotify

Konfiguration im Script:

EXCLUDED_STACK_DIRS=(
"/srv/docker/infrastructure/gotify"
)

Optional zusätzlich Container Namen:

EXCLUDED_CONTAINER_NAMES=(
"gotify"
)

---

## Gotify Benachrichtigungen

Das Script sendet folgende Nachrichten:

Backup gestartet
Backup erfolgreich
Backup Fehler
Backup übersprungen

Beispiel Erfolgsmeldung:

Host: docker-home
Start: 2026-03-15 05:30
Ende: 2026-03-15 05:32
Dauer: 2m 18s
Größe: 900 MB

---

## systemd Automation

Service Datei:

/etc/systemd/system/docker-backup.service

Inhalt:

[Unit]
Description=Docker Backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/srv/restic/docker-backup.sh

Timer Datei:

/etc/systemd/system/docker-backup.timer

[Unit]
Description=Docker Backup täglich

[Timer]
OnCalendar=*-*-* 05:30:00
Persistent=true

[Install]
WantedBy=timers.target

Timer aktivieren:

systemctl daemon-reload
systemctl enable --now docker-backup.timer

Timer prüfen:

systemctl list-timers

---

## Backup manuell starten

systemctl start docker-backup.service

Logs anzeigen:

journalctl -u docker-backup.service -f

---

## Restore

Snapshots anzeigen:

restic -r rclone:1blu:restic-repo 
--password-file /srv/restic/restic-password.txt 
snapshots

Snapshot wiederherstellen:

restic -r rclone:1blu:restic-repo 
--password-file /srv/restic/restic-password.txt 
restore <snapshotID> --target /restore

---

## Wartung

Repository prüfen:

restic check

Statistik anzeigen:

restic stats

---

## Hinweise

* Restic überträgt nur geänderte Daten
* Backups sind dedupliziert
* Mehrere Snapshots teilen sich identische Blöcke
* Der lokale Snapshot dient als zusätzliche Sicherheit

---

## Erweiterungsmöglichkeiten

Mögliche Verbesserungen:

* Telegram oder Matrix Benachrichtigungen
* Backup Monitoring
* automatische Restore Tests
* separate Datenbank Backups
* Backup Rotation lokal

---

## Wartungshinweis

Bei Änderungen an der Docker Infrastruktur sollte geprüft werden:

* ob neue Stacks Backup relevant sind
* ob neue Infrastrukturcontainer ausgeschlossen werden sollen

---

## Projektstatus

Status: produktiv

Automatisches tägliches Backup

Startzeit: 05:30

Speicherziel: 1blu Storage über rclone

Benachrichtigungen: Gotify
