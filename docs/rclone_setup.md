# Rclone Konfiguration

Diese Anleitung beschreibt, wie du Rclone für die Verbindung zu deinem Cloud-Speicher (Remote) konfigurierst. Rclone dient als Übertragungsschicht für Restic, um die verschlüsselten Backups sicher auf externen Speicher zu übertragen.

## 1. Konfigurationsmethoden

Es gibt zwei Wege, Rclone zu konfigurieren:

### A. Interaktiver Assistent (Empfohlen für neue Setups)

Rclone bietet einen geführten Assistenten, der dich durch alle notwendigen Einstellungen leitet.

```bash
rclone config
```

1. Wähle `n` für "New remote".
2. Gib einen Namen ein (z. B. `1blu` oder `hetzner`).
3. Wähle den Typ des Speichers aus der Liste (z. B. `webdav` oder `s3`).
4. Folge den spezifischen Anweisungen für deinen Anbieter.

### B. Manuelle Konfiguration (Direktes Editieren)

Du kannst die Konfigurationsdatei auch direkt bearbeiten oder erstellen. Rclone ist ein Kommandozeilenwerkzeug (CLI) und **kein Hintergrunddienst**. Das bedeutet:
- Es ist **kein Neustart** eines Dienstes erforderlich.
- Rclone liest die Konfigurationsdatei bei **jedem Befehlsaufruf** neu ein.

Der Standardpfad für die Konfiguration ist `~/.config/rclone/rclone.config`.

Hier sind zwei Beispiele für häufig genutzte Anbieter in diesem Projekt:

#### Beispiel: 1blu (WebDAV)
```ini
[1blu]
type = webdav
url = https://u318508.oberon.1blu.de
vendor = other
user = [dein_benutzername]
pass = [dein_verschlüsseltes_passwort]
```

#### Beispiel: Hetzner Object Storage (S3)
```ini
[hetzner]
type = s3
provider = Hetzner
access_key_id = [dein_key_id]
secret_access_key = [dein_secret]
region = fsn1
endpoint = fsn1.your-objectstorage.com
```

> **Hinweis zur Sicherheit:** Passwörter in der `rclone.config` sind standardmäßig mit einem einfachen Verfahren verschleiert. Wenn du sie manuell einträgst, kannst du `rclone obscure "dein_passwort"` nutzen, um den verschleierten String für das Feld `pass` zu generieren.

## 2. Speicherort der Konfiguration

Stelle sicher, dass die Datei die richtigen Berechtigungen hat, da sie Zugangsdaten enthält:

```bash
mkdir -p ~/.config/rclone
chmod 700 ~/.config/rclone
chmod 600 ~/.config/rclone/rclone.config
```

## 3. Funktionstests

Nachdem die Konfiguration abgeschlossen ist, solltest du prüfen, ob Rclone deine Remotes erkennt und die Verbindung testen.

### Remotes auflisten
Prüfe, ob deine konfigurierten Remotes (z. B. `1blu`, `hetzner`) in der Liste erscheinen:
```bash
rclone listremotes
```

### Verbindung prüfen
Listet alle Verzeichnisse im Root des Remotes auf:
```bash
rclone lsd [remote_name]:
```

### Schreibtest
Erstelle eine Testdatei und lade sie hoch:
```bash
echo "test" > rclone_test.txt
rclone copy rclone_test.txt [remote_name]:
```

### Verifizierung
Prüfe, ob die Datei auf dem Remote existiert:
```bash
rclone ls [remote_name]:rclone_test.txt
```

### Aufräumen
Lösche die Testdatei wieder:
```bash
rclone delete [remote_name]:rclone_test.txt
rm rclone_test.txt
```

## Nächste Schritte

Sobald die Verbindung steht, kannst du das Restic-Repository initialisieren. Siehe dazu die [Hauptanleitung](../readme.de.md#3-restic-repository-initialisieren).
