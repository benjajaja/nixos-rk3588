{
  description = "Orange Pi Fan Control with wiringOP - Multi-Fan Support";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        # wiringOP package definition
        wiringOP = let
          version = "unstable-2023-11-16";
          srcAll = pkgs.fetchFromGitHub {
            owner = "orangepi-xunlong";
            repo = "wiringOP";
            rev = "8cb35ff967291aca24f22af151aaa975246cf861";
            sha256 = "sha256-W6lZh4nEhhpkdcu/PWbVmjcvfhu6eqRGlkj8jiphG+k=";
          };
          mkSubProject = {
            subprj, # The only mandatory argument
            buildInputs ? [],
            src ? srcAll,
          }:
            pkgs.stdenv.mkDerivation (finalAttrs: {
              pname = "wiringop-${subprj}";
              inherit version src;
              sourceRoot = "${src.name}/${subprj}";
              inherit buildInputs;
              # Remove (meant for other OSs) lines from Makefiles
              preInstall = ''
                mkdir -p $out/bin
                sed -i "/chown root/d" Makefile
                sed -i "/chmod/d" Makefile
                sed -i "/ldconfig/d" Makefile
              '';
              makeFlags = [
                "DESTDIR=${placeholder "out"}"
                "PREFIX=/."
                # On NixOS we don't need to run ldconfig during build:
                "LDCONFIG=echo"
              ];
            });
          passthru = {
            # Helps nix-update and probably nixpkgs-update find the src of this package
            # automatically.
            src = srcAll;
            inherit mkSubProject;
            wiringPi = mkSubProject {
              subprj = "wiringPi";
              buildInputs = [pkgs.libxcrypt];
            };
            devLib = mkSubProject {
              subprj = "devLib";
              buildInputs = [passthru.wiringPi];
            };
            gpio = mkSubProject {
              subprj = "gpio";
              buildInputs = [
                pkgs.libxcrypt
                passthru.wiringPi
                passthru.devLib
              ];
            };
          };
        in
          pkgs.symlinkJoin {
            name = "wiringop-${version}";
            inherit passthru;
            paths = [
              passthru.wiringPi
              passthru.devLib
              passthru.gpio
            ];
            meta = with pkgs.lib; {
              description = "GPIO access library for Orange Pi (wiringPi port)";
              homepage = "https://github.com/orangepi-xunlong/wiringOP";
              license = licenses.lgpl3Plus;
              maintainers = [];
              platforms = platforms.linux;
            };
          };

        # opifancontrol package definition
        opifancontrol = pkgs.stdenv.mkDerivation rec {
          pname = "opifancontrol";
          version = "1.0.2";

          src = pkgs.writeTextFile {
            name = "opifancontrol-script";
            text = ''
              #!/bin/bash
              OPIFANCONTROL_VERSION="1.0.2"

              # Default values
              TEMP_LOW=55
              FAN_LOW=50
              TEMP_MED=65
              FAN_MED=75
              TEMP_HIGH=70
              FAN_HIGH=100
              TEMP_POLL_SECONDS=2

              RAMP_UP_DELAY_SECONDS=15
              RAMP_DOWN_DELAY_SECONDS=60

              FAN_GPIO_PIN=6
              PWM_RANGE=192
              PWM_CLOCK=4

              #CONFIG_FILE="/etc/opifancontrol.conf"
              if [ -n "$1" ]; then
                  CONFIG_FILE="$1"
              else
                  CONFIG_FILE="/etc/opifancontrol.conf"
              fi

              # Detect if gpio command is available
              if ! command -v gpio > /dev/null; then
                  echo "Error: gpio command not found. Please install wiringPi."
                  echo "See: https://github.com/jamsinclair/opifancontrol?tab=readme-ov-file#software-installation"
                  exit 1
              fi

              if [ -r "$CONFIG_FILE" ]; then
                  source "$CONFIG_FILE"
              else
                  echo "Warning: Configuration file not found at /etc/opifancontrol.conf. Using default values."
              fi

              CURRENT_PWM=0
              LAST_RAMPED_DOWN_TS=0

              # Initialize GPIO pin for PWM
              gpio mode $FAN_GPIO_PIN pwm
              gpio pwm $FAN_GPIO_PIN 0
              gpio pwmr $FAN_GPIO_PIN $PWM_RANGE
              gpio pwmc $FAN_GPIO_PIN $PWM_CLOCK
              # Need to set to 0 again after setting the clock and range
              gpio pwm $FAN_GPIO_PIN 0

              debug () {
                  if [ "$DEBUG" = true ]; then
                      echo "$1"
                  fi
              }

              echo "Starting opifancontrol (v$OPIFANCONTROL_VERSION) ..."
              echo "PWM range: $PWM_RANGE"
              echo "PWM clock: $PWM_CLOCK"
              echo "Fan GPIO pin: $FAN_GPIO_PIN"
              echo "Temperature poll interval: $TEMP_POLL_SECONDS seconds"
              echo "Temperature thresholds (C): $TEMP_LOW, $TEMP_MED, $TEMP_HIGH"
              echo "Fan speed thresholds (%): $FAN_LOW, $FAN_MED, $FAN_HIGH"
              echo "Ramp up delay: $RAMP_UP_DELAY_SECONDS seconds"
              echo "Ramp down delay: $RAMP_DOWN_DELAY_SECONDS seconds"
              if [ "$DEBUG" = true ]; then
                  echo "Debugging enabled"
              else
                  echo "Debugging is disabled. To log fan speed changes, set DEBUG=true in /etc/opifancontrol.conf"
              fi

              percent_to_pwm() {
                  local percent=$1
                  if [ $percent -gt 100 ]; then
                      percent=100
                  fi
                  local pwm=$((percent * PWM_RANGE / 100))
                  printf "%.0f" $pwm
              }

              cleanup() {
                  echo "Exiting opifancontrol and setting fan pin to 0 PWM"
                  gpio pwm $FAN_GPIO_PIN 0
                  exit 0
              }

              # Set trap to call cleanup function on script exit
              trap cleanup EXIT

              smooth_ramp() {
                  local current_pwm=$1
                  local target_pwm=$2
                  local ramp_step=$3
                  local ramp_delay=$4

                  while [ $current_pwm -ne $target_pwm ]; do
                      if [ $target_pwm -eq 0 ]; then
                          current_pwm=0
                      elif [ $current_pwm -eq 0 ]; then
                          current_pwm=$target_pwm
                      elif [ $current_pwm -lt $target_pwm ]; then
                          current_pwm=$((current_pwm + ramp_step))
                          if [ $current_pwm -gt $target_pwm ]; then
                              current_pwm=$target_pwm
                          fi
                      else
                          current_pwm=$((current_pwm - ramp_step))
                          if [ $current_pwm -lt $target_pwm ]; then
                              current_pwm=$target_pwm
                          fi
                      fi

                      gpio pwm $FAN_GPIO_PIN $current_pwm

                      sleep $ramp_delay
                  done

                  CURRENT_PWM=$target_pwm
              }

              while true; do
                  CPU_TEMP=$(cat /sys/class/thermal/thermal_zone1/temp)
                  CPU_TEMP=$((CPU_TEMP / 1000))

                  if [ $CPU_TEMP -lt $TEMP_LOW ]; then
                      TARGET_PWM=0
                  elif [ $CPU_TEMP -lt $TEMP_MED ]; then
                      TARGET_PWM=$(percent_to_pwm $FAN_LOW)
                  elif [ $CPU_TEMP -lt $TEMP_HIGH ]; then
                      TARGET_PWM=$(percent_to_pwm $FAN_MED)
                  else
                      TARGET_PWM=$(percent_to_pwm $FAN_HIGH)
                  fi

                  if [ $TARGET_PWM -ne $CURRENT_PWM ]; then
                      BASE_RAMP_UP_DELAY_TS=$(date +%s)
                      # If the fan is currently off, wait for the ramp up delay before turning it on to avoid rapid on/off cycles
                      if [ $TARGET_PWM -gt $CURRENT_PWM ] && [ $((LAST_RAMPED_DOWN_TS + $RAMP_UP_DELAY_SECONDS)) -gt $BASE_RAMP_UP_DELAY_TS ]; then
                          RAMP_UP_DELAY_REMAIN_SECONDS=$(($RAMP_UP_DELAY_SECONDS - $BASE_RAMP_UP_DELAY_TS + $LAST_RAMPED_DOWN_TS))
                          debug "Delay of $RAMP_UP_DELAY_REMAIN_SECONDS sec before turning on the fan ... Target PWM: $TARGET_PWM"
                          sleep $RAMP_UP_DELAY_REMAIN_SECONDS
                      fi

                      if [ $TARGET_PWM -eq 0 ] && [ $CURRENT_PWM -ne 0 ]; then
                          # Wait for the ramp down delay before turning off the fan to avoid rapid on/off cycles
                          debug "Delay of $RAMP_DOWN_DELAY_SECONDS sec before turning off the fan ... Target PWM: $TARGET_PWM"
                          sleep $RAMP_DOWN_DELAY_SECONDS
                          debug "Turning off the fan"
                          LAST_RAMPED_DOWN_TS=$(date +%s)
                      fi

                      debug "Changing Fan Speed | CPU temp: $CPU_TEMP, target PWM: $TARGET_PWM, current PWM: $CURRENT_PWM"
                      smooth_ramp $CURRENT_PWM $TARGET_PWM 2 0.2
                  fi

                  sleep $TEMP_POLL_SECONDS
              done
            '';
            executable = true;
          };

          dontUnpack = true;
          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/opifancontrol
            chmod +x $out/bin/opifancontrol
          '';

          meta = with pkgs.lib; {
            description = "Fan control script for Orange Pi boards";
            homepage = "https://github.com/jamsinclair/opifancontrol";
            license = licenses.mit;
            maintainers = [];
            platforms = platforms.linux;
          };
        };
      in {
        packages = {
          inherit wiringOP opifancontrol;
          default = opifancontrol;
        };

        # For development
        devShells.default = pkgs.mkShell {
          buildInputs = [wiringOP opifancontrol];
        };
      }
    )
    // {
      # NixOS module
      nixosModules.default = {
        config,
        lib,
        pkgs,
        ...
      }: let
        cfg = config.services.opifancontrol;

        # Define the fan configuration type
        fanConfigType = lib.types.submodule {
          options = {
            fanGpioPin = lib.mkOption {
              type = lib.types.int;
              default = 6;
              description = "The GPIO pin to use for the fan (wPi pin number)";
            };

            tempLow = lib.mkOption {
              type = lib.types.int;
              default = 55;
              description = "Low temperature threshold in Celsius";
            };

            fanLow = lib.mkOption {
              type = lib.types.int;
              default = 50;
              description = "Fan speed percentage for low temperature";
            };

            tempMed = lib.mkOption {
              type = lib.types.int;
              default = 65;
              description = "Medium temperature threshold in Celsius";
            };

            fanMed = lib.mkOption {
              type = lib.types.int;
              default = 75;
              description = "Fan speed percentage for medium temperature";
            };

            tempHigh = lib.mkOption {
              type = lib.types.int;
              default = 70;
              description = "High temperature threshold in Celsius";
            };

            fanHigh = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Fan speed percentage for high temperature";
            };

            tempPollSeconds = lib.mkOption {
              type = lib.types.int;
              default = 2;
              description = "Temperature polling interval in seconds";
            };

            rampUpDelaySeconds = lib.mkOption {
              type = lib.types.int;
              default = 15;
              description = "Delay before turning fan on to avoid rapid on/off cycles";
            };

            rampDownDelaySeconds = lib.mkOption {
              type = lib.types.int;
              default = 60;
              description = "Delay before turning fan off to avoid rapid on/off cycles";
            };

            pwmRange = lib.mkOption {
              type = lib.types.int;
              default = 192;
              description = "PWM range for fan control";
            };

            pwmClock = lib.mkOption {
              type = lib.types.int;
              default = 4;
              description = "PWM clock for fan control";
            };

            debug = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable debug logging";
            };
          };
        };

        # Generate configuration file content for a specific fan
        mkConfigFile = fanName: fanConfig: pkgs.writeText "opifancontrol-${fanName}.conf" ''
          FAN_GPIO_PIN=${toString fanConfig.fanGpioPin}
          TEMP_LOW=${toString fanConfig.tempLow}
          FAN_LOW=${toString fanConfig.fanLow}
          TEMP_MED=${toString fanConfig.tempMed}
          FAN_MED=${toString fanConfig.fanMed}
          TEMP_HIGH=${toString fanConfig.tempHigh}
          FAN_HIGH=${toString fanConfig.fanHigh}
          TEMP_POLL_SECONDS=${toString fanConfig.tempPollSeconds}
          RAMP_UP_DELAY_SECONDS=${toString fanConfig.rampUpDelaySeconds}
          RAMP_DOWN_DELAY_SECONDS=${toString fanConfig.rampDownDelaySeconds}
          PWM_RANGE=${toString fanConfig.pwmRange}
          PWM_CLOCK=${toString fanConfig.pwmClock}
          DEBUG=${
            if fanConfig.debug
            then "true"
            else "false"
          }
        '';

        # Create systemd service for a specific fan
        mkFanService = fanName: fanConfig: 
          let
            configFile = mkConfigFile fanName fanConfig;
          in {
            "opifancontrol-${fanName}" = {
              description = "Orange Pi Fan Control Service - ${fanName}";
              wantedBy = ["multi-user.target"];
              after = ["multi-user.target"];

              serviceConfig = {
                Type = "simple";
                ExecStart = "${cfg.package}/bin/opifancontrol ${configFile}";
                Restart = "on-failure";
                User = "root"; # GPIO access typically requires root
                # Ensure the service can find system binaries
                Environment = "PATH=${pkgs.lib.makeBinPath [cfg.wiringOP pkgs.coreutils pkgs.bash]}";
              };

              # Only start if the thermal zone file exists (i.e., on Orange Pi)
              unitConfig = {
                ConditionPathExists = "/sys/class/thermal/thermal_zone1/temp";
              };

              # Restart service when configuration changes
              restartTriggers = [configFile];
            };
          };

        # Generate all fan services
        fanServices = lib.mkMerge (lib.mapAttrsToList mkFanService cfg.fans);
      in {
        options.services.opifancontrol = {
          enable = lib.mkEnableOption "Orange Pi Fan Control Service";

          package = lib.mkOption {
            type = lib.types.package;
            default = self.packages.${pkgs.system}.opifancontrol;
            description = "The opifancontrol package to use";
          };

          wiringOP = lib.mkOption {
            type = lib.types.package;
            default = self.packages.${pkgs.system}.wiringOP;
            description = "The wiringOP package to use";
          };

          fans = lib.mkOption {
            type = lib.types.attrsOf fanConfigType;
            default = {};
            description = "Configuration for each fan";
            example = lib.literalExpression ''
              {
                cpu = {
                  fanGpioPin = 6;
                  tempLow = 45;
                  fanLow = 30;
                  tempMed = 55;
                  fanMed = 60;
                  tempHigh = 65;
                  fanHigh = 100;
                  debug = true;
                };
                closet = {
                  fanGpioPin = 22;
                  tempLow = 45;
                  fanLow = 30;
                  tempMed = 55;
                  fanMed = 60;
                  tempHigh = 65;
                  fanHigh = 100;
                  debug = true;
                };
              }
            '';
          };

          boardType = lib.mkOption {
            type = lib.types.str;
            default = "orangepi5plus";
            description = "Orange Pi board type";
          };
        };

        config = lib.mkIf cfg.enable {
          # Set up the board identification file
          environment.etc."orangepi-release".text = "BOARD=${cfg.boardType}";

          # Define the systemd services for all fans
          systemd.services = fanServices;
        };
      };
    };
}
