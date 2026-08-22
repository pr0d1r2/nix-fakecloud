# NixOS module for fakecloud.
#
# Why a NixOS module and not a launchd one: `orgmulacra` runs fakecloud on a
# Linux substrate, and on macOS that substrate is a lima Linux guest -- so the
# Linux module is the Mac path too. There is deliberately no darwin service.
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fakecloud";
      description = ''
        Directory passed to fakecloud as `--data-path`, and created as the
        service's `StateDirectory` when it is left at the default.

        fakecloud only writes here in persistent storage mode; its default mode
        keeps all state in RAM and discards it on restart. To persist, add
        `--storage-mode=persistent` to {option}`services.fakecloud.extraArgs`.
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
        "--storage-mode=persistent"
        "--region=eu-central-1"
      ];
      description = ''
        Extra command line arguments, appended after the ones this module sets.
        See `fakecloud --help`.
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
            "--data-path=${cfg.dataDir}"
          ]
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
