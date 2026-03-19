# Wiederherstellung (Restore) Anleitung

Diese Anleitung beschreibt, wie Daten aus den Backups wiederhergestellt werden können.

## 1. Übersicht über Backups (Snapshots)

Um zu sehen, welche Snapshots im Repository verfügbar sind:

```bash
cd restore
./restore.sh snapshots
```

## 2. Selektive Wiederherstellung

In der Regel möchte man nicht das gesamte Backup wiederherstellen, sondern nur bestimmte Dateien oder Verzeichnisse eines bestimmten Zeitpunkts.

### Schritt A: Inhalt eines Snapshots prüfen
Nutzen Sie `ls`, um die Pfade innerhalb eines Snapshots zu sehen:

```bash
./restore.sh ls latest
```
*(latest steht hier für den aktuellsten Snapshot, Sie können aber auch eine Snapshot-ID angeben)*

### Schritt B: Bestimmten Pfad wiederherstellen
Beispiel: Nur den MySQL-Dump wiederherstellen:

```bash
./restore.sh restore latest /mysql.sql.gz
```

Beispiel: Nur eine bestimmte App-Konfiguration wiederherstellen:

```bash
./restore.sh restore <SNAPSHOT_ID> /docker/apps/meine-app
```

**Wichtige Hinweise:**
1.  **Pfad-Format**: Der Pfad muss exakt so angegeben werden, wie er in `ls` erscheint. Oft beginnt er mit `/docker/...` oder `/vaultwarden/...`. Geben Sie **nicht** den absoluten Pfad des Host-Systems (z.B. `/srv/backups/...`) an.
2.  **Zielverzeichnis**:
    *   Das Skript nutzt prioritär das als dritten Parameter übergebene Verzeichnis.
    *   Falls kein Parameter übergeben wurde, wird `RESTORE_DEFAULT_PATH` aus der `.env` genutzt (falls gesetzt).
    *   Als Fallback wird automatisch ein lokaler Ordner `restore/restore-out-<ZEITSTEMPEL>` erstellt.
    Beispiel mit manuellem Ziel: `./restore.sh restore latest /mysql.sql.gz /mein/zielpfad`
3.  **Wildcards**: Vermeiden Sie Wildcards wie `*` in den Pfaden, da die Shell diese expandieren könnte, bevor sie an das Skript übergeben werden. Geben Sie stattdessen den Ordnerpfad an, den Sie wiederherstellen möchten. Restic stellt diesen Ordner inklusive Inhalt wieder her.
4.  **Struktur**: Restic stellt die komplette Verzeichnisstruktur ab dem Root des Snapshots wieder her. Wenn Sie `/docker/apps/immich` wiederherstellen, finden Sie die Dateien unter `restore-out-.../docker/apps/immich/`.

## 3. Fortgeschrittene Methode: Repository mounten (Linux/WSL)

Wenn Sie das gesamte Repository wie ein normales Laufwerk durchsuchen möchten, können Sie es mounten (benötigt `fuse`):

```bash
sudo mkdir /mnt/restic
./restore.sh mount /mnt/restic
```

Nun können Sie in `/mnt/restic` mit `ls`, `cp` oder einem Dateimanager navigieren.

## 4. Manuelle Wiederherstellung (Restic CLI)

Da das System auf Standard-Restic basiert, können Sie alle Restic-Befehle auch direkt nutzen. Stellen Sie sicher, dass die Umgebungsvariablen aus der `.env` geladen sind:

```bash
set -a; source ../.env; set +a
restic snapshots
restic restore <ID> --target /pfad/zum/ziel --include /pfad/im/backup
```

## 5. Tipps zur MySQL-Wiederherstellung

Wenn Sie den SQL-Dump wiederhergestellt haben (`mysql.sql.gz`), können Sie ihn wie folgt in einen laufenden Container einspielen:

```bash
zcat mysql.sql.gz | docker exec -i <MYSQL_CONTAINER_NAME> /usr/bin/mysql -u root -p<PASSWORT>
```
