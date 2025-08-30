{
  network = {
    # Displayname template for WhatsApp users.
    # {{.PushName}}     - nickname set by the WhatsApp user
    # {{.BusinessName}} - validated WhatsApp business name
    # {{.Phone}}        - phone number (international format)
    # {{.FullName}}     - Name you set in the contacts list
    # displayname_template: "{{if .BusinessName}}{{.BusinessName}}{{else if .PushName}}{{.PushName}}{{else}}{{.JID}}{{end}} (WA)"
    displayname_template = "{{if .BusinessName}}{{.BusinessName}}{{else if .PushName}}{{.PushName}}{{else if .FullName}}{{.FullName}}{{else}}{{.JID}}{{end}} (WA)";
  };

  homeserver = {
    address = "http://localhost:8008";
    domain = "qdice.wtf";

    # What software is the homeserver running?
    # Standard Matrix homeservers like Synapse, Dendrite and Conduit should just use "standard" here.
    software = "standard";
  };

  appservice = {
    address = "http://localhost:29318";
    hostname = "0.0.0.0";
    port = 29318;

    database = {
      type = "sqlite3-fk-wal";
      uri = "file:/var/lib/mautrix-whatsapp/mautrix-whatsapp.db?_txlock=immediate";
    };

    id = "whatsapp";
    bot = {
      username = "whatsappbot";
      displayname = "WhatsApp bridge bot";
      avatar = "mxc://maunium.net/NeXNQarUbrlYBiPCpprYsRqr";
    };
    # Whether or not to receive ephemeral events via appservice transactions.
    # Requires MSC2409 support (i.e. Synapse 1.22+).
    # You should disable bridge -> sync_with_custom_puppets when this is enabled.
    ephemeral_events = true;
  };

  # Bridge config
  bridge = {
    personal_filtering_spaces = false;
    sync_with_custom_puppets = false;
    sync_read_receipts = true;
    delivery_receipts = true;
    message_status_events = false;
    # Whether the bridge should send error notices via m.notice events when a message fails to bridge.
    message_error_notices = true;
    # Should incoming calls send a message to the Matrix room?
    call_start_notices = true;
    encryption = {
      allow = true;
      default = false;
      require = false;
    };
    history_sync = {
      # Enable backfilling history sync payloads from WhatsApp?
      backfill = false;
    };
    login_shared_secret_map = {
      "qdice.wtf" = "$MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET_MAP_QDICE";
    };

    # Permissions for using the bridge.
    # Permitted values:
    #    relay - Talk through the relaybot (if enabled), no access otherwise
    #     user - Access to use the bridge to chat with a WhatsApp account.
    #    admin - User level and some additional administration tools
    # Permitted keys:
    #        * - All Matrix users
    #   domain - All users on that homeserver
    #     mxid - Specific user
    permissions = {
      "*" = "relay";
      "qdice.wtf" = "user";
      "@whatsappbot:qdice.wtf" = "admin";
    };
    enable_status_broadcast = false;
    relay.enabled = false;
  };

  matrix = {
    federate_rooms = false;
  };
}
