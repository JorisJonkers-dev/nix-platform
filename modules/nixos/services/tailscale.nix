{ config, lib, ... }:
let
  cfg = config.platformBlueprints.services.tailscale;
in
{
  options.platformBlueprints.services.tailscale = {
    enable = lib.mkEnableOption "generic Tailscale host service";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional runtime path containing a Tailscale auth key.";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags passed to tailscale up.";
    };

    looseReversePathFiltering = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set firewall reverse-path checking to loose for routed tailnet traffic.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.tailscale = {
        enable = true;
        extraUpFlags = cfg.extraUpFlags;
      };
    }

    (lib.mkIf (cfg.authKeyFile != null) {
      services.tailscale.authKeyFile = cfg.authKeyFile;
    })

    (lib.mkIf cfg.looseReversePathFiltering {
      networking.firewall.checkReversePath = "loose";
    })
  ]);
}
