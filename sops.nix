{
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  defaultSopsFile = ./secrets/secrets.yaml;
  secrets = {
    gipsy_hashed_password = {
      mode = "0400";
      neededForUsers = true;
    };
    postfix_sasl_passwords = {
      mode = "0400";
      owner = "postfix";
      group = "postfix";
    };
    mosquitto-password = {
      owner = "mosquitto";
      group = "mosquitto";
    };
    meshstellar-env = {
      sopsFile = ./secrets/api_keys.yaml;
      owner = "meshstellar";
      group = "meshstellar";
      mode = "0400";
      restartUnits = [ "meshstellar.service" ];
    };
    ddns-updater = {
      mode = "0400";
    };
    porkbun_secret = {
      mode = "0400";
    };
    radarr_env = {
      sopsFile = ./secrets/api_keys.yaml;
      owner = "radarr";
      group = "radarr";
      mode = "0400";
      restartUnits = [ "radarr.service" "home-assistant.service" ];
    };
    sonarr_env = {
      sopsFile = ./secrets/api_keys.yaml;
      owner = "sonarr";
      group = "sonarr";
      mode = "0400";
      restartUnits = [ "sonarr.service" "home-assistant.service" ];
    };
    prowlarr_env = {
      sopsFile = ./secrets/api_keys.yaml;
      owner = "nobody";
      group = "users";
      mode = "0400";
      restartUnits = [ "prowlarr.service" "home-assistant.service" ];
    };
    # potato-mesh = {
      # sopsFile = ./secrets/api_keys.yaml;
      # owner = "potato-mesh";
      # group = "potato-mesh";
      # mode = "0400";
    # };
    mealie = {
      sopsFile = ./secrets/api_keys.yaml;
      owner = "mealie";
      group = "mealie";
      mode = "0400";
    };
    homeserver_secrets_yaml = {
      sopsFile = ./secrets/matrix.yaml;
      path = "/var/lib/matrix-synapse/secrets/homeserver_secrets.yaml";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    qdice_wtf_signing_key = {
      sopsFile = ./secrets/matrix.yaml;
      path = "/var/lib/matrix-synapse/secrets/qdice.wtf.signing.key";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    doublepuppet_yaml = {
      sopsFile = ./secrets/matrix.yaml;
      path = "/var/lib/matrix-synapse/secrets/doublepuppet.yaml";
      mode = "0400";
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    mautrix_telegram_env = {
      sopsFile = ./secrets/matrix.yaml;
      path = "/var/lib/matrix-synapse/secrets/mautrix-telegram.env";
      mode = "0400";
      owner = "mautrix-telegram";
      group = "mautrix-telegram";
    };
    mautrix_whatsapp_env = {
      sopsFile = ./secrets/matrix.yaml;
      path = "/var/lib/matrix-synapse/secrets/mautrix-whatsapp.env";
      mode = "0400";
      owner = "mautrix-whatsapp";
      group = "mautrix-whatsapp";
    };
    postgresql_synapse_password = {
      sopsFile = ./secrets/matrix.yaml;
      owner = "postgres";
      group = "postgres";
    };
  };
}
