{
  description = "fakecloud for nixos 26.05 -- current fakecloud, built from the fleet's pinned nixpkgs";

  # fakecloud is built here and pushed to this cache. The pinned nixpkgs ships
  # no fakecloud at all -- the crate is newer than the nixos-26.05 branch-off --
  # so without the substituter every consumer builds a ~19 MB Rust binary from
  # source. Declared here so the cache travels with the flake; note that a user
  # outside `trusted-users` still gets a silent source build and only a warning
  # (SPEC V6, and see README).
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE input (SPEC V11). nixpkgs-lock is the fleet's sole nixpkgs authority and
  # nixpkgs follows it, so every repo that consumes fakecloud resolves to the
  # same nixpkgs rev -- which is what makes the cachix binaries hit instead of
  # rebuilding. A second nixpkgs edge here would silently fork that rev.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Declared: 4. CI builds and caches 3 of them; x86_64-darwin is tier-2 --
      # it must evaluate everywhere but is built locally, not by CI (SPEC V16).
      # Same tiering as ../nix-hk, same reason: GitHub's only Intel macOS runner
      # is on its way out, so the platform is kept and the CI spend is not.
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # `packages`, `overlays` and `checks` are wired here; `nixosModules`
      # follows at T13.
      packages = forAllSystems (pkgs: rec {
        fakecloud = pkgs.callPackage ./pkgs/fakecloud/package.nix { };
        default = fakecloud;
      });

      # Consumers that already have a nixpkgs of their own take the overlay
      # instead of the package, and get `pkgs.fakecloud` in the usual place.
      # It must resolve to the same derivation as `packages.<sys>.fakecloud`,
      # or the cache hit consumers came for evaporates.
      overlays.default = _final: prev: {
        fakecloud = prev.callPackage ./pkgs/fakecloud/package.nix { };
      };

      # The package already runs the upstream test suite (`doCheck`) and
      # asserts its own version on install, so the check IS the build -- there
      # is nothing to duplicate here beyond making `nix flake check` build it.
      #
      # The VM test is Linux-only: NixOS VM tests need KVM and a Linux guest,
      # so on darwin it is not merely slow, it cannot run. Listing it there
      # would make `nix flake check` fail on the machines this repo is
      # maintained from.
      checks = forAllSystems (
        pkgs:
        {
          fakecloud = pkgs.callPackage ./pkgs/fakecloud/package.nix { };
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          module = pkgs.testers.runNixOSTest (import ./nixos/tests/module.nix { inherit self; });
        }
      );

      # The module defaults its package to `self.packages.<sys>.fakecloud`, so
      # a consumer that imports it gets the cached build without also having to
      # wire the overlay.
      nixosModules.default = import ./nixos/module.nix { inherit self; };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            # Nix gates, matching ../nix-hk's shell.
            pkgs.nixfmt
            pkgs.statix

            # For T2/T6/T7: resolving the real source and cargo hashes. `nurl`
            # emits the whole fetcher expression with its hash filled in, which
            # is the part that is easy to typo by hand; `nix-prefetch-git` is
            # the fallback when the source turns out not to be a plain GitHub
            # tag. Both are here because T2 has not decided between crates.io
            # and fetchFromGitHub yet -- drop the loser once it has.
            pkgs.nurl
            pkgs.nix-prefetch-git

            # For T15-T17: the CI workflows are shell and YAML, and nix-hk
            # learned the hard way that a green job is not evidence of a
            # populated cache. These let the checks be written and linted here
            # rather than debugged in Actions.
            pkgs.shellcheck
            pkgs.actionlint
            pkgs.cachix

            pkgs.git
          ];
        };
      });
    };
}
