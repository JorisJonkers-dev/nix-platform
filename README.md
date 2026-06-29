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
- `nixosModules.roleNodeLabelApplier`
- `nixosModules.roleControlPlane`
- `nixosModules.roleWorker`
- `nixosModules.roleNetworkTailscale`
- `nixosModules.roleStorageLonghorn`
- `nixosModules.roleAcceleratorGpu`
- `nixosModules.hardwareRaspberryPiAarch64`
- `nixosModules.imageRaspberryPiSdImage`

## Fleet Helpers

`lib.nixosFleet` maps fleet roles to NixOS modules:

- `base`
- `k3s-bootstrap`
- `k3s-server`
- `k3s-agent`
- `longhorn-node`
- `gpu-utility`
- `node-label-applier`
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
