#!/usr/bin/env bash
# Assert this flake resolves to the same nixpkgs as nixpkgs-lock publishes
# (SPEC V12).
#
# Drift is not cosmetic. Consumers resolve nixpkgs through nixpkgs-lock, so a
# different rev here means different derivation hashes, which means every
# consumer misses the cache and compiles fakecloud from source while everything
# still looks green. Failing the branch is the loud version of that; the silent
# version costs everyone half an hour each.
set -euo pipefail

ours=$(nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev')
theirs=$(nix flake metadata --json github:pr0d1r2/nixpkgs-lock |
  jq -r '.locks.nodes.nixpkgs.locked.rev')

for var in ours theirs; do
  val=${!var}
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    echo "could not read the '$var' nixpkgs rev — flake metadata layout changed?" >&2
    exit 1
  fi
done

if [ "$ours" != "$theirs" ]; then
  cat >&2 <<EOF
nixpkgs pin drift (SPEC V12)

  this flake:   $ours
  nixpkgs-lock: $theirs

Fix with:  nix flake update nixpkgs-lock

update-pins.yml opens that bump automatically; this check exists so the
drift cannot sit unnoticed in the meantime.
EOF
  exit 1
fi

echo "nixpkgs pin matches nixpkgs-lock: $ours"
