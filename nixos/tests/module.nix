# VM test for the fakecloud NixOS module.
#
# Two nodes on purpose. The claim worth testing is not "the service starts" --
# it is "the service starts AND is not reachable from another host", which a
# single-node test cannot express (SPEC V20, V21).
{ self }:
{
  name = "fakecloud-module";

  nodes = {
    server =
      { ... }:
      {
        imports = [ self.nixosModules.default ];
        services.fakecloud.enable = true;
        environment.systemPackages = [ ];
      };

    # Second server, in the other storage mode. `storageMode` exists because
    # fakecloud rejects `--data-path` without it, so the option is only proven
    # by a unit that actually comes up with it set (SPEC V28, B3).
    persistent =
      { ... }:
      {
        imports = [ self.nixosModules.default ];
        services.fakecloud = {
          enable = true;
          storageMode = "persistent";
        };
      };

    # Deliberately vanilla: its only job is to try to reach the server.
    client =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.curl ];
      };
  };

  testScript = ''
    start_all()

    server.wait_for_unit("fakecloud.service")
    server.wait_for_open_port(4566, addr = "127.0.0.1")

    # Answers on loopback. Any HTTP status counts -- this asserts the service
    # is reachable, not what it thinks of the request.
    server.succeed("curl -s -o /dev/null -m 5 http://127.0.0.1:4566/")

    # Runs as its own unprivileged user, not root (SPEC V21).
    server.succeed("systemctl show -p User --value fakecloud.service | grep -qx fakecloud")
    server.succeed("test \"$(stat -c %U /var/lib/fakecloud)\" = fakecloud")
    server.fail("systemctl show -p User --value fakecloud.service | grep -qx root")

    # Not listening anywhere else. `ss` output would show 0.0.0.0:4566 if the
    # module had let upstream's default through.
    server.succeed("ss -ltnH 'sport = :4566' | grep -q '127.0.0.1:4566'")
    server.fail("ss -ltnH 'sport = :4566' | grep -q '0.0.0.0:4566'")

    # And the point of the second node: another host cannot reach it (SPEC
    # V20). curl exits non-zero on a refused connection.
    client.wait_for_unit("multi-user.target")
    client.fail("curl -s -o /dev/null -m 5 http://server:4566/")


    # The persistent mode really starts, and really writes where it was told.
    persistent.wait_for_unit("fakecloud.service")
    persistent.wait_for_open_port(4566, addr = "127.0.0.1")
    persistent.succeed("curl -s -o /dev/null -m 5 http://127.0.0.1:4566/")
    persistent.succeed("systemctl show -p ExecStart --value fakecloud.service | grep -q -- --storage-mode=persistent")
    persistent.succeed("systemctl show -p ExecStart --value fakecloud.service | grep -q -- --data-path=/var/lib/fakecloud")

    # And the default mode does NOT pass a data path, which is what made the
    # service crash-loop before (SPEC B3).
    server.fail("systemctl show -p ExecStart --value fakecloud.service | grep -q -- --data-path")

    # Nothing here asserts Lambda, RDS, ElastiCache, MQ, MSK, ECS or EC2 work:
    # those need a container runtime the module does not pull in, and without
    # one fakecloud serves them metadata-only by design.
  '';
}
