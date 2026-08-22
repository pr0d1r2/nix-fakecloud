# SPEC — nix-fakecloud

## §G goal

Deliver `fakecloud` (0.44.10) to fleet systems. Fleet pin `nixos-26.05` ships ⊥ fakecloud (crate first published 2026, after branch-off) ∴ this repo IS the fleet's fakecloud provider.

Nix flake build ∀ 4 systems; push cachix `pr0d1r2`; consumed prebuilt by `orgmulacra` (& any 26.05 host), ⊥ local compile.

Built w/ rustc from same 26.05 pin (1.95.0) ∴ one toolchain, one bump point (`nixpkgs-lock`).

**Public from first commit.** Repo opensources ∴ ⊥ secret in tree, ⊥ private-path assumption, LICENSE + README ! present before push.

Sibling of `../nix-hk`. Same shape, same lessons — see §C "inherited lessons".

## §C constraints

### upstream fakecloud

- crate: `fakecloud` **0.44.10** on crates.io. bin name `fakecloud`. edition **2021**. `rust-version` **unspecified** upstream ∴ floor ⊥ declared, ! measured vs pinned 1.95.0 (T3).
- licence **AGPL-3.0-or-later**. repo `github.com/faiscadev/fakecloud`.
- upstream = workspace. sibling crates published (`fakecloud-sdk`, `fakecloud-s3`, `fakecloud-codepipeline`, …) ∴ crates.io tarball of `fakecloud` alone ? sufficient. `fetchFromGitHub` @ tag likely needed for tests/fixtures. decide by measurement (T2).
- upstream tag naming ⊥ verified. `v0.44.10` assumed, ! confirmed before `srcHash` (T2).
- size: 105 services / 7391 operations, binary ~19 MB, ~10 MiB idle, ~300 ms start (upstream claims, ⊥ measured here — T12).
- large crate ∴ build minutes & closure size ! recorded. cachix ⊥ optional here, it is the point (§V.6).
- runtime: single binary, listens `:4566`, dummy creds `test`/`test`. ⊥ Docker needed to run fakecloud itself.

### inherited lessons (from `../nix-hk` §B — ⊥ relearn)

- **⊥ copy a recipe unverified.** nix-hk B1: upstream recipe's `libgit2` buildInput was vestigial, real crate vendored. B2: `openssl` buildInput cargo-culted, binary linked neither. ∴ §V.14 here: ∀ buildInput justified by a measured failure without it.
- **measure the PHASE, ⊥ the compile.** nix-hk: `cargo build` succeeded w/o `usage`, then `postInstall` shell-completion generation silently wrote 3 zero-size files. ∴ measure through `installPhase`/`postInstall`/`checkPhase`, ⊥ stop at a green compile.
- **green CI ≠ populated cache.** nix-hk B3/B4/B5: `cachix-action` no-ops on empty token & logs 403 WITHOUT failing the job; an assert placed inside the build job races the post-push step. ∴ §V.15: separate `verify-cache` job, `needs: build`, queries `<hash>.narinfo`.
- **`nix flake check` silently omits foreign systems.** ∴ `--all-systems` mandatory (§V.4).
- **`nixConfig` inert for untrusted users.** consumer ∉ `trusted-users` → silent source build + warning, ⊥ error. README ! say so.

### licence boundary (AGPL)

- fakecloud = AGPL-3.0-or-later. This repo = **packaging only**: fetch, build, install. ⊥ derivative work of fakecloud.
- ∴ this repo's own licence free to be fleet default (MIT). ! stated explicitly in LICENSE + README, ⊥ left inferred (§V.18).
- **⊥ vendor fakecloud source into this tree. ⊥ patch it.** Both open the derivative-work question that packaging alone avoids. Upstream bug → upstream PR, ⊥ local patch (§V.17).
- consumers reach fakecloud as a **binary over `:4566`**, ⊥ by linking `fakecloud-*` crates. That boundary lives in the consumer's spec (`orgmulacra` §V.25); this repo ! ⊥ make linking easy — ⊥ export the sub-crates.

### measured (2026-08-22, aarch64-darwin, this machine)

