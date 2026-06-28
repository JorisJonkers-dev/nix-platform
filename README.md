# nix-platform

Reusable NixOS modules and helper library for JorisJonkers-dev platform hosts.

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
- `nixosModules.roleControlPlane`
- `nixosModules.roleWorker`
- `nixosModules.roleNetworkTailscale`
- `nixosModules.hardwareRaspberryPiAarch64`
- `nixosModules.imageRaspberryPiSdImage`

## Fleet Helpers

`lib.nixosFleet` maps fleet roles to NixOS modules:

- `base`
- `k3s-bootstrap`
- `k3s-server`
- `k3s-agent`
- `raspberry-pi-aarch64`
- `raspberry-pi-sd-image`
- `tailscale-subnet-router`

Compatibility aliases are retained for `k3s-control-plane`, `k3s-worker`, and `tailscale-network`.

## Local Validation

```bash
nix flake check --print-build-logs
```
