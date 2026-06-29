{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.services.mediaStorage;

  dirRules =
    path:
    [
      "d ${path} ${cfg.directoryMode} ${cfg.owner} ${cfg.group} - -"
      "z ${path} ${cfg.directoryMode} ${cfg.owner} ${cfg.group} - -"
    ];

  mediaDirectoryRules =
    lib.flatten (map (name: dirRules "${cfg.root}/${name}") cfg.directories);

  appStateRules =
    lib.optionals (cfg.appStateRoot != null) (
      [ "d ${cfg.appStateRoot} 0755 ${cfg.owner} ${cfg.group} - -" ]
      ++ map (name: "d ${cfg.appStateRoot}/${name} 0755 ${cfg.owner} ${cfg.group} - -") cfg.appStateDirectories
    );

  scratchRules =
    lib.optionals (cfg.scratch.path != null) (
      dirRules cfg.scratch.path
      ++ lib.optional cfg.scratch.nodatacow "h ${cfg.scratch.path} - - - - +C"
    );

  viewTarget = name: "${cfg.viewsRoot}/${name}";
  viewRules =
    lib.optionals (cfg.viewBinds != { }) (
      [ "d ${cfg.viewsRoot} 0755 root root - -" ]
      ++ lib.mapAttrsToList (name: _: "d ${viewTarget name} 0755 root root - -") cfg.viewBinds
    );

  physicalFileSystems =
    lib.mapAttrs
      (
        _: mount:
        {
          inherit (mount) device fsType options;
        }
      )
      cfg.mounts;

  bindFileSystems =
    lib.mapAttrs'
      (
        name: source:
        lib.nameValuePair (viewTarget name) {
          device = source;
          fsType = "none";
          options = [
            "bind"
            "nofail"
          ];
        }
      )
      cfg.viewBinds;
in
{
  options.platformBlueprints.services.mediaStorage = {
    enable = lib.mkEnableOption "generic media storage directories, mounts, and views";

    owner = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Owner used for managed media directories.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group used for managed media directories.";
    };

    directoryMode = lib.mkOption {
      type = lib.types.str;
      default = "0775";
      description = "Mode used for managed media directories.";
    };

    root = lib.mkOption {
      type = lib.types.str;
      default = "/srv/media";
      description = "Root media directory managed by tmpfiles.";
    };

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "Completed"
        "Films"
        "Series"
      ];
      description = "Relative directories created under root.";
    };

    appStateRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/media-services";
      description = "Optional root for application state directories.";
    };

    appStateDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Relative directories created under appStateRoot.";
    };

    installNtfsTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install ntfs3g recovery utilities for hosts that still attach NTFS media volumes.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "Caller-owned block device, label, UUID, or network mount source.";
          };
          fsType = lib.mkOption {
            type = lib.types.str;
            default = "btrfs";
            description = "Filesystem type.";
          };
          options = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "noatime"
              "nofail"
            ];
            description = "Mount options.";
          };
        };
      });
      default = { };
      description = "Concrete media mounts keyed by mountpoint. Values are caller-owned and not provided by this library.";
    };

    viewsRoot = lib.mkOption {
      type = lib.types.str;
      default = "/srv/media-views";
      description = "Root path for bind-mounted media views.";
    };

    viewBinds = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "library/Films" = "/srv/media/Films";
      };
      description = "Bind mount views, keyed by path relative to viewsRoot with source paths as values.";
    };

    scratch = {
      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/srv/media-incomplete";
        description = "Optional scratch path for active downloads or transcodes.";
      };

      nodatacow = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Apply +C to the scratch path through tmpfiles.";
      };

      quotaLimit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "250G";
        description = "Optional btrfs qgroup limit applied to scratch.path.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      systemd.tmpfiles.rules =
        dirRules cfg.root
        ++ mediaDirectoryRules
        ++ appStateRules
        ++ scratchRules
        ++ viewRules;

      fileSystems = physicalFileSystems // bindFileSystems;
    }

    (lib.mkIf cfg.installNtfsTools {
      environment.systemPackages = [ pkgs.ntfs3g ];
    })

    (lib.mkIf (cfg.scratch.path != null && cfg.scratch.quotaLimit != null) {
      systemd.services.media-storage-scratch-setup = {
        description = "Apply ownership and quota to media scratch storage";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = [ cfg.scratch.path ];
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          chown ${cfg.owner}:${cfg.group} ${cfg.scratch.path}
          chmod ${cfg.directoryMode} ${cfg.scratch.path}
          btrfs quota enable ${cfg.scratch.path} || true
          btrfs qgroup limit ${cfg.scratch.quotaLimit} ${cfg.scratch.path}
        '';
      };
    })
  ]);
}
