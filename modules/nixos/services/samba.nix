{
  config,
  lib,
  ...
}: let
  cfg = config.platformBlueprints.services.samba;

  mkUser = description: {
    isSystemUser = true;
    group = cfg.group;
    description = description;
  };
in {
  options.platformBlueprints.services.samba = {
    enable = lib.mkEnableOption "generic Samba service with caller-owned shares";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Samba firewall ports.";
    };

    workgroup = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "Samba workgroup.";
    };

    serverString = lib.mkOption {
      type = lib.types.str;
      default = "nix-platform-samba";
      description = "Samba server string.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "samba-share";
      description = "System group assigned to managed Samba users.";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        media-root = "All-access media share identity";
      };
      description = "System Samba users to create, mapped to their descriptions.";
    };

    shares = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {};
      example = {
        media = {
          path = "/srv/media";
          browseable = "yes";
          "read only" = "no";
        };
      };
      description = "Samba share settings merged under services.samba.settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = {};
    users.users = lib.mapAttrs (_: mkUser) cfg.users;

    services.samba = {
      enable = true;
      openFirewall = cfg.openFirewall;
      settings =
        {
          global = {
            workgroup = cfg.workgroup;
            "server string" = cfg.serverString;
            security = "user";
            "map to guest" = "Bad User";
            "server role" = "standalone server";
            "server min protocol" = "SMB2";
          };
        }
        // cfg.shares;
    };
  };
}
