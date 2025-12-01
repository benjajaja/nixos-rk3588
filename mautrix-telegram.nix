{
  # Homeserver details
  homeserver = {
    # The address that this appservice can use to connect to the homeserver.
    address = "http://localhost:8008";
    # The domain of the homeserver (for MXIDs, etc).
    domain = "qdice.wtf";
    # What software is the homeserver running?
    # Standard Matrix homeservers like Synapse, Dendrite and Conduit should just use "standard" here.
    software = "standard";
  };

  # Application service host/registration related details
  # Changing these values requires regeneration of the registration.
  appservice = {
    address = "http://localhost:29317";
    hostname = "0.0.0.0";
    port = 29317;
    database = "sqlite:/var/lib/mautrix-telegram/mautrix-telegram.db";
    database_opts = {
      min_size = 1;
      max_size = 10;
    };
    # The unique ID of this appservice.
    id = "telegrambot";
    # Username of the appservice bot.
    bot_username = "telegrambot";
    # Display name and avatar for bot. Set to "remove" to remove display name/avatar, leave empty
    # to leave display name/avatar as-is.
    bot_displayname = "Telegram Bridge Bot";
    bot_avatar = "mxc://maunium.net/tJCRmUyJDsgRNgqhOgoiHWbX";

    # Whether or not to receive ephemeral events via appservice transactions.
    # Requires MSC2409 support (i.e. Synapse 1.22+).
    # You should disable bridge -> sync_with_custom_puppets when this is enabled.
    ephemeral_events = true;
    "org.matrix.msc3202" = true;
  };

  bridge = {
    sync_with_custom_puppets = false;
    sync_read_receipts = true;
    sync_direct_chat_list = true;
    delivery_receipts = true;
    login_shared_secret_map = {
      "qdice.wtf" = "$MAUTRIX_TELEGRAM_BRIDGE_LOGIN_SHARED_SECRET_MAP_QDICE";
    };
    double_puppet_allow_discovery = true;
    encryption = {
      allow = true;
      default = true;
      require = false;
      pickle_key = "$MAUTRIX_TELEGRAM_ENCRYPTION_PICKLE_KEY";
      msc4190 = true;
      verification_levels = {
        receive = "unverified";
        send = "unverified";
        share = "cross-signed-tofu";
      };
      allow_key_sharing = true;
    };

    # puppet_power_level = 50;

    username_template = "t_{userid}";
    alias_template = "t_{groupname}";
    displayname_template = "{displayname} (tg)";
    displayname_preference = [
      "full name"
      "username"
      "phone number"
    ];
    backfill = {
      enable = false;
      # Use MSC2716 for backfilling?
      #
      # This requires a server with MSC2716 support, which is currently an experimental feature in Synapse.
      # It can be enabled by setting experimental_features -> msc2716_enabled to true in homeserver.yaml.
      msc2716 = false;
      # Use double puppets for backfilling?
      #
      # If using MSC2716, the double puppets must be in the appservice's user ID namespace
      # (because the bridge can't use the double puppet access token with batch sending).
      #
      # Even without MSC2716, bridging old messages with correct timestamps requires the double
      # puppets to be in an appservice namespace, or the server to be modified to allow
      # overriding timestamps anyway.
      #
      # Also note that adding users to the appservice namespace may have unexpected side effects,
      # as described in https://docs.mau.fi/bridges/general/double-puppeting.html#appservice-method
      double_puppet_backfill = false;
      # Whether or not to enable backfilling in normal groups.
      # Normal groups have numerous technical problems in Telegram, and backfilling normal groups
      # will likely cause problems if there are multiple Matrix users in the group.
      normal_groups = false;
      # If a backfilled chat is older than this number of hours, mark it as read even if it's unread on Telegram.
      # Set to -1 to let any chat be unread.
      unread_hours_threshold = 720;
    };

    # Permissions for using the bridge.
    # Permitted values:
    #   relaybot - Only use the bridge via the relaybot, no access to commands.
    #       user - Relaybot level + access to commands to create bridges.
    #  puppeting - User level + logging in with a Telegram account.
    #       full - Full access to use the bridge, i.e. previous levels + Matrix login.
    #      admin - Full access to use the bridge and some extra administration commands.
    # Permitted keys:
    #        * - All Matrix users
    #   domain - All users on that homeserver
    #     mxid - Specific user
    permissions = {
      "*" = "relaybot";
      "qdice.wtf" = "full";
      "@telegrambot:qdice.wtf" = "admin";
    };
  };

  matrix = {
    federate_rooms = false;
  };

  telegram = {
    api_id = "$MAUTRIX_TELEGRAM_TELEGRAM_API_ID";
    api_hash = "$MAUTRIX_TELEGRAM_TELEGRAM_API_HASH";
    bot_token = "disabled";
    catch_up = true;
    sequential_updates = true;
    exit_on_update_error = false;
  };
  logging = {
    version = 1;
    formatters = {
      normal = {
        format = "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s";
      };
    };
    handlers = {
      console = {
        class = "logging.StreamHandler";
        formatter = "normal";
      };
    };
    loggers = {
      mau = {
        level = "DEBUG";
      };
      telethon = {
        level = "DEBUG";
      };
    };
    root = {
      level = "DEBUG";
      handlers = ["console"];
    };
  };
}
