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

    # servers
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
      "d /srv/media/Movies 0777 root users - -"
      "d /srv/media/TV\ Shows 0777 root users - -"
      "d /srv/media/torrents/radarr 0777 transmission users - -"
      "d /srv/media/torrents/sonarr 0777 transmission users - -"
      # "L+ /srv/sdd - - - - /mnt/backup" # stupid kodi only sees the root

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
    mountdPort = 892; # ignored, but forced again in systemd.services.nfs-mountd
    statdPort = 4000;
    exports = ''
      /srv         192.168.8.0/24(rw,fsid=0,no_subtree_check,no_root_squash,insecure)
      /srv/media   192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/backup  192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/photos  192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
      /srv/sdd     192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
    '';
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

  # Patch the units because they are not generated, yet no build error, probably due to nfsd and friends coming from the armbian kernel.
  systemd.services."nfs-mountd" = {
    description = "NFS Mount Daemon HACK!";
    requires = ["proc-fs-nfsd.mount"];
    wants = ["network-online.target"];
    after = [
      "proc-fs-nfsd.mount"
      "network-online.target"
      "local-fs.target"
      "rpcbind.socket"
    ];
    bindsTo = ["nfs-server.service"];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.nfs-utils}/bin/rpc.mountd --port 892";

      Environment = [
        "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
        "PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin"
        "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      ];
    };
    wantedBy = ["multi-user.target"];
  };
  systemd.services.nfs-server = {
    description = "NFS server and services HACK! for armbian kernel with nixos";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.nfs-utils}/bin/exportfs -r";
      ExecStart = "${pkgs.nfs-utils}/bin/rpc.nfsd";
      ExecStop = "${pkgs.nfs-utils}/bin/rpc.nfsd 0";
      ExecStopPost = "${pkgs.runtimeShell} -c '${pkgs.nfs-utils}/bin/exportfs -au && ${pkgs.nfs-utils}/bin/exportfs -f'";
    };
    requires = ["nfs-mountd.service" "rpcbind.socket"];
    wants = ["network-online.target"];
    after = ["network-online.target" "proc-fs-nfsd.mount" "nfs-mountd.service" "rpcbind.socket"];
  };

  systemd.services.led-control = {
    description = "Orange Pi 5 LED gimmick";
    wantedBy = [ "multi-user.target" ];
    after = [ "sshd.service" ];
    wants = [ "sshd.service" ];

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
    settings.auth.apikey = builtins.getEnv "SONARR_KEY";
  };
  users.users.sonarr = {
    extraGroups = ["users" "transmission"];
  };
  services.radarr = {
    enable = true;
    openFirewall = true;
    settings.auth.apikey = builtins.getEnv "RADARR_KEY";
  };
  users.users.radarr = {
    extraGroups = ["users" "transmission"];
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;
    settings.auth.apikey = builtins.getEnv "PROWLARR_KEY";
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
      # "user-search"
    ];
    extraConfigFiles = ["/run/matrix-config/homeserver.yaml"];
    settings = {
      database = {
        name = "sqlite3";
        args.database = "/var/lib/matrix-synapse/homeserver.db";
      };
      signing_key_path = "/run/matrix-config/qdice.wtf.signing.key";
      app_service_config_files = [
        "/run/matrix-config/doublepuppet.yaml"
      ];
    };
  };
  services.mautrix-telegram = {
    enable = true;
    settings = import ./mautrix-telegram.nix;
    environmentFile = "/run/matrix-config/mautrix-telegram.env";
  };
  services.mautrix-whatsapp = {
    enable = true;
    settings = import ./mautrix-whatsapp.nix;
    environmentFile = "/run/matrix-config/mautrix-whatsapp.env";
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

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;  # Enable HA integration
      permit_join = false;
      mqtt = {
        server = "mqtt://localhost:1883";
      };
      serial = {
        # port = "/dev/ttyACM0";
        port = "tcp://orangepipc:8888";
        adapter = "zstack";
      };
      frontend = {
        port = 8020;
      };
      advanced = {
        log_level = "debug";
        channel = 15; # router uses 11 and 44, AP uses 1
      };
      devices = {
        "0xfc4d6afffe4e5dab" = {
          friendly_name = "Switch Bedroom Benja";
        };
        "0xfc4d6afffecbf7f3" = {
          friendly_name = "Switch Living Room";
        };
        "0x6cfd22fffe6c058b" = {
          friendly_name = "LED Strip Benja";
        };
        "0xfc4d6afffecbfa28" = {
          friendly_name = "Switch Bedroom Laia";
        };
      };
    };
  };
  systemd.services.zigbee2mqtt = { # Add systemd service overrides, e.g. re-plugging dongle
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5s";
    };
  };
  users.users.zigbee2mqtt.extraGroups = [ "dialout" ];

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

  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    allowedHosts = "ops,ops.lan,ops:8082";
    widgets = [
      {
        openmeteo = {
          label = "Lanzarote";
          units = "metric";
          latitude = 28.96302000;
          longitude = -13.54769000;
          cache = 5;
        };
      }
      {
        resources = {
          cpu = true;
          memory = true;
          cputemp = true;
          uptime = true;
          units = "metric";
          refresh = 3000;
        };
      }
      {
        resources = {
          label = "/";
          disk = ["/"];
        };
      }
      {
        resources = {
          label = "/mnt/backup";
          disk = ["/mnt/backup"];
        };
      }
    ];
    services = [
      {
        "System" = [
          {
            "CPU" = {
              icon = "glances";
              href = "http://ops:61208";
              widget = {
                type = "glances";
                url = "http://localhost:61208";
                version = 4;
                metric = "cpu";
              };
            };
          }
          {
            "Memory" = {
              widget = {
                type = "glances";
                url = "http://localhost:61208";
                version = 4;
                metric = "memory";
              };
            };
          }
          {
            "Network" = {
              widget = {
                type = "glances";
                url = "http://localhost:61208";
                version = 4;
                metric = "network:enP3p49s0";
              };
            };
          }
          {
            "Processes" = {
              widget = {
                type = "glances";
                url = "http://localhost:61208";
                version = 4;
                metric = "process";
              };
            };
          }
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma";
              href = "http://kuma.ops";
              description = "Uptime monitor";
              widget = {
                type = "uptimekuma";
                url = "http://localhost:3001";
                slug = "default";
              };
            };
          }
        ];
      }
      {
        "Servers" = [
          {
            Immich = {
              icon = "immich";
              href = "https://photos.${domain}";
              description = "Immich picture server";
              widget = {
                type = "immich";
                url = "https://photos.${domain}";
                key = builtins.getEnv "IMMICH_ADMIN_KEY";
                version = 2;
              };
            };
          }
          {
            Caddy = {
              icon = "caddy";
              description = "Caddy web server";
              widget = {
                type = "caddy";
                url = "http://localhost:2019";
              };
            };
          }
          {
            HomeAssistant = {
              icon = "home-assistant";
              description = "Home Assistant";
              href = "https://ha.${domain}";
              widget = {
                type = "homeassistant";
                url = "http://localhost:8123";
                key = builtins.getEnv "HASS_KEY";
                custom = [
                  {
                    state = "sensor.esp32ps5_temperature";
                    label = "PS5 Temperature";
                  }
                ];
              };
            };
          }
        ];
      }
      {
        "Downloads" = [
          {
            Transmission = {
              icon = "transmission";
              description = "Torrent client";
              widget = {
                type = "transmission";
                url = "http://localhost:9091";
              };
            };
          }
          {
            Radarr = {
              icon = "radarr";
              href = "http://ops:7878";
              description = "Movies";
              widget = {
                type = "radarr";
                url = "http://localhost:7878";
                key = builtins.getEnv "RADARR_KEY";
                enableBlocks = true;
                showEpisodeNumber = true;
              };
            };
          }
          {
            Sonarr = {
              icon = "sonarr";
              href = "http://ops:8989";
              description = "TV Shows";
              widget = {
                type = "sonarr";
                url = "http://localhost:8989";
                key = builtins.getEnv "SONARR_KEY";
                enableBlocks = true;
                showEpisodeNumber = true;
              };
            };
          }
          {
            Prowlarr = {
              icon = "prowlarr";
              href = "http://ops:9696";
              description = "Trackers";
              widget = {
                type = "prowlarr";
                url = "http://localhost:9696";
                key = builtins.getEnv "PROWLARR_KEY";
              };
            };
          }
        ];
      }
    ];
  };

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services.udev.packages = with pkgs; [
    rtl-sdr
  ];

  system.stateVersion = "23.11";
}
