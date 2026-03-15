#!/bin/bash
set -Eeuo pipefail

ENV_FILE="${ENV_FILE:-/srv/restic/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Env file not found: $ENV_FILE"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ -z "${GOTIFY_URL:-}" ] || [ -z "${GOTIFY_TOKEN:-}" ]; then
    echo "GOTIFY_URL or GOTIFY_TOKEN not set"
    exit 1
fi

TITLE="${1:-Gotify Test}"
MESSAGE="${2:-Test notification from docker-backup}"
PRIORITY="${3:-5}"

curl -fsS   -F "title=${TITLE}"   -F "message=${MESSAGE}"   -F "priority=${PRIORITY}"   "${GOTIFY_URL}?token=${GOTIFY_TOKEN}"

echo
echo "Notification sent."
