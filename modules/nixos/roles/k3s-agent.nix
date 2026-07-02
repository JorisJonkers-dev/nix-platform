{
  config,
  lib,
  ...
}: let
  cfg = config.platformBlueprints.roles.k3sAgent;
in {
  imports = [../k3s.nix];

  options.platformBlueprints.roles.k3sAgent = {
    enable = lib.mkEnableOption "generic k3s agent role";
  };

  config = lib.mkIf cfg.enable {
    platformBlueprints.k3s = {
      enable = true;
      role = lib.mkDefault "agent";
    };
  };
}
