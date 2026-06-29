{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.longhornNode;
  labelLib = import ../../../lib/nixos/node-contract-labels.nix { inherit lib; };
in
{
  imports = [ ../k3s.nix ];

  options.platformBlueprints.roles.longhornNode = {
    enable = lib.mkEnableOption "generic Longhorn-ready Kubernetes node role";

    enableOpenIscsi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Open-iSCSI service required by Longhorn volumes.";
    };

    enableNfsClient = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install NFS client utilities for Longhorn backup and restore operations.";
    };

    installUtilities = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install storage inspection utilities useful on Longhorn-capable nodes.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        cryptsetup
        e2fsprogs
        util-linux
      ];
      description = "Additional storage utilities installed when installUtilities is true.";
    };

    nodeLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = labelLib.mkCapabilityLabels [ "storage-longhorn" ];
      description = "Kubernetes node labels added through the shared k3s module.";
    };

    nodeTaints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional Kubernetes taints added through the shared k3s module.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.kernelModules = [ "iscsi_tcp" ];

      platformBlueprints.k3s = {
        nodeLabels = cfg.nodeLabels;
        nodeTaints = cfg.nodeTaints;
      };
    }

    (lib.mkIf cfg.enableOpenIscsi {
      services.openiscsi.enable = true;
    })

    (lib.mkIf cfg.enableNfsClient {
      environment.systemPackages = [ pkgs.nfs-utils ];
    })

    (lib.mkIf cfg.installUtilities {
      environment.systemPackages = cfg.packages;
    })
  ]);
}
