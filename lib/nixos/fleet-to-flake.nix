{lib}: let
  roleModuleNames = {
    base = "base";
    k3s-bootstrap = "roleK3sBootstrap";
    k3s-server = "roleK3sServer";
    k3s-control-plane = "roleK3sServer";
    k3s-agent = "roleK3sAgent";
    k3s-worker = "roleK3sAgent";
    longhorn-node = "roleLonghornNode";
    storage-longhorn = "roleLonghornNode";
    gpu-utility = "roleGpuUtility";
    accelerator-gpu = "roleGpuUtility";
    gpu-amd = "roleGpuAmd";
    amd-gpu = "roleGpuAmd";
    gpu-nvidia = "roleGpuNvidia";
    nvidia-gpu = "roleGpuNvidia";
    node-label-applier = "roleNodeLabelApplier";
    service-tailscale = "serviceTailscale";
    media-storage = "serviceMediaStorage";
    samba = "serviceSamba";
    ollama-rocm = "serviceOllamaRocm";
    btrfs-backup-snapshots = "serviceBtrfsBackupSnapshots";
    raspberry-pi-aarch64 = "hardwareRaspberryPiAarch64";
    raspberry-pi-sd-image = "imageRaspberryPiSdImage";
    tailscale-subnet-router = "roleTailscaleSubnetRouter";
    tailscale-network = "roleTailscaleSubnetRouter";
  };

  moduleNameForRole = role:
    roleModuleNames.${role} or (throw "Unknown nixos-modules fleet role: ${role}");
in rec {
  inherit moduleNameForRole roleModuleNames;

  modulesForNode = platformModules: node:
    map (role: platformModules.${moduleNameForRole role}) (node.roles or []);

  mkHostModule = platformModules: node: {
    imports = modulesForNode platformModules node;
    networking.hostName = lib.mkDefault node.id;
    nixpkgs.hostPlatform = lib.mkDefault node.system;
  };

  mkNixosConfigurations = {
    nixpkgs,
    platformModules,
    fleet,
    extraModules ? [],
    specialArgs ? {},
  }:
    lib.genAttrs (map (node: node.id) fleet.nodes) (
      nodeId: let
        node = lib.findFirst (candidate: candidate.id == nodeId) null fleet.nodes;
      in
        nixpkgs.lib.nixosSystem {
          system = node.system;
          inherit specialArgs;
          modules =
            [
              (mkHostModule platformModules node)
            ]
            ++ extraModules;
        }
    );

  deployNodeMetadata = fleet:
    lib.genAttrs (map (node: node.id) fleet.nodes) (
      nodeId: let
        node = lib.findFirst (candidate: candidate.id == nodeId) null fleet.nodes;
      in {
        hostname = node.sshHost or node.id;
        user = node.sshUser or null;
        profiles = node.roles or [];
      }
    );
}
