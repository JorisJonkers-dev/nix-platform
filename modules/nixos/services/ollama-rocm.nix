{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.services.ollamaRocm;
in
{
  options.platformBlueprints.services.ollamaRocm = {
    enable = lib.mkEnableOption "Ollama service using the ROCm package variant";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Ollama listen host.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Ollama listen port.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama";
      description = "Ollama home directory.";
    };

    models = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama/models";
      description = "Ollama model directory.";
    };

    loadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Models pulled during activation by the NixOS Ollama module.";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        HIP_VISIBLE_DEVICES = "0";
        OLLAMA_KEEP_ALIVE = "5m";
      };
      description = "Environment variables passed to the Ollama daemon.";
    };

    supplementaryGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "render"
        "video"
      ];
      description = "Supplementary groups granted to the Ollama systemd service.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Ollama TCP port in the host firewall.";
    };

    requireAmdGraphics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Assert that the AMD graphics stack is enabled.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-rocm;
        inherit (cfg) host port home models loadModels environmentVariables;
      };

      systemd.services.ollama.serviceConfig.SupplementaryGroups = cfg.supplementaryGroups;
    }

    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [ cfg.port ];
    })

    (lib.mkIf cfg.requireAmdGraphics {
      assertions = [
        {
          assertion = config.hardware.graphics.enable;
          message = "platformBlueprints.services.ollamaRocm requires hardware.graphics.enable or requireAmdGraphics = false.";
        }
      ];
    })
  ]);
}
