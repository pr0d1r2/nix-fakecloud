#!/usr/bin/env bash
# Watch crates.io for a new fakecloud release and, if there is one, bump the
# package in place so a PR can be opened from the result (SPEC T23, V24).
#
# Two things this deliberately does NOT do: merge anything, and trust the
# licence to have stayed put. fakecloud is AGPL-3.0-or-later, this repo is
# packaging-only on that basis, and a licence change upstream is a decision for
# a human, not for a cron job.
set -euo pipefail

pkg=pkgs/fakecloud/package.nix
api="https://crates.io/api/v1/crates/fakecloud"
ua="nix-fakecloud packaging bot (https://github.com/pr0d1r2/nix-fakecloud)"

current=$(grep -oE 'version = "[0-9]+\.[0-9]+\.[0-9]+"' "$pkg" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
meta=$(curl -sS --max-time 30 -H "User-Agent: $ua" "$api")

latest=$(printf '%s' "$meta" | jq -r '.crate.max_version')
license=$(printf '%s' "$meta" | jq -r --arg v "$latest" '.versions[] | select(.num == $v) | .license')
yanked=$(printf '%s' "$meta" | jq -r --arg v "$latest" '.versions[] | select(.num == $v) | .yanked')

echo "packaged: $current"
echo "upstream: $latest (license: $license, yanked: $yanked)"

if [ "$yanked" = "true" ]; then
  echo "upstream's newest version is yanked — nothing to do" >&2
  exit 0
fi

if [ "$current" = "$latest" ]; then
  echo "already current"
  exit 0
fi

# SPEC V24: re-check the licence on every bump. This repo's MIT licence and its
# whole no-vendoring, no-patching posture rest on fakecloud being AGPL; if that
# changed, the packaging decisions need revisiting before the version does.
if [ "$license" != "AGPL-3.0-or-later" ]; then
  cat >&2 <<EOF
upstream licence changed: expected AGPL-3.0-or-later, crates.io reports "$license"

Not bumping. This repository's licence boundary is built on the old value —
re-read LICENSE, README and SPEC's licence boundary before taking $latest.
EOF
  exit 1
fi

echo "bumping $current -> $latest"
nix-update --flake --version "$latest" fakecloud

# nix-update rewrites the hashes; prove the result actually builds before a PR
# claims it does.
nix build .#fakecloud --print-build-logs
./result/bin/fakecloud --version | grep -q "$latest"

{
  echo "version=$latest"
  echo "previous=$current"
  echo "bumped=true"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
