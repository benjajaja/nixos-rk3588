# NixOS Orange Pi 5 Plus

Initially built with https://github.com/gnull/nixos-rk3588, now uses mainline NixOS kernel and
everything else.

Initially started with colmena secrets, now also uses sops.

https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix

# Services & Features

* [opifancontrol](https://github.com/jamsinclair/opifancontrol)
  * Quietly running CPU closet fans.
* LED gimmick
  * Set to indicate when online and SSH is up.
* Immich
  * Just works! As good or better as google photos.
* Matrix homeserver
  * With WhatsApp and Telegram bridges
* Torrent downloads
  * Sonarr, Radarr, and all those things.
* NFS share
  * Backup directory, torrent downloads, and general storage.
* Nightly backup to external disk
  * TODO: add some cloud backup too
* Home Assistant and Zigbee2MQTT
  * Turns on ceiling fan / light from wall switch via RF emitter.
  * Temperature, humidity and PM2.5/PM10 particle measurement.
  * Console cooling fan monitoring.

# Deploy via Colmena

```
colmena apply
```

Could probably also be done with something like `nixos-rebuild switch --flake .#ops`.

# TODO

* Cloud backup
* Fix matrix bridges
    * Permission error on read receipts to matrix
