{
  config,
  lib,
  pkgs,
  nixpkgs,
  opifan,
  ...
}: let
  domain = "qdice.wtf";

  clientConfig."m.homeserver".base_url = "https://${domain}";
  serverConfig."m.server" = "${domain}:443";
in {
  # =========================================================================
  #      Base NixOS Configuration
  # =========================================================================
  # nix run nixpkgs#colmena apply -- --impure

  sops = import ./sops.nix;
  # Set your time zone.
  time.timeZone = "Atlantic/Canary";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings = {
    # Manual optimise storage: nix-store --optimise
    # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
    auto-optimise-store = true;
    builders-use-substitutes = true;
    # enable flakes globally
    experimental-features = ["nix-command" "flakes"];
  };
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # make `nix run nixpkgs#nixpkgs` use the same nixpkgs as the one used by this flake.
  nix.registry.nixpkgs.flake = nixpkgs;
  # make `nix repl '<nixpkgs>'` use the same nixpkgs as the one used by this flake.
  environment.etc."nix/inputs/nixpkgs".source = "${nixpkgs}";
  nix.nixPath = ["/etc/nix/inputs"];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  #
  # TODO feel free to add or remove packages here.
  environment.systemPackages = with pkgs; [
    neovim

    # networking
    mtr # A network diagnostic tool
    iperf3 # A tool for measuring TCP and UDP bandwidth performance
    nmap # A utility for network discovery and security auditing
    ldns # replacement of dig, it provide the command `drill`
    socat # replacement of openbsd-netcat
    tcpdump # A powerful command-line packet analyzer

    # archives
    zip
    xz
    unzip
    p7zip
    zstd
    gnutar

    # misc
    file
    which
    tree
    gnused
    gawk
    busybox
    stress-ng
    lm_sensors
    opifan.packages.${pkgs.system}.wiringOP
    opifan.packages.${pkgs.system}.opifancontrol
    ncdu
    fastfetch
    sqlite
    mailutils

    # servers - is this still necessary?
    nfs-utils
    ntfs3g

    # Radio
    dump1090
    rtl-sdr
    rtl-ais
    rtl_433

    # stop annoying $TERM complaints
    kitty.terminfo
  ];

  # replace default editor with neovim
  environment.variables.EDITOR = "nvim";

  networking.firewall.enable = true;

  virtualisation.docker = {
    enable = false;
  };

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "prohibit-password"; # disable root login with password
      PasswordAuthentication = false; # disable password login
    };
    openFirewall = true;
  };

  systemd.tmpfiles.rules = builtins.concatLists [
    # Type | Path | Mode | User | Group | Age | Argument
    [
      "d /srv 0777 root users - -"
      "d /srv/backup 0777 root users - -"
      "d /srv/media 0777 root users - -"
      "d /srv/media/torrents 0777 transmission users - -"
      "d /srv/media/torrents/radarr 0777 transmission users - -"
      "d /srv/media/torrents/sonarr 0777 transmission users - -"

      # matrix secrets
      "d /var/lib/matrix-synapse/secrets 0700 matrix-synapse matrix-synapse -"
      "L+ /var/lib/matrix-synapse/homeserver.yaml - - - - ${./homeserver.yaml}"

      # immich - this might be because of an initial mismatch between db and fs.
      "d /srv/photos 0777 immich immich - -"
      "d /srv/photos/encoded-video 0777 immich immich - -"
      "f /srv/photos/encoded-video/.immich 0777 immich immich - -"
      "d /srv/photos/library 0777 immich immich - -"
      "f /srv/photos/library/.immich 0777 immich immich - -"
      "d /srv/photos/upload 0777 immich immich - -"
      "f /srv/photos/upload/.immich 0777 immich immich - -"
      "d /srv/photos/profile 0777 immich immich - -"
      "f /srv/photos/profile/.immich 0777 immich immich - -"
      "d /srv/photos/thumbs 0777 immich immich - -"
      "f /srv/photos/thumbs/.immich 0777 immich immich - -"
      "d /srv/photos/backups 0777 immich immich - -"
      "f /srv/photos/backups/.immich 0777 immich immich - -"
    ]
  ];

  services.rpcbind.enable = true;
  services.nfs.server = {
    enable = true;
    mountdPort = 892;
    statdPort = 4000;
    exports = ''
      /srv         192.168.8.0/24(rw,fsid=0,no_subtree_check,no_root_squash,insecure)
      /srv/media   192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/backup  192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/photos  192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/sdd     192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
    '';
  };

  systemd.services.backup-sync = {
    description = "Sync Pictures and Documents to backup disk";
    conflicts = [ "matrix-synapse.service" ]; # Stop matrix on start.
    script = ''
      set -euo pipefail  # Exit on error, undefined variables, and pipe failures
      
      echo "Starting backup sync at $(date)"
      
      # For photos
      echo "Backing up photos (quiet)..."
      ${pkgs.rsync}/bin/rsync -a --delete /srv/photos/ /srv/sdd/backup/immich/photos/
      
      # For Matrix Synapse - safely backup the SQLite database
      echo "Backing up Matrix Synapse database..."
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/matrix-synapse/homeserver.db ".backup /tmp/homeserver_backup.db"
      ${pkgs.rsync}/bin/rsync -av --delete /tmp/homeserver_backup.db /srv/sdd/backup/matrix/
      rm /tmp/homeserver_backup.db
      
      # Backup other Matrix files
      echo "Backing up Matrix Synapse secrets..."
      ${pkgs.rsync}/bin/rsync -av --delete /var/lib/matrix-synapse/secrets /srv/sdd/backup/matrix/secrets/
      
      echo "Backing up Matrix Synapse media_store (quiet)..."
      ${pkgs.rsync}/bin/rsync -a --delete /var/lib/matrix-synapse/media_store /srv/sdd/backup/matrix/media_store/
      
      echo "Backing up Matrix Synapse media_store (quiet)..."
      ${pkgs.rsync}/bin/rsync -a --delete /var/lib/matrix-synapse/media_store /srv/sdd/backup/matrix/media_store/
      
      echo "Backup sync completed successfully at $(date)"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";  # Needed for Matrix Synapse files
      Nice = 19;  # Low priority
      IOSchedulingClass = "idle";  # Low I/O priority
      StandardOutput = "journal";
      StandardError = "journal";
    };
    # Ensure matrix-synapse is started again after backup completes
    # (whether successful or failed)
    unitConfig = {
      OnSuccess = "matrix-synapse.service";
      OnFailure = "matrix-synapse.service";
    };
  };

  systemd.timers.backup-sync = {
    description = "Run backup sync daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # Run if system was off during scheduled time
      RandomizedDelaySec = "1h";  # Randomize start time to avoid load spikes
    };
  };

  networking.firewall.allowedTCPPorts = [
    111 # rpcbind
    2049 # nfs
    892 # mountd
    4000 # statd
    80 # http
    443 #https
    51413 # transmission
    1883 # mqtt
    8020 # zigbee
    8080 # RTL stuff
  ];
  networking.firewall.allowedUDPPorts = [
    111 # rpcbind
    2049 # nfs
    892 # mountd
    4000 # statd
    51413 # transmission
  ];

  programs = {
    bash = {
      shellAliases = {
        nv = "nvim";
      };
      interactiveShellInit = ''
        set -o vi
        set show-mode-in-prompt on
        set vi-cmd-mode-string "\1\e[2 q\2"
        set vi-ins-mode-string "\1\e[6 q\2"
      '';
    };
  };

  systemd.services.led-control = {
    description = "Orange Pi 5 LED gimmick";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "sshd.service" ];
    wants = [ "network-online.target" "sshd.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeShellScript "disable-blue-enable-green-led" ''
        echo none > /sys/class/leds/blue:indicator-1/trigger
        echo 0 > /sys/class/leds/blue:indicator-1/brightness

        echo default-on > /sys/class/leds/green:indicator-2/trigger
      ''}";
      RemainAfterExit = true;
    };
  };

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    accelerationDevices = null;
    mediaLocation = "/srv/photos";
    openFirewall = true;
  };
  # users.users.immich.extraGroups = [ "video" "render" "users" ];

  services.transmission = {
    enable = true;
    openRPCPort = true;
    openPeerPorts = true;
    settings = {
      "download-dir" = "/srv/media/torrents";
      "rpc-bind-address" = "0.0.0.0";
      "rpc-authentication-required" = false;
      "rpc-host-whitelist-enabled" = false;
      "rpc-whitelist-enabled" = false;
      "ratio-limit" = "2.0";
      "ratio-limit-enabled" = true;
      "idle-seeding-limit" = 60;
      "idle-seeding-limit-enabled" = true;
    };
    downloadDirPermissions = "770";
  };
  users.users.transmission = {
    isSystemUser = true;
    extraGroups = ["users"]; # let it write (move files) to /srv/media
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.sonarr_env.path ];
  };
  users.users.sonarr = {
    extraGroups = ["users" "transmission"];
  };
  services.radarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.radarr_env.path ];
  };
  users.users.radarr = {
    extraGroups = ["users" "transmission"];
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.prowlarr_env.path ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."qdice.wtf" = {
      extraConfig = ''
        handle / {
          respond 503
        }
        handle_path /.well-known/matrix/server {
          header Content-Type application/json
          header Access-Control-Allow-Origin *
          respond `${builtins.toJSON serverConfig}` 200
        }

        handle_path /.well-known/matrix/client {
          header Content-Type application/json
          header Access-Control-Allow-Origin *
          respond `${builtins.toJSON clientConfig}` 200
        }

        reverse_proxy 127.0.0.1:8008
      '';
    };
    virtualHosts."photos.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:2283
      '';
    };
    virtualHosts."ha.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:8123
      '';
    };

    virtualHosts."ops" = {
      extraConfig = ''
        tls internal
        reverse_proxy localhost:8082
      '';
    };
    virtualHosts."kuma.ops" = {
      extraConfig = ''
        tls internal
        reverse_proxy localhost:3001
      '';
    };
  };

  services.opifancontrol = {
    enable = true;
    fans."cpu" = {
      fanGpioPin = 6;
      tempLow = 35;
      tempMed = 45;
      tempHigh = 50;
      fanLow = 30;
      fanMed = 50;
      fanHigh = 60;
      debug = false;
    };
    fans."closet" = {
      fanGpioPin = 22;
      tempLow = 40;
      tempMed = 45;
      tempHigh = 50;
      fanLow = 20;
      fanMed = 30;
      fanHigh = 40;
      debug = false;
    };
    boardType = "orangepi5plus";
  };

  services.matrix-synapse = {
    enable = true;
    extras = [
      "oidc"
      "systemd"
      "url-preview"
      # "cache-memory", "jwt", "oidc", "postgres", "redis", "saml2", "sentry", "systemd", "url-preview"
      # "user-search"
    ];
    extraConfigFiles = [
      "/var/lib/matrix-synapse/homeserver.yaml"
      config.sops.secrets.homeserver_secrets_yaml.path
    ];
    settings = {
      database = {
        name = "sqlite3";
        args.database = "/var/lib/matrix-synapse/homeserver.db";
      };
      signing_key_path = config.sops.secrets.qdice_wtf_signing_key.path;
      app_service_config_files = [ config.sops.secrets.doublepuppet_yaml.path ];
    };
  };
  services.mautrix-telegram = {
    enable = true;
    settings = import ./mautrix-telegram.nix;
    environmentFile = config.sops.secrets.mautrix_telegram_env.path;
  };
  services.mautrix-whatsapp = {
    enable = true;
    settings = import ./mautrix-whatsapp.nix;
    environmentFile = config.sops.secrets.mautrix_whatsapp_env.path;
  };

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    config = {
      homeassistant = {
        name = "Home";
        # latitude = "!secret latitude";
        # longitude = "!secret longitude";
        # elevation = "!secret elevation";
        unit_system = "metric";
        time_zone = "UTC";
      };
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };
      mobile_app = {};
      recorder = {
        db_url = "sqlite:////var/lib/hass/home-assistant_v2.db";
      };
      automation = "!include automations.yaml";
      history = {};
    };
    package = pkgs.home-assistant.override {
      extraPackages = ps:
        with ps; [
          paho-mqtt
          gtts
          roombapy
          python-kasa
          aemet-opendata
          glances-api
          transmission-rpc
          aiopyarr
        ];
    };
  };
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        acl = ["pattern readwrite #"];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  services.glances = {
    enable = true;
    openFirewall = true;
  };
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services.udev.packages = with pkgs; [
    rtl-sdr
  ];

  services.postfix = {
    enable = true;
    setSendmail = true;
    
    config = {
      # Listen only on localhost
      inet_interfaces = "localhost";
      inet_protocols = "ipv4";
      
      # Relay all mail directly to MailerSend (replaces msmtp)
      relayhost = "[smtp.mailersend.net]:587";
      
      # SASL authentication for Postfix to authenticate TO MailerSend
      smtp_sasl_auth_enable = true;
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_password_maps = "texthash:${config.sops.secrets."postfix_sasl_passwords".path}";
      smtp_tls_security_level = "encrypt";
      smtp_tls_wrappermode = false;
      
      # Security: only accept mail from localhost, no auth required from clients
      smtpd_relay_restrictions = [
        "permit_mynetworks"
        "reject_unauth_destination"
      ];
      mynetworks = "127.0.0.0/8";
      
      # Disable SMTP server authentication (clients don't need to auth to us)
      smtpd_sasl_auth_enable = false;
      
      # Disable local delivery
      mydestination = "";
      local_recipient_maps = "";
      local_transport = "error:local mail delivery is disabled";
      
      # Simple configuration
      compatibility_level = "3.6";
    };
  };

  system.stateVersion = "23.11";
}
