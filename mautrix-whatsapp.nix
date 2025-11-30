{
  homeserver = {
    address = "http://localhost:8008";
    domain = "qdice.wtf";
    software = "standard";
  };

  appservice = {
    address = "http://localhost:29318";
    hostname = "0.0.0.0";
    port = 29318;
    id = "whatsapp";
    bot = {
      username = "whatsappbot";
      displayname = "WhatsApp bridge bot";
      avatar = "mxc://maunium.net/NeXNQarUbrlYBiPCpprYsRqr";
    };
    ephemeral_events = true;
  };

  database = {
    type = "sqlite3-fk-wal";
    uri = "file:/var/lib/mautrix-whatsapp/mautrix-whatsapp.db?_txlock=immediate";
  };

  bridge = {
    command_prefix = "!wa";
    permissions = {
      "*" = "relay";
      "qdice.wtf" = "user";
      "@whatsappbot:qdice.wtf" = "admin";
    };
    relay = {
      enabled = false;
    };
  };

  encryption = {
    allow = true;
    default = false;
    require = false;
    pickle_key = "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
  };

  network = {
    displayname_template = "{{if .BusinessName}}{{.BusinessName}}{{else if .PushName}}{{.PushName}}{{else if .FullName}}{{.FullName}}{{else}}{{.Phone}}{{end}} (WA)";
    history_sync = {
      backfill = false;
    };
    call_start_notices = true;
    identity_change_notices = true;
  };

  double_puppet = {
    secrets = {
      "qdice.wtf" = "$MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET_MAP_QDICE";
    };
  };

  matrix = {
    federate_rooms = false;
  };

  logging = {
    min_level = "info";
    writers = [
      {
        type = "stdout";
        format = "pretty-colored";
      }
    ];
  };
}
