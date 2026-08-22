#!/usr/bin/env bash
# Assert fakecloud is built with the rustc from the pinned nixpkgs (SPEC V13).
#
# Read from the derivation itself rather than from a separate `nix eval` of
# `rustc.version`: the question is not "what version does nixpkgs have", it is
# "what version is this build actually going to use". Those differ the moment
# anyone adds an overlay.
set -euo pipefail

system=${1:?usage: assert-rustc.sh <system>}
expected="1.95"

drv=$(nix eval --raw ".#packages.${system}.fakecloud.drvPath")
refs=$(nix-store --query --references "$drv")

rustc=$(printf '%s\n' "$refs" | grep -oE 'rustc(-wrapper)?-[0-9]+\.[0-9]+\.[0-9]+' | head -1)
cargo=$(printf '%s\n' "$refs" | grep -oE '(^|/)[a-z0-9]{32}-cargo-[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$rustc" ] || [ -z "$cargo" ]; then
  echo "could not find rustc/cargo among the derivation's inputs — did the" >&2
  echo "rustPlatform layout change? refs were:" >&2
  printf '%s\n' "$refs" >&2
  exit 1
fi

rustc_version=${rustc##*-}
cargo_version=${cargo##*-}

status=0
for pair in "rustc:$rustc_version" "cargo:$cargo_version"; do
  tool=${pair%%:*}
  version=${pair#*:}
  case "$version" in
    "${expected}."*) echo "$tool $version" ;;
    *)
      echo "$tool version drift (SPEC V13): got $version, expected ${expected}.x" >&2
      status=1
      ;;
  esac
done

# The other half of V13: there must be no second place a Rust version can come
# from. A rust-toolchain file would silently win over the pin for anyone
# running cargo directly in this tree.
for stray in rust-toolchain rust-toolchain.toml; do
  if [ -e "$stray" ]; then
    echo "$stray exists — the toolchain must come from the pin alone (SPEC V13)" >&2
    status=1
  fi
done

exit "$status"
