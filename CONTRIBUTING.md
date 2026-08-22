# Contributing

Thanks for looking. A few things are worth knowing before you spend effort.

## What belongs here, and what does not

This repository packages [fakecloud](https://github.com/faiscadev/fakecloud).
It does not contain fakecloud's source and does not modify it.

So: **bugs in fakecloud's behaviour belong upstream**, not here. If `s3
CreateBucket` returns the wrong error, that is an upstream issue. What belongs
here is anything about how it is built, packaged, configured or served — a
build failure on some system, a wrong hash, a NixOS module option, a missing
cache entry.

This repository will not carry patches to fakecloud. That is not a style
preference: fakecloud is AGPL-3.0-or-later and this repository is MIT on the
strength of being packaging only. Patching upstream source here would blur
that boundary for everyone downstream. If upstream needs a fix, send it
upstream and we will take the release.

## The spec

`SPEC.md` is the contract: goal, constraints, interfaces, invariants,
task list, and a log of bugs with the invariant each one produced. Behaviour
changes should be argued there first. The invariants are numbered, and commits
and comments cite them by number — if you are wondering why something is
written the way it is, the citation is the answer.

Some of them will look paranoid. Each one is there because something failed
quietly once.

## Working on it

```console
$ direnv allow      # or: nix develop
```

That gives you the pinned toolchain — the same versions CI uses. Before
opening a PR:

```console
$ nixfmt .
$ statix check
$ nix flake check --all-systems
$ shellcheck .github/scripts/*.sh
$ actionlint
```

`--all-systems` is not optional. The bare form silently skips systems your
machine cannot evaluate, which is how a broken `x86_64-darwin` stays green.

The NixOS VM test needs KVM, so it cannot run on macOS. CI runs it on the
x86_64 Linux job.

## Hashes

Do not hand-edit `srcHash` or `cargoHash`. Use `nix-update`, which is in the
devShell:

```console
$ nix-update --flake --version <version> fakecloud
```

A wrong hash either fails loudly or, worse, points at something you did not
intend to build.

## Commits

One logical change per commit, and say **why** in the body. The what is in the
diff already. If a change exists because something broke, name what broke —
that is the part nobody can reconstruct later.

Version bumps are usually opened automatically by the cron in
`.github/workflows/upstream.yml`. They are never merged automatically: a bump
is a moment to re-read upstream's changelog and re-check the licence.
