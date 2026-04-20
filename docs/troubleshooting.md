# Troubleshooting

## rclone config not found

**Error:** `Config file "/root/.config/rclone/rclone.conf" not found`

**Fix:** Stelle sicher, dass `RCLONE_CONFIG` in der `.env` auf den korrekten Pfad zeigt:

```env
RCLONE_CONFIG=/root/.config/rclone/rclone.conf
```

**Test:**
```bash
rclone listremotes
```

---

## Restic wrong password

**Error:** `wrong password or no key found`

Überprüfe das Passwort in der `.env`:

```env
RESTIC_PASSWORD='...'
```

**Test:**
```bash
source restore/setEnvironment.sh
restic snapshots
```

---

## Gotify notifications not working

**Test:**
```bash
curl -F "title=Test" -F "message=Gotify works" "$GOTIFY_URL?token=$GOTIFY_TOKEN"
```

---

## systemd timer not triggering

**Prüfen:**
```bash
systemctl list-timers
```

**Neu laden:**
```bash
systemctl daemon-reload
systemctl enable --now docker-backup.timer
```

---

## MySQL Backup - Access Denied

**Error:** `mysqldump: Got error: 1045: Access denied for user 'backup'@'localhost'`

Der MySQL-Benutzer muss in der betroffenen Instanz angelegt sein und die notwendigen Berechtigungen haben:

```sql
CREATE USER 'backup'@'%' IDENTIFIED BY 'dein_passwort';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON *.* TO 'backup'@'%';
FLUSH PRIVILEGES;
```

Stelle sicher, dass in `backup.conf` / `.env` das korrekte Passwort hinterlegt ist.

---

## Nextcloud DB-Dump schlägt fehl (Exit 127)

**Error:** `mysqldump: executable file not found in $PATH`

Neuere MariaDB-Images haben `mysqldump` durch `mariadb-dump` ersetzt. Das Script erkennt dies automatisch. Falls die Autodetection nicht greift, kannst du den Befehl explizit setzen:

```bash
# in backup.conf
NEXTCLOUD_DB_DUMP_CMD=mariadb-dump
```

**Prüfen was im Container verfügbar ist:**
```bash
docker exec nextcloud-db which mariadb-dump
docker exec nextcloud-db ls /usr/bin/ | grep -E 'dump|mysql|maria'
```

---

## Nextcloud bleibt im Maintenance Mode

Falls das Backup unterbrochen wurde und Nextcloud im Maintenance Mode feststeckt:

```bash
docker exec nextcloud-app php occ maintenance:mode --off
```

---

## Internxt-Sync wird übersprungen

Das Script prüft vor dem Sync ob der Remote erreichbar ist. Wenn nicht, wird der Sync übersprungen (kein Fehler).

**Manuell testen:**
```bash
rclone lsd internxt-webdav: --no-check-certificate --contimeout 10s --timeout 30s
```

Stelle sicher, dass der Remote-Name in `backup.conf` mit dem Namen in der `rclone.conf` übereinstimmt:

```bash
# backup.conf
INTERNXT_RCLONE_REMOTE="internxt-webdav"

# rclone.conf
[internxt-webdav]
...
```

---

## Passwort mit Sonderzeichen funktioniert nicht

Passwörter in der `.env` mit Sonderzeichen wie `*`, `$`, `!`, `\` sollten in einfache Anführungszeichen gesetzt werden:

```env
MYSQL_PASSWORD='mein*Passwort!'
RESTIC_PASSWORD='geheim$123'
```

Single Quotes verhindern jegliche Shell-Interpretation. Nur ein `'` selbst im Passwort wäre problematisch – dann Double Quotes verwenden.
