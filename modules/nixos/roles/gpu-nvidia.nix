{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.gpuNvidia;

  unfreeNamePrefixes = [
    "cuda"
    "libcu"
    "libn"
    "libnv"
    "nvidia-"
  ];
in
{
  imports = [ ./gpu-utility.nix ];

  options.platformBlueprints.roles.gpuNvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU host role with container runtime integration";

    openDriver = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use NVIDIA's open kernel module variant.";
    };

    driverPackage = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = "config.boot.kernelPackages.nvidiaPackages.stable";
      description = "Optional NVIDIA driver package override.";
    };

    enableContainerToolkit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nvidia-container-toolkit and expose its runtime tools to k3s.";
    };

    skipCdiGeneratorWhenDriverMissing = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Skip CDI generation during activations where the running NVIDIA module is not loaded.";
    };

    allowUnfreePackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow NVIDIA and CUDA package names that nixpkgs marks unfree.";
    };

    installUtilities = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install basic GPU inspection utilities.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        libva
        pciutils
      ];
      description = "NVIDIA utility packages installed when installUtilities is true.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        open = cfg.openDriver;
        modesetting.enable = true;
        package = cfg.driverPackage;
      };

      platformBlueprints.roles.gpuUtility = {
        enable = true;
        gpuVendors = [ "nvidia" ];
        installUtilities = false;
      };
    }

    (lib.mkIf cfg.allowUnfreePackages {
      nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
        pkg:
        let
          name = lib.getName pkg;
          license = pkg.meta.license.shortName or "";
        in
        lib.any (prefix: lib.hasPrefix prefix name) unfreeNamePrefixes
        || license == "CUDA EULA"
      );
    })

    (lib.mkIf cfg.enableContainerToolkit {
      hardware.nvidia-container-toolkit.enable = true;

      systemd.services.k3s.path = lib.mkIf config.services.k3s.enable [
        pkgs.nvidia-container-toolkit.tools
        pkgs.runc
      ];
    })

    (lib.mkIf cfg.skipCdiGeneratorWhenDriverMissing {
      systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
        "/proc/driver/nvidia/version";
    })

    (lib.mkIf cfg.installUtilities {
      environment.systemPackages = cfg.packages;
    })
  ]);
}
