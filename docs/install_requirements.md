# Schritt-für-Schritt Installationsanleitung

Diese Anleitung beschreibt, wie du eine neue Umgebung für die Wiederherstellung oder den Betrieb des Docker-Backup-Systems von Grund auf einrichtest.

## 1. System aktualisieren und Basis-Tools installieren

Zuerst bringen wir das System auf den neuesten Stand und installieren grundlegende Hilfswerkzeuge.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg lsb-release ca-certificates
```

## 2. Docker aus dem offiziellen Repository installieren

Um die aktuellste Version von Docker zu erhalten, nutzen wir das offizielle Docker-Repo (nicht die Standard-Paketquellen von Debian/Ubuntu).

```bash
# Docker GPG-Schlüssel hinzufügen
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Repository hinzufügen
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## 3. Benutzerrechte konfigurieren

Damit der aktuelle Benutzer Docker-Befehle ohne `sudo` ausführen kann, muss er zur Gruppe `docker` hinzugefügt werden.

```bash
# Aktuellen User zur Gruppe docker hinzufügen
sudo usermod -aG docker $USER

# Wichtig: Damit die Gruppenänderung aktiv wird, musst du dich einmal ab- und wieder anmelden oder:
newgrp docker
```

## 4. Verzeichnisinfrastruktur erstellen

Wir legen die benötigten Verzeichnisse unter `/srv/docker` und `/opt/docker-backup` an.

```bash
# Docker-Verzeichnisse erstellen
sudo mkdir -p /srv/docker/infrastructure
sudo mkdir -p /srv/docker/apps

# Besitzrechte auf den aktuellen User übertragen
sudo chown -R $USER:$USER /srv/docker

# Schreibrechte sicherstellen
chmod -R 755 /srv/docker

# Backup-Projektverzeichnis
sudo mkdir -p /opt/docker-backup
sudo chown -R $USER:$USER /opt/docker-backup
```

## 5. Restic und Rclone installieren

Diese Tools werden für die Deduplizierung und den Remote-Upload der Backups benötigt.

```bash
sudo apt install -y restic rclone
```

### Kurze Überprüfung der Installation

Du kannst prüfen, ob alle Tools korrekt installiert wurden:

```bash
docker --version
docker compose version
restic version
rclone version
```

## 6. Backup-Projekt einrichten

```bash
# Repository klonen (oder Dateien manuell kopieren)
cd /opt/docker-backup

# Konfigurationsdateien anlegen
cp .env.example .env
cp backup.conf.example backup.conf

# .env anpassen (Passwörter, Repository-Pfad, Gotify-URL)
nano .env

# backup.conf anpassen (Pfade, MySQL-Instanzen, Nextcloud-Variablen)
nano backup.conf
```

## Nächste Schritte

Nachdem die Infrastruktur steht, kannst du mit der [Konfiguration von Rclone](rclone_setup.md), der [Konfiguration des Backups](../readme.de.md#konfiguration) oder dem [Wiederherstellungs-Leitfaden](restore.md) fortfahren.
