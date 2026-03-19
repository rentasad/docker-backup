# Installation der Voraussetzungen

Eine funktionierende Docker-Installation wird vorausgesetzt.

Rclone und Restic und curl kann einfach via apt installiert werden.

apt install rclone restic curl


##  Einrichtung von RClone

in ~/.config/rclone/rclone.conf wird die Verbindung zum Webdav-Speicher hinterlegt:

[1blu]
type = webdav
url = https://PathToYourWebdavServer
vendor = other
user = username
pass = superSecurePassword

