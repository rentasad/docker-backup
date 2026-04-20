# Wiederherstellungs-Leitfaden (Restore Guide)

Dieses Dokument beschreibt, wie du Daten aus deinen Backups suchen, finden und wiederherstellen kannst. Es ergänzt das [Hilfsskript im `restore/` Verzeichnis](../restore/README.md).

## 1. Voraussetzungen & Vorbereitung

Bevor du mit der Wiederherstellung beginnst, stelle sicher, dass:
- Restic und Rclone installiert sind (siehe [Installationsanleitung](install_requirements.md)).
- Deine `rclone.conf` korrekt eingerichtet ist (siehe [Rclone Setup](rclone_setup.md)).
- Du Zugriff auf das Restic-Passwort hast (üblicherweise in der `.env` Datei).

### Umgebungsvariablen setzen
Bevor du manuelle Restic-Befehle ausführst, musst du die Umgebungsvariablen laden. Nutze dafür das bereitgestellte Skript im `restore/` Verzeichnis:

```bash
# In das Projekt-Verzeichnis wechseln
cd /opt/docker-backup

# Umgebung laden
source restore/setEnvironment.sh
```

Nun sind `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` (oder `RESTIC_PASSWORD_FILE`) und `RCLONE_CONFIG` in deiner aktuellen Shell-Sitzung gesetzt.

---

## 2. Suchen & Finden (Snapshots und Dateien)

Bevor du etwas wiederherstellst, musst du wissen, was im Backup vorhanden ist.

### Alle Snapshots auflisten
```bash
restic snapshots
```

### Inhalt eines Snapshots durchsuchen
```bash
restic ls latest
```

### Nach bestimmten Dateien suchen
```bash
restic find "meine-datei.txt"
restic find "/srv/docker/apps/vaultwarden/*"
```

---

## 3. Wiederherstellungsszenarien

### A. Den gesamten aktuellsten Snapshot wiederherstellen
```bash
mkdir -p /tmp/restore-full
restic restore latest --target /tmp/restore-full
```

### B. Einzelne Dateien oder Verzeichnisse wiederherstellen
```bash
# Vaultwarden-Ordner aus dem neuesten Snapshot
restic restore latest --target /tmp/restore-app --include "/srv/docker/apps/vaultwarden"

# MySQL-Dump wiederherstellen
restic restore latest --target /tmp/restore-db --include "/mysql"
```

---

## 4. Spezifische Beispiele

### Beispiel: Vaultwarden wiederherstellen

1. **Dienst stoppen:**
   ```bash
   docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml down
   ```
2. **Daten wiederherstellen:**
   ```bash
   restic restore latest --target /tmp/vw-restore --include "/srv/docker/apps/vaultwarden"
   ```
3. **Daten kopieren:**
   Kopiere die benötigten Dateien aus `/tmp/vw-restore/srv/docker/apps/vaultwarden` zurück nach `/srv/docker/apps/vaultwarden`.
4. **Dienst wieder starten:**
   ```bash
   docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml up -d
   ```

### Beispiel: MySQL / MariaDB-Instanz wiederherstellen

1. **Dump-Datei wiederherstellen:**
   ```bash
   restic restore latest --target /tmp/db-restore --include "/mysql"
   ```
2. **In die Datenbank einspielen:**
   ```bash
   gunzip -c /tmp/db-restore/mysql/CONTAINER_NAME.sql.gz | docker exec -i CONTAINER_NAME mysql -u root -p
   ```

### Beispiel: Nextcloud wiederherstellen

> Die Nextcloud-Daten liegen im Snapshot unter dem Pfad `nextcloud/` (relativ zum Snapshot-Root).

1. **Nextcloud-Dienste stoppen:**
   ```bash
   docker compose -f /srv/docker/apps/nextcloud/docker-compose.yml down
   ```

2. **Datenbank wiederherstellen:**
   ```bash
   restic restore latest --target /tmp/nc-restore --include "/nextcloud/nextcloud-db.sql.gz"
   gunzip -c /tmp/nc-restore/nextcloud/nextcloud-db.sql.gz \
     | docker exec -i nextcloud-db mariadb -u nextcloud -p nextcloud
   ```

3. **Datei-Verzeichnisse wiederherstellen** (`data`, `config`, `custom_apps`, `themes`):
   ```bash
   restic restore latest --target /tmp/nc-restore --include "/nextcloud"
   # Dateien zurückkopieren nach NEXTCLOUD_DATA_DIR
   rsync -a /tmp/nc-restore/nextcloud/data/ /srv/docker/apps/nextcloud/data/nextcloud/data/
   rsync -a /tmp/nc-restore/nextcloud/config/ /srv/docker/apps/nextcloud/data/nextcloud/config/
   ```

4. **Dienste wieder starten:**
   ```bash
   docker compose -f /srv/docker/apps/nextcloud/docker-compose.yml up -d
   ```

5. **Maintenance Mode deaktivieren (falls noch aktiv):**
   ```bash
   docker exec nextcloud-app php occ maintenance:mode --off
   ```

### Beispiel: Aus Internxt-Backup wiederherstellen

Falls das primäre Backup (1blu) nicht verfügbar ist, kann direkt vom Internxt-Remote wiederhergestellt werden. Das Restic-Repository auf Internxt ist ein vollständiges Spiegelbild.

```bash
# RESTIC_REPOSITORY temporär auf Internxt umstellen
export RESTIC_REPOSITORY="rclone:internxt-webdav:restic-repo"
restic snapshots
restic restore latest --target /tmp/restore-from-internxt
```

---

## 5. Alternative: Repository mounten (FUSE)

Am einfachsten lassen sich Dateien finden, wenn man das Backup wie ein lokales Laufwerk einbindet. Dies erfordert `fuse`.

```bash
mkdir -p /mnt/restic
restic mount /mnt/restic
```

Nun kannst du in einem zweiten Terminal ganz normal mit `cd`, `ls` und `cp` in `/mnt/restic/snapshots` navigieren und Dateien kopieren.

---

## Nächste Schritte

Für eine automatisierte oder vereinfachte Wiederherstellung kannst du auch das mitgelieferte [Restore-Skript](../restore/README.md) verwenden.
