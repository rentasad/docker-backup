# Wiederherstellungs-Leitfaden (Restore Guide)

Dieses Dokument beschreibt, wie du Daten aus deinen Backups suchen, finden und wiederherstellen kannst. Es ergänzt das [Hilfsskript im `restore/` Verzeichnis](../restore/README.md).

## 1. Voraussetzungen & Vorbereitung

Bevor du mit der Wiederherstellung beginnst, stelle sicher, dass:
- Restic und Rclone installiert sind (siehe [Installationsanleitung](install_requirements.md)).
- Deine `rclone.config` korrekt eingerichtet ist (siehe [Rclone Setup](rclone_setup.md)).
- Du Zugriff auf das Restic-Passwort hast (üblicherweise in der `.env` Datei).

### Umgebungsvariablen setzen
Bevor du manuelle Restic-Befehle ausführst, musst du die Umgebungsvariablen laden. Nutze dafür das bereitgestellte Skript im `restore/` Verzeichnis:

```bash
# In das Projekt-Verzeichnis wechseln
cd /srv/restic

# Umgebung laden
source restore/setEnvironment.sh
```

Nun sind `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` (oder `RESTIC_PASSWORD_FILE`) und `RCLONE_CONFIG` in deiner aktuellen Shell-Sitzung gesetzt.

---

## 2. Suchen & Finden (Snapshots und Dateien)

Bevor du etwas wiederherstellst, musst du wissen, was im Backup vorhanden ist.

### Alle Snapshots auflisten
Zeigt alle verfügbaren Zeitpunkte (Snapshots) an:
```bash
restic snapshots
```

### Inhalt eines Snapshots durchsuchen (ls)
Um zu sehen, welche Dateien in einem Snapshot (`latest` oder eine spezifische ID) enthalten sind:
```bash
restic ls latest
```

### Nach bestimmten Dateien suchen (find)
Wenn du nicht weißt, in welchem Snapshot oder unter welchem Pfad eine Datei liegt:
```bash
restic find "meine-datei.txt"
restic find "/srv/docker/apps/vaultwarden/*"
```

---

## 3. Wiederherstellungsszenarien

### A. Den gesamten aktuellsten Snapshot wiederherstellen
Nützlich für einen kompletten Server-Umzug oder nach einem Totalausfall:
```bash
mkdir -p /tmp/restore-full
restic restore latest --target /tmp/restore-full
```

### B. Einzelne Dateien oder Verzeichnisse wiederherstellen
Oft möchte man nur eine bestimmte Konfiguration oder Datenbank zurückholen:
```bash
# Stellt nur den Ordner 'vaultwarden' aus dem neuesten Snapshot wieder her
restic restore latest --target /tmp/restore-app --include "/srv/docker/apps/vaultwarden"

# Stellt nur den MySQL-Dump wieder her
restic restore latest --target /tmp/restore-db --include "/mysql.sql.gz"
```

---

## 4. Spezifische Beispiele

### Beispiel: Vaultwarden wiederherstellen
Vaultwarden speichert seine Daten oft in einem Volume oder Verzeichnis.

1. **Dienst stoppen:**
   ```bash
   docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml down
   ```
2. **Daten wiederherstellen (in ein temporäres Verzeichnis):**
   ```bash
   restic restore latest --target /tmp/vw-restore --include "/srv/docker/apps/vaultwarden"
   ```
3. **Daten kopieren:**
   Kopiere die benötigten Dateien aus `/tmp/vw-restore/srv/docker/apps/vaultwarden` zurück nach `/srv/docker/apps/vaultwarden`.
4. **Dienst wieder starten:**
   ```bash
   docker compose -f /srv/docker/apps/vaultwarden/docker-compose.yml up -d
   ```

### Beispiel: MySQL / MariaDB wiederherstellen
Wenn du einen gzipped SQL-Dump (`mysql.sql.gz`) im Backup hast:

1. **Datei wiederherstellen:**
   ```bash
   restic restore latest --target /tmp/db-restore --include "/mysql.sql.gz"
   ```
2. **In die Datenbank einspielen:**
   ```bash
   gunzip -c /tmp/db-restore/mysql.sql.gz | docker exec -i [CONTAINER_NAME] mysql -u root -p
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
