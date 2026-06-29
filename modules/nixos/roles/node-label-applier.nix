{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.nodeLabelApplier;
  labelArgs = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.labels;
  labelCommands = map (
    label:
    "${cfg.kubectlPackage}/bin/kubectl --kubeconfig ${lib.escapeShellArg cfg.kubeconfigFile} label node ${lib.escapeShellArg cfg.nodeName} ${lib.escapeShellArg label} --overwrite"
  ) labelArgs;
  taintCommands = map (
    taint:
    "${cfg.kubectlPackage}/bin/kubectl --kubeconfig ${lib.escapeShellArg cfg.kubeconfigFile} taint node ${lib.escapeShellArg cfg.nodeName} ${lib.escapeShellArg taint} --overwrite"
  ) cfg.taints;
in
{
  options.platformBlueprints.roles.nodeLabelApplier = {
    enable = lib.mkEnableOption "generic Kubernetes node label and taint applier";

    nodeName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = "config.networking.hostName";
      description = "Kubernetes node name to label or taint.";
    };

    kubeconfigFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/rancher/k3s/k3s.yaml";
      description = "Kubeconfig used by the local node-label-applier service.";
    };

    kubectlPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubectl;
      defaultText = "pkgs.kubectl";
      description = "kubectl package used by the node-label-applier service.";
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Kubernetes labels applied with --overwrite.";
    };

    taints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Kubernetes taints applied with --overwrite.";
    };

    after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "k3s.service" ];
      description = "Systemd units that should start before node-label-applier.";
    };

    wantedBy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "multi-user.target" ];
      description = "Systemd targets that want node-label-applier.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.labels != { } || cfg.taints != [ ];
        message = "nodeLabelApplier requires at least one label or taint.";
      }
    ];

    systemd.services.node-label-applier = {
      description = "Apply Kubernetes node labels and taints";
      after = cfg.after;
      wants = cfg.after;
      wantedBy = cfg.wantedBy;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ cfg.kubectlPackage ];
      script = lib.concatStringsSep "\n" (labelCommands ++ taintCommands);
    };
  };
}