- **T1 answered.** Pinned nixpkgs `5880666fd9eb563038431edb35c2d0aa595884e6` (via nixpkgs-lock `216e0d3205877fc1ad797506e75fed7b2e08fe50`, 2026-08-21) provides ⊥ `fakecloud`. `nix eval …#fakecloud.version` → `does not provide attribute`, suggests `rmfakecloud` (reMarkable cloud, unrelated). ∴ §G holds, repo needed.
- nix-hk's §C cites rev `9f78f44a` — **stale**. nixpkgs-lock auto-bumps; ⊥ copy a rev between sibling specs, read the lock.
- `nix flake check --all-systems` → `all checks passed`, ∀ 4 systems eval clean, devShell derivation built ∀ 4.
- `nix develop` entered; `nixfmt` 1.4.0, `statix` 0-unstable-2026-05-14, `nurl` 0.4.0, `nix-prefetch-git` 26.05, `shellcheck` 0.11.0, `actionlint` 1.7.12, `cachix` 1.11.1, `git` 2.54.0 ∀ on PATH.
- **x86_64-darwin has an end date.** Eval emits: `Nixpkgs 26.05 will be the last release to support x86_64-darwin`. ∴ tier-2 is not merely uncached, it is terminal — the next pin bump past 26.05 removes the platform. §V.16 stands for now; revisit at that bump, ⊥ treat as permanent.
- **build 0.44.10 green (2026-08-22).** `buildPhase` 27m34s + `checkPhase` 1m28s, 10 cores, load ~23 (cargo `cores = 0` oversubscribes). tests: 103 unit ✓, 1 filtered (§B.1 skip).
- **⊥ buildInputs, ⊥ nativeBuildInputs.** whole workspace compiles & links bare. `libz-sys`/`zstd-sys`/`bzip2-sys`/`lzma-sys`/`ring` ∈ lock ! build own vendored C. `otool -L` → system frameworks + `libiconv` only. ∴ §V.14 satisfied by measurement, ⊥ by copying.
- **⊥ `[profile.release]`** in published crate ⊕ upstream workspace root. ∴ size below = plain cargo release, ⊥ a lost upstream profile.
- `fakecloud --version` → `fakecloud 0.44.10` (§T.4 answered, exact format).
- **§V.25 claims now measured** (aarch64-darwin):
  - services registered **105** — upstream claim ✓ matches.
  - startup **0.096 s** to first HTTP answer — beats claimed ~300 ms.
  - idle RSS **25.2 MB** — ~2.5x claimed ~10 MiB.
  - binary **181,020,528 B** installed (155,659,440 B after `strip -x`; `-S` strip leaves ~25 MB local syms) — **~9x** claimed ~19 MB. ⊥ debug sections present. gap ⊥ explained yet.
  - closure **216.3 MiB**. §V.23 baseline.
- **container runtime absent → degraded, ⊥ failed start.** startup WARN lists: Lambda (Invoke errors for code fns), RDS (CreateDBInstance/snapshot/replica error), ElastiCache (metadata-only), MQ & MSK (control-plane only), ECS (`RunTask` → `TaskFailedToStart`), EC2 (metadata-only instances). env `FAKECLOUD_CONTAINER_CLI` points at CLI. ∴ NixOS module & §T.14 VM test ! ⊥ assume container-backed ops work.

### pin graph

```
nixpkgs-lock ──> nix-fakecloud ──> orgmulacra
             └──> nix-hk ────────┘
```

- `github:pr0d1r2/nixpkgs-lock` = sole pin authority, ~80 consumers, tracks `nixos-26.05`.
- this repo: **1 input** — `nixpkgs-lock`, `nixpkgs.follows = "nixpkgs-lock/nixpkgs"`. 2nd nixpkgs edge forks the rev & kills ∀ cache hit (§V.11).
- consumer (`orgmulacra`) wires 3: `nixpkgs-lock`, `nix-hk`, `nix-fakecloud`, latter two `follows` the first.
- ⊥ re-export by nixpkgs-lock (cycle + breaks its leaf rule).

### build & CI

