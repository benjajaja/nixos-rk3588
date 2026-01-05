{
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  defaultSopsFile = ./secrets/api_keys.yaml;
  secrets = {
    radarr_env = {
      owner = "radarr";
      group = "radarr";
      mode = "0400";
      restartUnits = [ "radarr.service" "home-assistant.service" ];
    };
    sonarr_env = {
      owner = "sonarr";
      group = "sonarr";
      mode = "0400";
      restartUnits = [ "sonarr.service" "home-assistant.service" ];
    };
    prowlarr_env = {
      owner = "nobody";
      group = "users";
      mode = "0400";
      restartUnits = [ "prowlarr.service" "home-assistant.service" ];
    };
    postfix_sasl_passwords = {
      mode = "0400";
      owner = "postfix";
      group = "postfix";
    };

    # We write all these files to a fixed path for easier debugging, because
    # they sometimes depend on each other.
    homeserver_secrets_yaml = {
      path = "/var/lib/matrix-synapse/secrets/homeserver_secrets.yaml";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    qdice_wtf_signing_key = {
      path = "/var/lib/matrix-synapse/secrets/qdice.wtf.signing.key";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    doublepuppet_yaml = {
      path = "/var/lib/matrix-synapse/secrets/doublepuppet.yaml";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    mautrix_telegram_env = {
      path = "/var/lib/matrix-synapse/secrets/mautrix-telegram.env";
      mode = "0400";
      owner = "mautrix-telegram";
      group = "mautrix-telegram";
    };
    mautrix_whatsapp_env = {
      path = "/var/lib/matrix-synapse/secrets/mautrix-whatsapp.env";
      mode = "0400";
      owner = "mautrix-whatsapp";
      group = "mautrix-whatsapp";
    };
    postgresql_synapse_password = {
      owner = "postgres";
      group = "postgres";
    };
    mosquitto-password = {
      owner = "mosquitto";
      group = "mosquitto";
    };
    potato-mesh = {
      owner = "potato-mesh";
      group = "potato-mesh";
      mode = "0400";
    };
    mealie = {
      owner = "mealie";
      group = "mealie";
      mode = "0400";
    };
    ddns-updater = {
      mode = "0400";
    };
    porkbun_secret = {
      mode = "0400";
    };
  };
}

