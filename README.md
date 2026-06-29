# nix-platform

Reusable NixOS modules and helper library for JorisJonkers-dev platform hosts.

## What It Is

This repository is a shared Nix artifact. It does not contain live host inventory, Flux cluster state, secrets, deploy nodes, disk layouts, or site-specific device paths.

## Flake Usage

Pin the flake in a consumer repository:

```nix
{
  inputs.nix-platform.url = "github:JorisJonkers-dev/nix-platform/v0.1.0";
}
```

Import modules in consumer-owned host modules:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nix-platform.nixosModules.default
    inputs.nix-platform.nixosModules.roleK3sServer
    inputs.nix-platform.nixosModules.roleLonghornNode
    inputs.nix-platform.nixosModules.roleGpuAmd
    inputs.nix-platform.nixosModules.serviceTailscale
  ];

  platformBlueprints.base = {
    enable = true;
    ssh.ports = [ 22 ];
    timeZone = "UTC";
    defaultLocale = "en_US.UTF-8";
  };

  platformBlueprints.roles.k3sServer.enable = true;
}
```

Available module outputs:

- `nixosModules.base`
- `nixosModules.k3s`
- `nixosModules.default`
- `nixosModules.roleK3sBootstrap`
- `nixosModules.roleK3sServer`
- `nixosModules.roleK3sAgent`
- `nixosModules.roleTailscaleSubnetRouter`
- `nixosModules.roleLonghornNode`
- `nixosModules.roleGpuUtility`
- `nixosModules.roleGpuAmd`
- `nixosModules.roleGpuNvidia`
- `nixosModules.roleNodeLabelApplier`
- `nixosModules.roleControlPlane`
- `nixosModules.roleWorker`
- `nixosModules.roleNetworkTailscale`
- `nixosModules.roleStorageLonghorn`
- `nixosModules.roleAcceleratorGpu`
- `nixosModules.serviceTailscale`
- `nixosModules.serviceMediaStorage`
- `nixosModules.serviceSamba`
- `nixosModules.serviceOllamaRocm`
- `nixosModules.serviceBtrfsBackupSnapshots`
- `nixosModules.hardwareRaspberryPiAarch64`
- `nixosModules.imageRaspberryPiSdImage`

## Reusable Roles

The role modules expose scheduling and host mechanics without carrying host
inventory:

- `platformBlueprints.roles.k3sServer` and `k3sAgent` configure generic k3s
  server or agent behavior.
- `platformBlueprints.roles.longhornNode` installs generic Longhorn
  prerequisites and storage node labels.
- `platformBlueprints.roles.gpuAmd` enables AMD graphics, ROCm utilities, and
  AMD GPU node labels.
- `platformBlueprints.roles.gpuNvidia` enables NVIDIA graphics, the container
  toolkit, and NVIDIA GPU node labels.
- `platformBlueprints.roles.nodeLabelApplier` applies caller-owned labels and
  taints with `kubectl`.

Consumers own all sensitive inputs: node names, join tokens, device paths,
driver branch overrides, and any cluster-specific labels.

## Reusable Services

The service modules are parameterized building blocks:

```nix
{
  imports = [
    inputs.nix-platform.nixosModules.serviceMediaStorage
    inputs.nix-platform.nixosModules.serviceSamba
    inputs.nix-platform.nixosModules.serviceBtrfsBackupSnapshots
  ];

  platformBlueprints.services.mediaStorage = {
    enable = true;
    owner = "media";
    group = "media";
    directories = [ "Completed" "Films" "Series" ];
    mounts."/srv/media" = {
      device = "/dev/disk/by-label/EXAMPLE_MEDIA";
      fsType = "btrfs";
    };
    viewBinds."library/Films" = "/srv/media/Films";
  };

  platformBlueprints.services.samba = {
    enable = true;
    users.media-root = "All-access media share identity";
    shares.media = {
      path = "/srv/media";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "media-root";
    };
  };

  platformBlueprints.services.btrfsBackupSnapshots = {
    enable = true;
    sourceSubvolume = "/srv/media/Backup";
    sourceSnapshotDirectory = "/srv/media/.snapshots";
    destinationSnapshotDirectory = "/srv/backup/.snapshots/Backup";
  };
}
```

`serviceTailscale` enables the host Tailscale service and optional loose
reverse-path filtering. `serviceOllamaRocm` enables `pkgs.ollama-rocm` with
caller-owned listen address, model list, model directory, environment variables,
and firewall exposure.

## Fleet Helpers

`lib.nixosFleet` maps fleet roles to NixOS modules:

- `base`
- `k3s-bootstrap`
- `k3s-server`
- `k3s-agent`
- `longhorn-node`
- `gpu-utility`
- `gpu-amd`
- `gpu-nvidia`
- `node-label-applier`
- `service-tailscale`
- `media-storage`
- `samba`
- `ollama-rocm`
- `btrfs-backup-snapshots`
- `raspberry-pi-aarch64`
- `raspberry-pi-sd-image`
- `tailscale-subnet-router`

Compatibility aliases are retained for `k3s-control-plane`, `k3s-worker`, and `tailscale-network`.

## Node Contract Labels

`lib.nodeContractLabels` builds canonical Kubernetes node labels under `platform.jorisjonkers.dev/*` and transition mirrors under `personal-stack/*`. Consumers pass inventory-owned node facts into the helper; this repository does not carry the inventory.

## Local Validation

```bash
nix flake check --print-build-logs
```

## Links

- [Organization profile](https://github.com/JorisJonkers-dev)
- [Security policy](https://github.com/JorisJonkers-dev/.github/security/policy)
- [Changelog](./CHANGELOG.md)
- [License](./LICENSE)

Copyright (c) Joris Jonkers. Source available for viewing only; use, copying,
modification, redistribution, deployment, or reuse is not licensed. See
[LICENSE](./LICENSE).