- systems declared = **4**: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`. ≡ nixpkgs-lock set.
- tier-1 = **3**: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. CI builds, tests, pushes cachix.
- tier-2 = `x86_64-darwin`. eval ! pass; build ⊥ CI-verified, ⊥ cached. README states it.
- flake pure eval. ⊥ IFD. `flake.lock` committed.
- cachix push from Actions on `main` only. fork PRs have ⊥ secret.
- aarch64-linux native on `ubuntu-24.04-arm`. ⊥ qemu, ⊥ cross.

### NixOS module

- `orgmulacra` runs fakecloud on Linux substrate ∴ this repo ships `nixosModules.default` → `services.fakecloud`.
- module defaults **bind `127.0.0.1`**, ⊥ `0.0.0.0`. fakecloud has ⊥ auth by design ∴ a public bind = open AWS control plane (§V.20).
- runs as own unprivileged user, own `StateDirectory`. ⊥ root (§V.21).
- darwin: ⊥ launchd module. Mac path = lima Linux guest, which uses the NixOS module.

## §I interfaces

- input (this repo):
  ```nix
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  };
  ```
- flake: `packages.<sys>.fakecloud` → fakecloud 0.44.10 derivation
- flake: `packages.<sys>.default` ≡ `packages.<sys>.fakecloud`
- flake: `overlays.default` → adds `pkgs.fakecloud`
- flake: `checks.<sys>.fakecloud` → build + test suite
- flake: `devShells.<sys>.default` → fakecloud + `nixfmt` + `statix`
- flake: `nixosModules.default` → `services.fakecloud.{enable,package,bindAddress,port,dataDir,user,group,extraArgs}`
- consumer (`orgmulacra`):
  ```nix
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-fakecloud.url = "github:pr0d1r2/nix-fakecloud";
    nix-fakecloud.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };
  ```
  `inputs.<attr>.inputs.nixpkgs-lock.follows` = load-bearing. Without it closure holds 2 nixpkgs revs.
- cachix: substituter `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`
- env: `CACHIX_AUTH_TOKEN` ! **per-cache token w/ WRITE** on `pr0d1r2`, ⊥ personal token. Wrong scope → 403, push fails, job stays green
- cmd: `nix build .#fakecloud` → `result/bin/fakecloud`
- cmd: `nix run .#fakecloud -- --version` → version string containing `0.44.10` (exact format ! confirmed T4)
- cmd: `nix flake check --all-systems` → exit 0
- ci: `.github/workflows/build.yml` matrix {ubuntu-24.04, ubuntu-24.04-arm, macos-14}
- ci: `.github/workflows/upstream.yml` cron — watch crates.io for new fakecloud, open PR
- ci: `.github/workflows/update-pins.yml` cron — follow nixpkgs-lock bumps

## §V invariants

V1: `nix run .#fakecloud -- --version` → contains `0.44.10`
V2: ∀ sys ∈ tier-1 → `packages.<sys>.fakecloud` evals & builds
V3: `srcHash` & `cargoHash` = real literal sha256. ⊥ `lib.fakeHash` on `main`
V4: `flake.lock` committed. CI runs `nix flake check --all-systems` — bare form silently omits foreign systems ∴ tier-2 rots green
V5: cachix push on `main` push only. PR ⊥ push
V6: consumer w/ substituter configured → fakecloud fetched, ⊥ `building '/nix/store/…fakecloud…drv'` in log
V7: derivation asserts version at install (`versionCheckHook`). mismatch = build fail, ⊥ silent wrong binary
V8: ⊥ IFD, ⊥ `--impure`, ⊥ network in build phase
V9: `doCheck = true`. ∀ skipped test listed in `checkFlags` w/ inline reason & asserted to EXIST in src — `--skip=<gone>` accepted silently
V10: push filter uploads own paths only. ⊥ mirror nixpkgs closure
V11: `flake.nix` inputs ≡ {`nixpkgs-lock`}. ⊥ direct nixpkgs URL, ⊥ 2nd input
V12: nixpkgs rev ≡ nixpkgs-lock rev. CI asserts equality. drift → fail loud, ⊥ silent cache miss
V13: rustc used ≡ rustc ∈ pinned nixpkgs (**1.95.x**). ⊥ rust-overlay, ⊥ fenix, ⊥ `rust-toolchain.toml`. CI asserts exact minor
V14: `buildInputs`/`nativeBuildInputs` ≡ measured need. ∀ entry justified by a build failure without it. ⊥ copied unverified
V15: `main` build → ∀ tier-1 path ∈ cachix, asserted by querying `<hash>.narinfo` ≡ 200 from a **separate job** (`needs: build`). green build ⊥ evidence of populated cache
V16: declared systems ≡ 4. tier-2 `x86_64-darwin` = eval-only, stated in README. ⊥ silent tier-2 claim
V17: ⊥ vendor fakecloud source, ⊥ patch it. upstream fix → upstream PR
V18: this repo's own licence stated in LICENSE + README. ⊥ inferred, ⊥ AGPL by accident
V19: repo public-ready ∀ commit: ⊥ secret, ⊥ token, ⊥ absolute private path, ⊥ unpublishable reference
V20: `services.fakecloud` default `bindAddress = "127.0.0.1"`. fakecloud has ⊥ auth ∴ public bind = open AWS control plane. `0.0.0.0` ! deliberate opt-in
V21: module runs as own unprivileged user + `StateDirectory`. ⊥ root
V22: sub-crates (`fakecloud-*`) ⊥ exported by this flake. consumers reach fakecloud over `:4566` only
V23: build wall-time & closure size recorded per release. regression ≥ 2x → flagged, ⊥ absorbed
V24: upstream version bump opens PR, ⊥ auto-merge. AGPL upstream ∴ licence field re-checked ∀ bump
V25: ∀ claim in §C from upstream marketing (service count, startup ms, binary size) tagged as unmeasured until this repo measures it
V26: upstream test skipped ⟺ inapplicable by construction (needs workspace layout ∉ published tarball). reason inline @ `checkFlags` & `preCheck` greps test name ∃ in src ∴ upstream rename/removal fails loud, ⊥ silently skips nothing. ⊥ skip for flake, slow, or inconvenience

