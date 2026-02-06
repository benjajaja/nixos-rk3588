{ config, lib }: {
  server_name = "qdice.wtf";
  
  listeners = [
    {
      port = 8008;
      tls = false;
      type = "http";
      x_forwarded = true;
      resources = [
        {
          names = [ "client" "federation" ];
          compress = false;
        }
      ];
      bind_addresses = [ "127.0.0.1" ];
    }
  ];

  database = {
    # name = "sqlite3";
    # args.database = "/var/lib/matrix-synapse/homeserver.db";
    name = "psycopg2";
    args = {
      user = "synapse";
      # password = "???"; # This will be replaced by extraConfigFiles
      database = "synapse";
      host = "localhost";
      port = 5432;
      cp_min = 5;
      cp_max = 10;
    };
  };

  signing_key_path = config.sops.secrets.qdice_wtf_signing_key.path;
  app_service_config_files = [ config.sops.secrets.doublepuppet_yaml.path ];
  
  report_stats = false;
  
  trusted_key_servers = [
    { server_name = "matrix.org"; }
  ];
  suppress_key_server_warning = true; # yea yea trust matrix.org.
  
  enable_registration_captcha = true;
  enable_registration = true;
  default_identity_server = "https://matrix.org";
  
  password_config = {
    enabled = true;
    policy = {
      enabled = true;
      minimum_length = 1;
      require_digit = false;
      require_symbol = false;
      require_lowercase = false;
      require_uppercase = false;
    };
  };
  
  enable_3pid_lookup = false;
  
  email = {
    app_name = "matrix";
    notif_from = "noreply@qdice.wtf";
    enable_notifs = true;
    smtp_host = "127.0.0.1";
    smtp_port = 25;
    force_tls = false;
    require_transport_security = false;
    notif_for_new_users = false;
    client_base_url = "https://qdice.wtf";
  };
  
  url_preview_enabled = true;
  url_preview_ip_range_blacklist = [
    "127.0.0.0/8"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "169.254.0.0/16"
    "::1/128"
    "fe80::/10"
    "fc00::/7"
  ];
  
  media_retention = {
    local_media_lifetime = "30d";
    remote_media_lifetime = "14d";
  };
  
  track_appservice_user_ips = true;
  
  experimental_features = {
    msc2409_to_device_messages_enabled = true;
    msc3202_device_masquerading = true;
    msc3202_transaction_extensions = true;
    msc3391_phantom_receipt_enabled = true;
  };

  allow_application_service_read_markers = true;
  enable_admin_api = true;
}
