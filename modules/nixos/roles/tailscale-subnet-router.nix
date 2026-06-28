{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.tailscaleSubnetRouter;
  advertiseRoutesFlag =
    lib.optional (cfg.advertiseRoutes != [ ])
      "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}";
in
{
  options.platformBlueprints.roles.tailscaleSubnetRouter = {
    enable = lib.mkEnableOption "generic Tailscale subnet router role";

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

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "CIDR routes advertised by this Tailscale subnet router.";
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = "Tailnet interface name used by dependent roles.";
    };

    trustInterface = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mark the tailnet interface as trusted in the firewall.";
    };

    useForK3sFlannel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set platformBlueprints.k3s.flannelInterface to the tailnet interface.";
    };

    waitForK3s = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Wait for the tailnet interface before k3s starts.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.tailscale = {
        enable = true;
        extraUpFlags = advertiseRoutesFlag ++ cfg.extraUpFlags;
      }
      // lib.optionalAttrs (cfg.authKeyFile != null) {
        authKeyFile = cfg.authKeyFile;
      };

      networking.firewall.checkReversePath = lib.mkDefault "loose";
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = lib.mkDefault 1;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
      };
    }

    (lib.mkIf cfg.trustInterface {
      networking.firewall.trustedInterfaces = [ cfg.interfaceName ];
    })

    (lib.mkIf cfg.useForK3sFlannel {
      platformBlueprints.k3s.flannelInterface = lib.mkDefault cfg.interfaceName;
    })

    (lib.mkIf cfg.waitForK3s {
      platformBlueprints.k3s.waitForInterface.name = lib.mkDefault cfg.interfaceName;
    })
  ]);
}
