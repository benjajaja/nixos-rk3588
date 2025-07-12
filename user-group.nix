let
  username = "gipsy";
  hostName = "ops";
  # To generate a hashed password run `mkpasswd -m scrypt`.
  # this is the hash of the password "rk3588"
  hashedPassword = "$y$j9T$V7M5HzQFBIdfNzVltUxFj/$THE5w.7V7rocWFm06Oh8eFkAKkUFb5u6HVZvXyjekK6";
  # TODO replace this with your own public key!
  publickey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6bBFgPLjUHf3r5SEGfQs+nLyDzlDUnGyRjwZ1zm2Sdhng+FnLfFjX/FMTx/96z+NAzvJolTEGF4QoxndgOELeYn1dqpFXV1VfYjMqZx1RG+0hoCCI5PwoWEcnzdZRYoYgeZkm+3K2V3ETiopDkKSEntWn33s+UguBvPALjjrFrCoL9n2/+wIZpRSZcjHUEqUVX9KPHKRgwW3hHGqq23r3Mvk/leSA/4fVJs9iPiYjk0NpyCtbvUDvkKTLT9PhRklkARsAstIB0+/YUjQL7PKGL3suo9WosH/MHz0cJMmcpRYURmo0h4HQraBeusRowYYbMMkWjEPyEddvs9WXMuqr1dYk/YJiABzeZTRjS7Y1JSPfFYhjfykUFiSd172VLpd55yXKM3eElyUW9S7rcwfP9H5XUux/o1w/qVSsDvU5uS411PL+yvXcDkkF9hxHrnPcPy1b3HnfToha2at5hOaE0ZND7LnDFmAzY8vsH3HKMBuVJ/UCJvMtKPOnGGzSLq3eYi8leXLV0FfasOSZpZyr2ZmfxVqIEhHLjnMeX1R/2PyzIjCwJryHmhFWCxwECdpyHvMU9OajrwjVnQpfLCIJ5oSNNbg3GOGu+5QTd+nB63gdRLdfvxr6Ee31WFEW3l/x1RZv5xQ3hfcQWJWEbF+mOkb13Sjy62NnBsQ2ibWZAw== ste3ls@gmail.com";
in {
  # =========================================================================
  #      Users & Groups NixOS Configuration
  # =========================================================================

  networking.hostName = hostName;

  # TODO Define a user account. Don't forget to update this!
  users.users."${username}" = {
    inherit hashedPassword;
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = ["users" "wheel" "docker"];
    openssh.authorizedKeys.keys = [
      publickey
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    publickey
  ];

  users.groups = {
    "${username}" = {};
    docker = {};
  };

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD: ALL
  '';
}
