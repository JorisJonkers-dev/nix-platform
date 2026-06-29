{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.services.btrfsBackupSnapshots;
in
{
  options.platformBlueprints.services.btrfsBackupSnapshots = {
    enable = lib.mkEnableOption "scheduled btrfs snapshot send/receive backup";

    serviceName = lib.mkOption {
      type = lib.types.str;
      default = "btrfs-backup-snapshots";
      description = "Systemd service and timer name.";
    };

    sourceSubvolume = lib.mkOption {
      type = lib.types.str;
      example = "/srv/media/Backup";
      description = "Source btrfs subvolume to snapshot.";
    };

    sourceSnapshotDirectory = lib.mkOption {
      type = lib.types.str;
      example = "/srv/media/.snapshots";
      description = "Directory that stores local read-only snapshots.";
    };

    destinationSnapshotDirectory = lib.mkOption {
      type = lib.types.str;
      example = "/srv/backup/.snapshots/Backup";
      description = "Directory that receives backup snapshots.";
    };

    snapshotPrefix = lib.mkOption {
      type = lib.types.str;
      default = "Backup";
      description = "Prefix for generated snapshot names.";
    };

    keepSource = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Number of source snapshots to retain.";
    };

    keepDestination = lib.mkOption {
      type = lib.types.ints.positive;
      default = 26;
      description = "Number of destination snapshots to retain.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "Sun 03:00";
      description = "systemd timer OnCalendar expression.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "systemd timer RandomizedDelaySec value.";
    };

    timeoutStartSec = lib.mkOption {
      type = lib.types.str;
      default = "12h";
      description = "Maximum runtime for the snapshot send service.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.keepSource >= 2;
        message = "platformBlueprints.services.btrfsBackupSnapshots.keepSource must be at least 2 for incremental sends.";
      }
    ];

    systemd.services.${cfg.serviceName} = {
      description = "btrfs snapshot send/receive backup";
      path = [
        pkgs.btrfs-progs
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
      ];
      unitConfig.RequiresMountsFor = [
        cfg.sourceSubvolume
        cfg.sourceSnapshotDirectory
        cfg.destinationSnapshotDirectory
      ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        TimeoutStartSec = cfg.timeoutStartSec;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [
          cfg.sourceSnapshotDirectory
          cfg.destinationSnapshotDirectory
        ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
      script = ''
        set -euo pipefail

        SRC_SUBVOL=${cfg.sourceSubvolume}
        SRC_SNAP_DIR=${cfg.sourceSnapshotDirectory}
        DST_SNAP_DIR=${cfg.destinationSnapshotDirectory}
        SNAP_PREFIX=${cfg.snapshotPrefix}
        KEEP_SRC=${toString cfg.keepSource}
        KEEP_DST=${toString cfg.keepDestination}

        mkdir -p "$SRC_SNAP_DIR" "$DST_SNAP_DIR"

        while IFS= read -r entry; do
          recv_uuid=$(btrfs subvolume show "$entry" 2>/dev/null \
            | awk '/Received UUID:/ {print $3}' || true)
          if [[ -z "$recv_uuid" || "$recv_uuid" == "-" ]]; then
            echo "scrubbing partial received subvolume: $entry"
            btrfs subvolume delete "$entry"
          fi
        done < <(find "$DST_SNAP_DIR" -mindepth 1 -maxdepth 1 -name "$SNAP_PREFIX-*" -printf '%p\n')

        stamp=$(date -u +%Y%m%dT%H%M%SZ)
        new_snap="$SRC_SNAP_DIR/$SNAP_PREFIX-$stamp"

        btrfs subvolume snapshot -r "$SRC_SUBVOL" "$new_snap"

        parent=""
        while IFS= read -r src_name; do
          src_path="$SRC_SNAP_DIR/$src_name"
          dst_path="$DST_SNAP_DIR/$src_name"
          if [[ "$src_path" == "$new_snap" ]]; then continue; fi
          if [[ ! -d "$dst_path" ]]; then continue; fi
          recv_uuid=$(btrfs subvolume show "$dst_path" 2>/dev/null \
            | awk '/Received UUID:/ {print $3}' || true)
          if [[ -z "$recv_uuid" || "$recv_uuid" == "-" ]]; then continue; fi
          parent="$src_path"
          break
        done < <(find "$SRC_SNAP_DIR" -mindepth 1 -maxdepth 1 -name "$SNAP_PREFIX-*" -printf '%f\n' | sort -r)

        if [[ -n "$parent" ]]; then
          echo "incremental send: parent=$parent -> $new_snap"
          btrfs send -p "$parent" "$new_snap" | btrfs receive "$DST_SNAP_DIR"
        else
          echo "WARNING: no valid parent found - sending full snapshot ($new_snap)"
          btrfs send "$new_snap" | btrfs receive "$DST_SNAP_DIR"
        fi

        prune() {
          local dir="$1" keep="$2" label="$3"
          mapfile -t snaps < <(find "$dir" -mindepth 1 -maxdepth 1 -name "$SNAP_PREFIX-*" -printf '%f\n' | sort)
          local n=''${#snaps[@]}
          if (( n > keep )); then
            local to_remove=$(( n - keep ))
            echo "pruning $to_remove old $label snapshot(s) (keep $keep of $n)"
            for s in "''${snaps[@]:0:to_remove}"; do
              btrfs subvolume delete "$dir/$s"
            done
          fi
        }

        prune "$SRC_SNAP_DIR" "$KEEP_SRC" source
        prune "$DST_SNAP_DIR" "$KEEP_DST" destination
      '';
    };

    systemd.timers.${cfg.serviceName} = {
      description = "Trigger ${cfg.serviceName}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        AccuracySec = "1min";
      };
    };
  };
}
