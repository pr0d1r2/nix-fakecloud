# NixOS module for fakecloud.
#
# Why a NixOS module and no launchd equivalent: fakecloud is run on a Linux
# substrate, and on macOS that substrate is a Linux guest in a VM -- so the
# NixOS module is the Mac path too, one service definition instead of two.
#
# Takes `self` so the default package is this flake's own build, which is the
# build the binary cache has.
{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.fakecloud;
in
{
  options.services.fakecloud = {
    enable = lib.mkEnableOption "fakecloud, a local AWS cloud emulator";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.fakecloud;
      defaultText = lib.literalExpression "nix-fakecloud.packages.\${system}.fakecloud";
      description = ''
        fakecloud package to run. Defaults to this flake's own build, which is
        the one published to the binary cache; pointing this elsewhere means
        building it yourself.
      '';
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address to listen on.

        The default is loopback-only and deliberately differs from fakecloud's
        own default of `0.0.0.0`. fakecloud has no authentication by design --
        it accepts the dummy credentials `test`/`test` from anyone -- so
        binding it to a routable address publishes an AWS control plane that
        will create, mutate and delete resources for any host that can reach
        the port.

        Widening this is a deliberate opt-in. If you do it, put something that
        authenticates in front of it.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4566;
      description = ''
        Port to listen on. 4566 is the port AWS SDK clients are conventionally
        pointed at, so changing it means changing every client endpoint too.
      '';
    };

    storageMode = lib.mkOption {
      type = lib.types.enum [
        "memory"
        "persistent"
      ];
      default = "memory";
      description = ''
        Where fakecloud keeps state. `memory` is upstream's default and
        discards everything on restart; `persistent` mirrors supported services
        to {option}`services.fakecloud.dataDir`.

        This is a typed option rather than something you pass through
        {option}`services.fakecloud.extraArgs` because the two flags are not
        independent: fakecloud refuses to start if `--data-path` is given
        without `--storage-mode=persistent`, so the module has to know which
        mode you want in order to build a command line it will accept
        (SPEC B3).
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fakecloud";
      description = ''
        Directory fakecloud persists state to, and created as the service's
        `StateDirectory` when it is left at the default.

        Only used when {option}`services.fakecloud.storageMode` is
        `persistent`; in the default `memory` mode it is not passed to
        fakecloud at all, because fakecloud refuses to start with a data path
        it has no mode for.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "fakecloud";
      description = ''
        User to run as. Defaults to a dedicated unprivileged user created by
        this module; fakecloud has no reason to run as root.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "fakecloud";
      description = "Group to run as.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--region=eu-central-1"
        "--log-level=debug"
      ];
      description = ''
        Extra command line arguments, appended after the ones this module sets.
        See `fakecloud --help`. Storage mode belongs in
        {option}`services.fakecloud.storageMode`, not here -- it has to agree
        with `--data-path`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "fakecloud") {
      fakecloud = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
        description = "fakecloud service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "fakecloud") { fakecloud = { }; };

    systemd.services.fakecloud = {
      description = "fakecloud local AWS cloud emulator";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--addr=${cfg.bindAddress}:${toString cfg.port}"
            "--storage-mode=${cfg.storageMode}"
          ]
          # Only in persistent mode. fakecloud rejects `--data-path` outright
          # when storage is in-memory -- it does not ignore it -- and the
          # service crash-loops to start-limit-hit (SPEC B3, caught by the VM
          # test's first real run).
          ++ lib.optional (cfg.storageMode == "persistent") "--data-path=${cfg.dataDir}"
          ++ cfg.extraArgs
        );

        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";

        # systemd owns the state directory when it is left in the default
        # place; a dataDir pointed elsewhere is the operator's to create.
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/fakecloud") "fakecloud";
        StateDirectoryMode = "0700";

        # Hardening. fakecloud holds no secrets worth having, but it accepts
        # unauthenticated requests that create resources, so bounding what a
        # bad request can reach is worth the few lines.
        AmbientCapabilities = [ ];
        CapabilityBoundingSet = [ ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          # systemd's own notify and journal sockets need this even though
          # fakecloud itself only speaks TCP.
          "AF_UNIX"
        ];

        # Note on what this module does NOT do: fakecloud shells out to a
        # container runtime for Lambda, RDS, ElastiCache, MQ, MSK, ECS and EC2.
        # With no runtime present it starts, warns, and serves those
        # metadata-only rather than failing. This module does not pull in
        # Docker or Podman -- that is the operator's choice, and it would
        # otherwise be a large hidden dependency for people who only want S3
        # and SQS.
      };
    };
  };
}
