#!/bin/bash
# Print unRAID releases (stable + latest next) >= MIN_UNRAID that have no kernel package release yet,
# as JSON list of {version, url, sha256}. Already built versions are listed as "Unraid <version>"
# lines in the release notes of the kernel releases.
# Usage: discover-unraid.sh [only this version]
set -euo pipefail

MIN_UNRAID="${MIN_UNRAID:-7.3.2}"
ONLY="${1:-}"
REPO="${GITHUB_REPOSITORY:-RogerSik/unraid-ugreenleds-driver}"

stable="$(curl -sf https://releases.unraid.net/json | jq -c '[.[] | {version, url: (.url | split("?")[0]), sha256}]')"
# next has no list endpoint; the zip sits next to the changelog
next="$(curl -sf "https://releases.unraid.net/os?branch=next&current_version=${MIN_UNRAID}" | jq -c '
  if .changelog // "" | test("^https://next\\.dl\\.unraid\\.net/.*\\.txt$")
  then [{version, url: (.changelog | sub("\\.txt$"; ".zip")), sha256}] else [] end')"

built="$(gh api "repos/${REPO}/releases" --paginate --jq '.[].body' 2>/dev/null | grep -oE '^Unraid [^ ]+' | cut -d' ' -f2 || true)"

jq -cn --argjson s "$stable" --argjson n "$next" '$s + $n | unique_by(.version)' | jq -c '.[]' | while read -r rel; do
  v="$(jq -r .version <<< "$rel")"
  if [ -n "$ONLY" ]; then
    [ "$v" == "$ONLY" ] || continue
  else
    # skip older than MIN_UNRAID (sort -V puts "-beta" after release, good enough for a floor)
    [ "$(printf '%s\n%s\n' "$MIN_UNRAID" "$v" | sort -V | head -1)" == "$MIN_UNRAID" ] || continue
    grep -qx "$v" <<< "$built" && continue
  fi
  echo "$rel"
done | jq -cs .
