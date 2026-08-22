#!/usr/bin/env bash
# Assert that everything CI just built is actually IN the binary cache, and
# signed (SPEC V15).
#
# This exists because a green build job proves nothing about the cache.
# cachix-action no-ops on an empty token and logs a 403 without failing, so the
# only trustworthy evidence is asking the cache itself, from a job that runs
# after the push step has finished. Asserting this inside the build job races
# cachix-action's own post-run hook and can pass before anything was uploaded
# (../nix-hk B3-B5).
set -euo pipefail

dir=${1:?usage: verify-cache.sh <dir-of-store-path-artifacts>}
cache=${CACHIX_CACHE:-pr0d1r2}

status=0
found=0

while IFS= read -r path; do
  [ -n "$path" ] || continue
  found=$((found + 1))

  # /nix/store/<hash>-name -> <hash>
  hash=${path#/nix/store/}
  hash=${hash%%-*}
  url="https://${cache}.cachix.org/${hash}.narinfo"

  narinfo=$(curl -sS --max-time 30 -w '\n%{http_code}' "$url" || true)
  code=${narinfo##*$'\n'}
  body=${narinfo%$'\n'*}

  if [ "$code" != "200" ]; then
    echo "MISSING $path"
    echo "  $url returned $code — the build was green but nothing reached the cache."
    status=1
    continue
  fi

  if ! printf '%s\n' "$body" | grep -q '^Sig: '; then
    echo "UNSIGNED $path"
    echo "  narinfo has no Sig: line, so consumers will not trust it."
    status=1
    continue
  fi

  echo "OK $path"
done < <(cat "$dir"/*/store-path.txt)

if [ "$found" -eq 0 ]; then
  echo "no store paths to check — the build jobs published no artifacts, which is itself a failure" >&2
  exit 1
fi

echo "checked $found path(s) against ${cache}.cachix.org"
exit "$status"
