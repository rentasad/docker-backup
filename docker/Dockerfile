# Ubuntu-basiertes Dockerfile für Docker-Backup-Tests und Wiederherstellung
# Mit Docker-in-Docker für isolierte Restore-Tests
FROM ubuntu:22.04

# Verhindere interaktive Prompts während der Installation
ENV DEBIAN_FRONTEND=noninteractive

# System aktualisieren und Basis-Tools installieren
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    iptables \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Docker GPG-Schlüssel und Repository hinzufügen
RUN mkdir -m 0755 -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker, Restic und Rclone installieren
RUN apt-get update && \
    apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    restic \
    rclone \
    && rm -rf /var/lib/apt/lists/*

# Verzeichnisinfrastruktur erstellen
RUN mkdir -p /srv/docker/infrastructure /srv/docker/apps && \
    chmod -R 755 /srv/docker

# Arbeitsverzeichnis setzen
WORKDIR /srv/docker

# Volume-Mount-Points definieren (inkl. Docker-Storage für DinD)
VOLUME ["/srv/docker/infrastructure", "/srv/docker/apps", "/var/lib/docker"]

# Entrypoint-Script für Docker-in-Docker erstellen
RUN echo '#!/bin/bash\n\
set -e\n\
# Docker-Daemon im Hintergrund starten\n\
dockerd &\n\
# Warten bis Docker bereit ist\n\
timeout=30\n\
while ! docker info > /dev/null 2>&1; do\n\
  timeout=$((timeout - 1))\n\
  if [ $timeout -le 0 ]; then\n\
    echo "Docker daemon failed to start"\n\
    exit 1\n\
  fi\n\
  sleep 1\n\
done\n\
echo "Docker daemon is ready"\n\
# Shell starten oder übergebenen Befehl ausführen\n\
exec "$@"\n\
' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
