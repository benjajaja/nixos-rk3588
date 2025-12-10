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
    htop
    ncdu
    busybox
    file
    which
    tree
    gnused
    gawk

    # archives
    zip
    xz
    unzip
    p7zip
    zstd
    gnutar

    # misc
    stress-ng
    lm_sensors
    opifan.packages.${pkgs.system}.wiringOP
    opifan.packages.${pkgs.system}.opifancontrol
    fastfetch
    sqlite
    mailutils
    synapse-admin

    # servers - is this still necessary?
    nfs-utils
    ntfs3g

    # Radio
    dump1090-fa
    rtl-sdr
    rtl-ais
    rtl_433
    python313Packages.meshtastic

    # stop annoying $TERM complaints
    kitty.terminfo
  ];

  # replace default editor with neovim
  environment.variables.EDITOR = "nvim";

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
      "d /srv 0775 root users - -"
      "d /srv/backup 0770 root users - -"

      # immich - this might be because of an initial mismatch between db and fs.
      "d /srv/photos 0770 immich immich - -"
      "d /srv/photos/encoded-video 0770 immich immich - -"
      "f /srv/photos/encoded-video/.immich 0770 immich immich - -"
      "d /srv/photos/library 0770 immich immich - -"
      "f /srv/photos/library/.immich 0770 immich immich - -"
      "d /srv/photos/upload 0770 immich immich - -"
      "f /srv/photos/upload/.immich 0770 immich immich - -"
      "d /srv/photos/profile 0770 immich immich - -"
      "f /srv/photos/profile/.immich 0770 immich immich - -"
      "d /srv/photos/thumbs 0770 immich immich - -"
      "f /srv/photos/thumbs/.immich 0770 immich immich - -"
      "d /srv/photos/backups 0770 immich immich - -"
      "f /srv/photos/backups/.immich 0770 immich immich - -"

      "d /var/lib/hass/zhaquirks 0754 hass hass -"
      "C /var/lib/hass/zhaquirks/esphome_particles_quirks.py 0644 hass hass - ${./esphome_particles_quirks.py}"
    ]
  ];

  services.rpcbind.enable = true;
  services.nfs.server = {
    enable = true;
    mountdPort = 892;
    statdPort = 4000;
    exports = ''
      /srv         192.168.8.0/24(rw,fsid=0,no_subtree_check,no_root_squash,insecure)
      /srv/backup  192.168.8.0/24(rw,nohide,crossmnt,no_subtree_check,no_root_squash,insecure)
      /srv/photos  192.168.8.0/24(rw,nohide,crossmnt,no_subtree_check,no_root_squash,insecure)
      /srv/sdd     192.168.8.0/24(rw,nohide,crossmnt,no_subtree_check,no_root_squash,insecure)
    '';
  };

  systemd.services.backup-sync = import ./backup.nix { inherit pkgs; };
  systemd.timers.backup-sync = {
    description = "Run backup sync daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # Run if system was off during scheduled time
      RandomizedDelaySec = "1h";  # Randomize start time to avoid load spikes
    };
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    111 # rpcbind
    2049 # nfs
    892 # mountd
    4000 # statd
    80 # http
    443 #https
    51413 # transmission
    8020 # zigbee
    8080 # RTL stuff
    1883 # mqtt
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
  users.users.immich.extraGroups = [ "video" "render" "users" ];

  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openRPCPort = true;
    openPeerPorts = true;
    settings = {
      "download-dir" = "/srv/sdd/transmission";
      "incomplete-dir-enabled" = false;
      "rpc-bind-address" = "0.0.0.0";
      "rpc-authentication-required" = false;
      "rpc-host-whitelist-enabled" = false;
      "rpc-whitelist-enabled" = false;
      "ratio-limit" = "2.0";
      "ratio-limit-enabled" = true;
      "idle-seeding-limit" = 60;
      "idle-seeding-limit-enabled" = true;
    };
    downloadDirPermissions = "775";
  };
  users.users.transmission = {
    isSystemUser = true;
    extraGroups = ["users" "media"];
  };
  services.sonarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.sonarr_env.path ];
  };
  users.users.sonarr = {
    extraGroups = ["users" "transmission" "media"];
  };
  services.radarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.radarr_env.path ];
  };
  users.users.radarr = {
    extraGroups = ["users" "transmission" "media"];
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.sops.secrets.prowlarr_env.path ];
  };

  users.users.hass.extraGroups = ["users"];

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
    virtualHosts."http://immich, http://immich.lan" = {
      extraConfig = ''
        reverse_proxy localhost:2283
      '';
    };
    virtualHosts."http://ha, http://ha.lan" = {
      extraConfig = ''
        reverse_proxy localhost:8123
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
      tempMed = 50;
      tempHigh = 60;
      fanLow = 20;
      fanMed = 30;
      fanHigh = 40;
      debug = false;
    };
    boardType = "orangepi5plus";
  };


  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host synapse synapse ::1/128 md5
      host synapse synapse 127.0.0.1/32 md5
    '';
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
    settings = import ./matrix-synapse.nix { inherit config lib; };
    extraConfigFiles = [
      config.sops.secrets.homeserver_secrets_yaml.path
    ];
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
  systemd.services.postgresql.postStart = ''
    PSQL="${config.services.postgresql.package}/bin/psql -U postgres"
    DB_PASSWORD=$(cat ${config.sops.secrets.postgresql_synapse_password.path})
    $PSQL -tAc "SELECT 1 FROM pg_database WHERE datname='synapse'" | grep -q 1 || $PSQL -tAc "CREATE DATABASE synapse OWNER synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0"
    $PSQL -tAc "SELECT 1 FROM pg_roles WHERE rolname='synapse'" | grep -q 1 || $PSQL -tAc "CREATE USER synapse WITH PASSWORD '$DB_PASSWORD'"
    $PSQL -tAc "GRANT ALL PRIVILEGES ON DATABASE synapse TO synapse"
    $PSQL -d synapse -tAc "GRANT ALL ON SCHEMA public TO synapse"
  '';
  systemd.services.postgresql = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
  };
  systemd.services.matrix-synapse = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
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
      zha = {
        zigpy_config = {
          ota = {
            extra_providers = [
              {
                type = "advanced";
                warning = "I understand I can *destroy* my devices by enabling OTA updates from files. Some OTA updates can be mistakenly applied to the wrong device, breaking it. I am consciously using this at my own risk.";
                path = "/var/lib/hass/zigpy_ota";
              }
            ];
          };
          serial = {
            port = "socket://slzb-06.lan:6638";
            baudrate = 115200;
          };
        };
        database_path = "/var/lib/hass/zigbee.db";
        enable_quirks = true;
        custom_quirks_path = "/var/lib/hass/zhaquirks/";
      };
    };
    package = pkgs.home-assistant.override {
      extraPackages = ps:
        with ps; [
          gtts
          python-kasa
          aemet-opendata
          transmission-rpc
          aiopyarr
          zigpy-znp
        ];
    };
  };
  
  services.glances = {
    enable = true;
    openFirewall = true;
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
      relayhost = ["[smtp-relay.brevo.com]:587"];
      
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
      mynetworks = ["127.0.0.0/8"];
      
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

  services.mosquitto = {
    enable = true;
    listeners = [{
      port = 1883;
      users.meshdev = {
        passwordFile = config.sops.secrets.mosquitto-password.path;
        acl = [ "readwrite #" ];
      };
      settings.allow_anonymous = false;
    }];
    
    bridges.meshtastic_es = {
      addresses = [{ address = "mqtt.meshtastic.es"; port = 1883; }];
      topics = [
        "msh/EU_868/# out 0 \"\" \"\""
        # "msh/EU_868/2/e/LasPalmas/# in 0 \"\" \"\""
      ];
      settings = {
        cleansession = false;
        notifications = false;
        bridge_protocol_version = "mqttv50";
        remote_username = "meshdev";
        remote_password = "large4cats";  # public creds, fine as plaintext
      };
    };
    bridges.meshtastic_org = {
      addresses = [{ address = "mqtt.meshtastic.org"; port = 1883; }];
      topics = [
        "msh/EU_868/# out 0"
      ];
      settings = {
        cleansession = true;
        notifications = false;
        bridge_protocol_version = "mqttv311";
        remote_username = "meshdev";
        remote_password = "large4cats";
      };
    };
  };

  services.meshmonitor = {
    enable = false;
    meshtasticNodeIP = "192.168.8.72";
    allowedOrigins = [ "http://ops:3001" ];
    adminPassword = "12345"; # wireguarded
    openFirewall = true;
  };

  system.stateVersion = "23.11";
}
