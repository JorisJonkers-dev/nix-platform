{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.gpuAmd;

  rocmSmiWrapped = pkgs.symlinkJoin {
    name = "rocm-smi-wrapped";
    paths = [ pkgs.rocmPackages.rocm-smi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rocm-smi \
        --prefix LD_LIBRARY_PATH : ${pkgs.libdrm}/lib
    '';
  };

  unfreeNamePrefixes = [
    "amdgpu-"
    "amdvlk"
    "hip"
    "rocm"
  ];
in
{
  imports = [ ./gpu-utility.nix ];

  options.platformBlueprints.roles.gpuAmd = {
    enable = lib.mkEnableOption "AMD GPU host role with Mesa, ROCm, and scheduler labels";

    enable32BitGraphics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit Mesa userspace for Vulkan and OpenGL workloads.";
    };

    enableRedistributableFirmware = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable redistributable firmware blobs required by AMD GPUs.";
    };

    allowUnfreePackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow AMD GPU and ROCm package names that nixpkgs marks unfree.";
    };

    installUtilities = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install AMD GPU and ROCm inspection tools.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        clinfo
        libdrm
        libva-utils
        pciutils
        radeontop
        rocmSmiWrapped
        rocmPackages.rocminfo
        vulkan-tools
      ];
      description = "AMD GPU utility packages installed when installUtilities is true.";
    };

    rocmRuntimeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/rocm";
      description = "Optional runtime directory created with render-group ownership for ROCm workloads.";
    };

    renderGroup = lib.mkOption {
      type = lib.types.str;
      default = "render";
      description = "Group that should own ROCm runtime state and /dev/kfd.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.initrd.kernelModules = [ "amdgpu" ];
      boot.kernelModules = [
        "amdgpu"
        "kvm-amd"
      ];

      hardware.enableRedistributableFirmware = cfg.enableRedistributableFirmware;
      hardware.firmware = [ pkgs.linux-firmware ];
      hardware.graphics = {
        enable = true;
        enable32Bit = cfg.enable32BitGraphics;
        extraPackages = with pkgs; [
          libva
          libvdpau-va-gl
          mesa
          rocmPackages.clr.icd
        ];
        extraPackages32 = lib.mkIf cfg.enable32BitGraphics (with pkgs.pkgsi686Linux; [
          mesa
        ]);
      };

      services.udev.extraRules = ''
        KERNEL=="kfd", GROUP="${cfg.renderGroup}", MODE="0660"
      '';

      platformBlueprints.roles.gpuUtility = {
        enable = true;
        gpuVendors = [ "amd" ];
        installUtilities = false;
      };

      assertions = [
        {
          assertion = config.hardware.graphics.enable;
          message = "platformBlueprints.roles.gpuAmd requires hardware.graphics.enable.";
        }
      ];
    }

    (lib.mkIf cfg.allowUnfreePackages {
      nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
        pkg:
        let
          name = lib.getName pkg;
        in
        lib.any (prefix: lib.hasPrefix prefix name) unfreeNamePrefixes
      );
    })

    (lib.mkIf cfg.installUtilities {
      environment.systemPackages = cfg.packages;
    })

    (lib.mkIf (cfg.rocmRuntimeDirectory != null) {
      systemd.tmpfiles.rules = [
        "d ${cfg.rocmRuntimeDirectory} 0755 root ${cfg.renderGroup} - -"
      ];
    })
  ]);
}
