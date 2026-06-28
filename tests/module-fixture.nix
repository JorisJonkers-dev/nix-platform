{ self, nixpkgs, system }:
let
  lib = nixpkgs.lib;
in
lib.nixosSystem {
  inherit system;
  modules = [
    self.nixosModules.base
    self.nixosModules.k3s
    self.nixosModules.roleK3sBootstrap
    self.nixosModules.roleK3sServer
    self.nixosModules.roleK3sAgent
    self.nixosModules.roleTailscaleSubnetRouter
    self.nixosModules.hardwareRaspberryPiAarch64
    (
      { pkgs, ... }:
      {
        boot.loader.grub.enable = false;
        fileSystems."/".device = "fixture-root";
        fileSystems."/".fsType = "ext4";
        system.stateVersion = "25.05";

        platformBlueprints.base = {
          enable = true;
          ssh.ports = [ 22 ];
          deployUser = {
            enable = true;
            name = "deploy";
            authorizedKeys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureKeyMaterialOnly000000000000000000000"
            ];
            passwordlessSudo = true;
          };
          resolver = {
            nameservers = [ "RESOLVER_ADDRESS" ];
            options = [
              "timeout:1"
              "attempts:2"
            ];
          };
          timeZone = "UTC";
          defaultLocale = "en_US.UTF-8";
        };

        platformBlueprints.roles.k3sServer = {
          enable = true;
          oidc = {
            issuerUrl = "OIDC_ISSUER_URL";
            clientId = "dashboard";
            groupsClaim = "groups";
          };
        };

        platformBlueprints.k3s = {
          flannelInterface = "mesh0";
          waitForInterface.name = "mesh0";
          requiredServices = [ "network-online.target" ];
          nodeLabels.role = "fixture";
          nodeTaints = [ "fixture=true:NoSchedule" ];
        };

        platformBlueprints.roles.k3sBootstrap = {
          enable = true;
          flannelInterface = "mesh0";
          waitForInterface = true;
          nodeLabels.bootstrap = "fixture";
        };

        platformBlueprints.roles.tailscaleSubnetRouter = {
          enable = true;
          advertiseRoutes = [ "10.42.0.0/16" ];
          useForK3sFlannel = true;
          waitForK3s = true;
        };

        environment.systemPackages = [ pkgs.hello ];
      }
    )
  ];
}
