# Troubleshooting

## rclone config not found

Error: Config file "/root/.config/rclone/rclone.conf" not found

Fix:

export RCLONE_CONFIG="/home/matthi/.config/rclone/rclone.conf"

Test:

rclone listremotes

Expected output: 1blu:

## Restic wrong password

Error: wrong password or no key found

Check password in `.env`:

`RESTIC_PASSWORD='...'`

Test:

```bash
source restore/setEnvironment.sh
restic snapshots
```

## Gotify notifications not working

Test manually:

curl -F "title=Test" -F "message=Gotify works"
"$GOTIFY_URL?token=$GOTIFY_TOKEN"

## systemd timer not triggering

Check timers:

systemctl list-timers

Reload configuration:

systemctl daemon-reload systemctl enable --now docker-backup.timer
