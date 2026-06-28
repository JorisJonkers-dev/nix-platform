{
  description = "Reusable NixOS modules and helpers for JorisJonkers-dev platform hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      mkPkgs = system: import nixpkgs { inherit system; };
      moduleFixture =
        system:
        import ./tests/module-fixture.nix {
          inherit self nixpkgs system;
        };
    in
    {
      nixosModules = rec {
        base = ./modules/nixos/base.nix;
        k3s = ./modules/nixos/k3s.nix;

        roleK3sBootstrap = ./modules/nixos/roles/k3s-bootstrap.nix;
        roleK3sServer = ./modules/nixos/roles/k3s-server.nix;
        roleK3sAgent = ./modules/nixos/roles/k3s-agent.nix;
        roleTailscaleSubnetRouter = ./modules/nixos/roles/tailscale-subnet-router.nix;

        roleControlPlane = roleK3sServer;
        roleWorker = roleK3sAgent;
        roleNetworkTailscale = roleTailscaleSubnetRouter;

        hardwareRaspberryPiAarch64 = ./modules/nixos/hardware/raspberry-pi-aarch64.nix;
        imageRaspberryPiSdImage = ./modules/nixos/image/raspberry-pi-sd-image.nix;

        roles = {
          k3sBootstrap = roleK3sBootstrap;
          k3sServer = roleK3sServer;
          k3sAgent = roleK3sAgent;
          tailscaleSubnetRouter = roleTailscaleSubnetRouter;
          controlPlane = roleControlPlane;
          worker = roleWorker;
          networkTailscale = roleNetworkTailscale;
        };

        default = {
          imports = [
            base
            k3s
          ];
        };
      };

      lib = {
        nixosFleet = import ./lib/nixos/fleet-to-flake.nix {
          inherit lib;
        };
      };

      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          fixture = moduleFixture system;
          fixtureDrvPath = builtins.unsafeDiscardStringContext fixture.config.system.build.toplevel.drvPath;
        in
        {
          module-fixture = pkgs.runCommand "nix-platform-module-fixture" { } ''
            printf '%s\n' '${fixtureDrvPath}' > "$out"
          '';
        }
      );
    };
}
