{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.gpuUtility;
  labelLib = import ../../../lib/nixos/node-contract-labels.nix { inherit lib; };
in
{
  imports = [ ../k3s.nix ];

  options.platformBlueprints.roles.gpuUtility = {
    enable = lib.mkEnableOption "generic GPU utility node role";

    gpuVendors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "GPU vendor identifiers converted into node-contract labels.";
    };

    capabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "gpu" ];
      description = "Node capability labels exposed for GPU placement.";
    };

    nodeLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional Kubernetes node labels for GPU-aware scheduling.";
    };

    installUtilities = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install generic GPU and PCI inspection tools.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        clinfo
        pciutils
        usbutils
        vulkan-tools
      ];
      description = "GPU utility packages installed when installUtilities is true.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      platformBlueprints.k3s.nodeLabels =
        labelLib.mkCapabilityLabels cfg.capabilities
        // labelLib.mkGpuLabels cfg.gpuVendors
        // cfg.nodeLabels;
    }

    (lib.mkIf cfg.installUtilities {
      environment.systemPackages = cfg.packages;
    })
  ]);
}
