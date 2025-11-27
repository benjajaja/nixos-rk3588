{
  description = "MeshMonitor - Web application for monitoring Meshtastic mesh networks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.buildNpmPackage rec {
            pname = "meshmonitor";
            version = "2.19.7";

            src = pkgs.fetchFromGitHub {
              owner = "Yeraze";
              repo = "meshmonitor";
              rev = "9ab45145b3438738eea35a71c6b3ad1019c81045";
              hash = "sha256-f0gFEFzDsfw2w9GdLM/oLBdb/Lay/J7brqsgWJDPz+E=";
              fetchSubmodules = true;
            };

            npmDepsHash = "sha256-A36v4MM2FyMXJCWoXbdR23VOM3LTlYKpH2YTw1z4vIw=";

            nodejs = pkgs.nodejs_22;

            nativeBuildInputs = with pkgs; [
              python3
              pkg-config
            ];

            buildInputs = with pkgs; [
              vips
            ];

            npmFlags = [ "--ignore-scripts" ];

            buildPhase = ''
              runHook preBuild
              npm rebuild better-sqlite3
              npm run build
              npm run build:server
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/meshmonitor
              cp -r dist $out/lib/meshmonitor/
              cp -r node_modules $out/lib/meshmonitor/
              cp -r protobufs $out/lib/meshmonitor/
              cp package.json $out/lib/meshmonitor/

              mkdir -p $out/bin
              cat > $out/bin/meshmonitor <<SCRIPT
#!/bin/sh
cd $out/lib/meshmonitor
exec ${pkgs.nodejs_22}/bin/node dist/server/server.js "\$@"
SCRIPT
              chmod +x $out/bin/meshmonitor
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Web application for monitoring Meshtastic mesh networks over IP";
              homepage = "https://github.com/Yeraze/meshmonitor";
              license = licenses.bsd3;
              platforms = platforms.linux;
            };
          };
        }
      );

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.meshmonitor;
          meshmonitorPkg = self.packages.${pkgs.system}.default;
        in {
          options.services.meshmonitor = {
            enable = lib.mkEnableOption "MeshMonitor service";

            port = lib.mkOption {
              type = lib.types.port;
              default = 3001;
              description = "Port to listen on";
            };

            meshtasticNodeIP = lib.mkOption {
              type = lib.types.str;
              description = "IP address of the Meshtastic node";
            };

            meshtasticTcpPort = lib.mkOption {
              type = lib.types.port;
              default = 4403;
              description = "TCP port of the Meshtastic node";
            };

            allowedOrigins = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of allowed CORS origins";
            };

            adminPassword = lib.mkOption {
              type = lib.types.str;
              default = "changeme";
              description = "Admin password (set on each service start)";
            };

            openFirewall = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Open firewall port";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.tmpfiles.rules = [
              "d /var/lib/meshmonitor 0755 meshmonitor meshmonitor -"
              "d /data 0755 meshmonitor meshmonitor -"
            ];

            users.users.meshmonitor = {
              isSystemUser = true;
              group = "meshmonitor";
              home = "/var/lib/meshmonitor";
            };
            users.groups.meshmonitor = {};

            systemd.services.meshmonitor = {
              description = "MeshMonitor - Meshtastic mesh network monitoring";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              environment = {
                NODE_ENV = "production";
                PORT = toString cfg.port;
                MESHTASTIC_NODE_IP = cfg.meshtasticNodeIP;
                MESHTASTIC_TCP_PORT = toString cfg.meshtasticTcpPort;
                ALLOWED_ORIGINS = lib.concatStringsSep "," cfg.allowedOrigins;
              };

              script = ''
                export SESSION_SECRET=$(cat /var/lib/meshmonitor/session_secret)
                exec ${meshmonitorPkg}/bin/meshmonitor
              '';

              serviceConfig = {
                Type = "simple";
                User = "meshmonitor";
                Group = "meshmonitor";
                WorkingDirectory = "/data";
                Restart = "always";
                RestartSec = "10s";

                ExecStartPre = let
                  generateSecret = pkgs.writeShellScript "meshmonitor-generate-secret" ''
                    SECRET_FILE="/var/lib/meshmonitor/session_secret"
                    if [ ! -f "$SECRET_FILE" ]; then
                      ${pkgs.openssl}/bin/openssl rand -hex 32 > "$SECRET_FILE"
                      chmod 600 "$SECRET_FILE"
                      chown meshmonitor:meshmonitor "$SECRET_FILE"
                    fi
                  '';
                  setAdminPassword = pkgs.writeShellScript "meshmonitor-set-admin-password" ''
                    DB_FILE="/data/meshmonitor.db"
                    if [ -f "$DB_FILE" ]; then
                      HASH=$(${pkgs.nodejs_22}/bin/node -e "
                        const bcrypt = require('${meshmonitorPkg}/lib/meshmonitor/node_modules/bcrypt');
                        console.log(bcrypt.hashSync('${cfg.adminPassword}', 10));
                      ")
                      ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" "UPDATE users SET password_hash='$HASH' WHERE username='admin';"
                    fi
                  '';
                in [
                  "+${generateSecret}"
                  "+${setAdminPassword}"
                ];

                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                ReadWritePaths = [ "/var/lib/meshmonitor" "/data" ];
              };
            };

            networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
          };
        };
    };
}