## §T tasks

id|status|task|cites
T1|x|verified: pin `5880666f` has ⊥ `fakecloud` (only `rmfakecloud`). repo needed|G
T2|x|pick source: crates.io tarball vs `fetchFromGitHub` @ tag. confirm real tag name|V3,V8
T3|x|measure minimal build inputs. cargo+rustc alone? record what fails without what|V14
T4|x|confirm `--version` output format & exact string|V1,V7
T5|~|`flake.nix`, `.envrc`, `.gitignore`, `flake.lock` done. left: `pkgs/fakecloud/package.nix`, `README.md`, `LICENSE`|V2,V18
T6|x|resolve real `srcHash`|V3
T7|x|resolve real `cargoHash`|V3
T8|x|`versionCheckHook` + `versionCheckProgramArg`|V1,V7
T9|x|test suite: run upstream tests, list + justify ∀ skip, assert skips exist|V9,V26
T10|x|`devShells` done & verified ∀ 4 sys. left: `packages`, `overlays.default`, `checks` — blocked on T6/T7 hashes|I,V2,V8
T11|x|single input `nixpkgs-lock` + `nixpkgs.follows`, `flake.lock` written & staged|V11
T12|x|measure & record build time, closure size, binary size, startup, idle RSS|V23,V25
T13|x|`nixosModules.default` — `services.fakecloud`, 127.0.0.1 default, own user|V20,V21
T14|~|NixOS VM test: module starts, `:4566` answers, ⊥ reachable off-host by default|V20,V21
T15|.|`.github/workflows/build.yml` 3-runner native matrix|V2,V5
T16|.|cachix: per-cache WRITE token, `main` only, `skipPush` on PR, `pushFilter` own paths|V5,V10
T17|.|`verify-cache` job (`needs: build`) asserting narinfo 200 + signature|V15
T18|.|`nix flake check --all-systems` in CI + eval-only job for x86_64-darwin|V4,V16
T19|.|CI assert nixpkgs rev ≡ nixpkgs-lock rev|V12
T20|.|CI assert pinned rustc ≡ 1.95.x|V13
T21|x|`nixConfig` substituter + pubkey|I
T22|.|README: pin graph, consumer wiring, tier table, `trusted-users` trap, AGPL boundary|V6,V16,V18
T23|.|`upstream.yml` cron — watch crates.io, bump, resolve hashes, open PR, re-check licence|V24
T24|.|`update-pins.yml` cron — follow nixpkgs-lock, build before PR|V12
T25|.|opensource readiness sweep: secrets, paths, LICENSE, CONTRIBUTING, CoC|V19,V18
T26|.|wire `orgmulacra` to consume this flake|I

## §B bugs

id|date|cause|fix
B1|2026-08-22|upstream ships repo-layout lint `no_include_str_escapes_its_crate` INSIDE crates.io tarball. asserts `CARGO_MANIFEST_DIR`/.. ends `crates` & scans sibling crate src ∴ ⊥ passable from tarball (layout ∉ tarball). 103 unit tests ok, this 1 failed → whole build failed. src choice = test-surface choice, ⊥ only a fetch detail|V26
