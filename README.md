# nix-fakecloud

Nix packaging for [fakecloud](https://github.com/faiscadev/fakecloud), a local
AWS cloud emulator, built against the fleet's pinned nixpkgs and pushed to a
binary cache so consumers do not compile it.

The fleet pin (`nixos-26.05`) ships no fakecloud at all — the crate was first
published after that branch was cut — so this repository is where fakecloud
comes from for every machine on the pin.

## Use it

```nix
{
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    nix-fakecloud.url = "github:pr0d1r2/nix-fakecloud";
    nix-fakecloud.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };
}
```

That last line is load-bearing. Without it your closure holds two different
nixpkgs revisions, the derivation hashes stop matching the ones in the cache,
and every consumer rebuilds fakecloud from source instead of fetching it.

Outputs:

| output | what it is |
| --- | --- |
| `packages.<system>.fakecloud` | the fakecloud binary |
| `packages.<system>.default` | same derivation |
| `overlays.default` | adds `pkgs.fakecloud` |
| `checks.<system>.fakecloud` | build with the upstream test suite enabled |
| `devShells.<system>.default` | the toolchain this repo is maintained with |
| `nixosModules.default` | `services.fakecloud` |

Ad hoc:

```console
$ nix run github:pr0d1r2/nix-fakecloud -- --version
$ nix run github:pr0d1r2/nix-fakecloud          # listens on 0.0.0.0:4566
```

## Binary cache

```
substituter: https://pr0d1r2.cachix.org
public key:  pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=
```

The flake declares both in `nixConfig`, so in the common case you get them for
free.

**The trap:** `nixConfig` is honoured only for users in `trusted-users`. If you
are not one, Nix prints a warning, ignores the substituter, and builds
fakecloud from source — several hundred crates — while looking like it is
working correctly. It does not fail. If a `nix build` you expected to be
instant is compiling, this is why. Put the substituter and key in your own
`nix.conf` (or `nix.settings` on NixOS) instead of relying on the flake's.

## What you are fetching

Measured on aarch64-darwin, 2026-08-22, building 0.44.10 from the crates.io
release tarball:

| | |
| --- | --- |
| binary | 181,020,528 bytes |
| closure | 216.3 MiB |
| build | 27m34s to compile, 1m28s to test, on 10 cores |
| startup | 0.096s to the first HTTP answer |
| idle RSS | 25.2 MB |
| services | 105 registered |

The binary is large — roughly nine times the size upstream advertises. It is
not debug symbols (there are none, and a full strip only reaches 155,659,440
bytes) and it is not a missing release profile (neither the published crate
nor upstream's workspace defines one). The gap is unexplained rather than
guessed at. It is also the best argument for the cache: nobody wants to spend
half an hour producing it themselves.

## Systems

| system | evaluated | built and cached by CI |
| --- | --- | --- |
| `aarch64-linux` | yes | yes |
| `x86_64-linux` | yes | yes |
| `aarch64-darwin` | yes | yes |
| `x86_64-darwin` | yes | **no** |

`x86_64-darwin` is kept evaluating but is not built by CI and has no cache
entries: building it there means compiling locally. Nixpkgs also warns that
26.05 is the last release to support the platform, so it is on its way out
rather than waiting for more CI budget.

## NixOS module

```nix
{
  imports = [ inputs.nix-fakecloud.nixosModules.default ];
  services.fakecloud.enable = true;
}
```

Defaults: listens on `127.0.0.1:4566`, runs as a dedicated unprivileged
`fakecloud` user with its own state directory.

**fakecloud has no authentication.** It accepts the dummy credentials
`test`/`test` from anybody, by design — it is an emulator, not a cloud.
Upstream's own default is to listen on `0.0.0.0`; this module's is not,
because binding an unauthenticated AWS control plane to a routable address
hands resource creation and deletion to anything that can reach the port. If
you set `bindAddress = "0.0.0.0"`, put something authenticating in front of it.

The module does not pull in a container runtime. fakecloud shells out to
Docker or Podman for Lambda, RDS, ElastiCache, MQ, MSK, ECS and EC2; with no
runtime present it starts, warns, and serves those metadata-only rather than
failing. Install a runtime yourself if you need them, or point
`FAKECLOUD_CONTAINER_CLI` at one. S3, SQS, DynamoDB and the rest work without.

State is kept in RAM unless you ask for persistence:

```nix
services.fakecloud.extraArgs = [ "--storage-mode=persistent" ];
```

## Licence

This repository is MIT — see [LICENSE](LICENSE). It covers the packaging: the
Nix expressions, the module, the workflows, the docs.

fakecloud itself is a separate work under **AGPL-3.0-or-later**, fetched from
its own release artefacts at build time. This repository does not vendor it,
does not patch it, and does not re-export its library crates; consumers talk to
the binary over its HTTP endpoint. Anything you build here contains fakecloud,
and that binary is governed by the AGPL, not by this repository's licence. Bugs
in fakecloud belong upstream, not in a patch here.

## Working on this repository

`direnv allow`, or `nix develop`. Both give you the pinned toolchain: `nixfmt`,
`statix`, `nurl`, `nix-prefetch-git`, `shellcheck`, `actionlint` and `cachix`.

Before pushing:

```console
$ nixfmt .
$ statix check
$ nix flake check --all-systems
```

`--all-systems` is not optional. The bare form silently skips systems the
runner cannot evaluate, so a broken `x86_64-darwin` stays green until someone
tries to use it.

`SPEC.md` is the contract this repository is built against — invariants,
constraints, and the task list. Read it before changing behaviour.
