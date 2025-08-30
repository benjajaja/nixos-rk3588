{ config, pkgs, lib, ... }:

let
  myConverter = pkgs.writeText "my-converter.js" ''
    const {deviceEndpoints, onOff} = require('zigbee-herdsman-converters/lib/modernExtend');

    const definition = {
        zigbeeModel: ['zbremote-esphome'],
        model: 'zbremote-esphome',
        vendor: 'esphome',
        description: 'Automatically generated definition',
        extend: [deviceEndpoints({"endpoints":{"1":1,"2":2,"3":3}}), onOff({"powerOnBehavior":false,"endpointNames":["1","2","3"]})],
        meta: {"multiEndpoint":true},
    };

    module.exports = definition;
  '';
in
{
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;  # Enable HA integration
      permit_join = false; # Enable timed join via UI
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
        log_level = "info";
        channel = 15; # router uses 11 and 44, AP uses 1
      };
      # external_converters = [
        # "${myConverter}"
      # ];
      devices = {
        "0xfc4d6afffe4e5dab" = {
          friendly_name = "Switch Bedroom Benja";
        };
        "0x6cfd22fffe6c058b" = {
          friendly_name = "LED Strip Benja";
        };
        "0xfc4d6afffecbfa28" = {
          friendly_name = "Switch Bedroom Laia";
        };
        "0xfc4d6afffecbf7f3" = {
          friendly_name = "Switch Bedroom Laia Fan";
        };
        "0xfc4d6afffecde292" = {
          friendly_name = "Zigbee USB Plug";
        };
        "0x98a316fffe856a20" = {
          friendly_name = "Zigbee RF Remote";
        };
        "0x98a316fffe8581a8" = {
          friendly_name = "Laser Particle Measurement";
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
}
