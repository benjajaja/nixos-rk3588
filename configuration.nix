{
  config,
  lib,
  pkgs,
  nixpkgs,
  opifan,
  ...
}:
let 
  domain = "qdice.wtf";
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

    # servers
    nfs-utils
    ntfs3g

    # stop annoying $TERM complaints
    kitty.terminfo
  ];

  # replace default editor with neovim
  environment.variables.EDITOR = "nvim";

  networking.firewall.enable = true;

  virtualisation.docker = {
    enable = false;
    # start dockerd on boot.
    # This is required for containers which are created with the `--restart=always` flag to work.
    enableOnBoot = false;
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
      # matrix
      # "d /var/lib/matrix-synapse 0750 matrix-synapse matrix-synapse -"
      # "d /var/lib/matrix-synapse/media 0750 matrix-synapse matrix-synapse -"
      # "d /var/lib/mautrix-telegram 0750 mautrix-telegram mautrix-telegram -"
      # "d /var/lib/mautrix-whatsapp 0750 mautrix-whatsapp mautrix-whatsapp -"
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
      /mnt/backup  192.168.8.0/24(rw,nohide,insecure,no_subtree_check,no_root_squash,insecure)
    '';
  };
  networking.firewall.allowedTCPPorts = [
    111 # rpcbind
    2049 # nfs
    892 # mountd
    4000 # statd
    80 # http / caddy
    443
    51413 # transmission
  ];
  networking.firewall.allowedUDPPorts = [
    111 # rpcbind
    2049 # nfs
    892 # mountd
    4000 # statd
    51413 # transmission
  ];

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
      # ExecStopPost = "\"${pkgs.nfs-utils}/bin/exportfs -au && ${pkgs.nfs-utils}/bin/exportfs -f\"";
      ExecStopPost = "${pkgs.runtimeShell} -c '${pkgs.nfs-utils}/bin/exportfs -au && ${pkgs.nfs-utils}/bin/exportfs -f'";
    };
    requires = ["nfs-mountd.service" "rpcbind.socket"];
    after = ["network-online.target" "proc-fs-nfsd.mount" "nfs-mountd.service" "rpcbind.socket"];
  };

  systemd.services.led-control = {
    description = "Orange Pi 5 LED gimmick";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeShellScript "disable-blue-enable-green-led" ''
        echo none > /sys/class/leds/blue_led/trigger
        echo 0 > /sys/class/leds/blue_led/brightness

        echo default-on > /sys/class/leds/green_led/trigger
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

  services.flaresolverr = {
    enable = false;
    openFirewall = true;
  };
  services.sonarr = {
    enable = true;
    openFirewall = true;
  };
  users.users.sonarr = {
    extraGroups = ["users"];
  };
  services.radarr = {
    enable = true;
    openFirewall = true;
  };
  users.users.radarr = {
    extraGroups = ["users"];
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  services.caddy = {
    enable = true;
    virtualHosts."photos.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:2283
      '';
    };
    virtualHosts."ops.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:19999
        basicauth {
          benjajaja $2a$14$4pZrY1ZOqTSVnAgtLfatYuTKoHCD7lXukoFNeC0ZFH833lNrM/W7S
        }
      '';
    };
    virtualHosts."glances.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:61208
        basicauth {
          benjajaja $2a$14$4pZrY1ZOqTSVnAgtLfatYuTKoHCD7lXukoFNeC0ZFH833lNrM/W7S
        }
      '';
    };
    virtualHosts."kuma.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:3001
        basicauth {
          benjajaja $2a$14$4pZrY1ZOqTSVnAgtLfatYuTKoHCD7lXukoFNeC0ZFH833lNrM/W7S
        }
      '';
    };
    virtualHosts."home.qdice.wtf" = {
      extraConfig = ''
        reverse_proxy localhost:8082
        basicauth {
          benjajaja $2a$14$4pZrY1ZOqTSVnAgtLfatYuTKoHCD7lXukoFNeC0ZFH833lNrM/W7S
        }
      '';
    };
    virtualHosts."lz.qdice.wtf" = {
      extraConfig = ''
        root * /srv/www
        file_server
      '';
    };
  };

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
    enable = false;
    extras = [
      "oidc"
      "systemd"
      "url-preview"
      "user-search"
    ];
    extraConfigFiles = ["/run/matrix-config/homeserver.yaml"];
    settings = {
      database = {
        name = "sqlite3";
        args.database = "/var/lib/matrix-synapse/homeserver.db";
      };
    };
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

  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    allowedHosts = "homepage.qdice.wtf,ops:8082";
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
      { resources = { label = "/"; disk = [ "/" ]; }; }
      { resources = { label = "/mnt/backup"; disk = [ "/mnt/backup" ]; }; }
    ];
    services = [
      {
        "System" = [
          {
            "CPU" = {
              icon = "glances";
              href = "https://glances.${domain}";
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
              href = "https://kuma.${domain}";
              description = "Uptime monitor";
              widget = {
                type = "uptimekuma";
                url = "http://localhost:19999";
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
                key = "TODO";
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
              };
            };
          }
        ];
      }
    ];
  };

  system.stateVersion = "23.11";
}
