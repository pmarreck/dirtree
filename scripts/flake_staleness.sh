#!/usr/bin/env bash
# Sourceable helper: warn (never block) when the flake's pinned nixpkgs is stale.
#
# Reproducible nix builds pin nixpkgs in flake.lock. If that pin drifts too far
# behind, you build against an aging toolchain/security baseline. We only nudge
# -- auto-updating nixpkgs mid-build would be surprising and could change build
# results unexpectedly.
#
# Usage:  check_flake_staleness [path-to-flake.lock]   (default: ./flake.lock)
# Config: FLAKE_LOCK_STALE_DAYS  threshold in days (default 7; 0 = silent)
#         FLAKE_LOCK_NOW         override "now" as a Unix epoch (for deterministic
#                                tests); falls back to `date +%s` if unset/invalid.
# Output: a multi-line WARNING to stderr if stale; nothing otherwise.
# Returns: always 0 (advisory only).
#
# No Python: lastModified is extracted with jq when available, otherwise a small
# awk/bash fallback. Age math stays in epoch seconds (GNU/BSD `date` agnostic --
# both honor `date +%s`); no formatted-date parsing is needed.

# Extract the nixpkgs pin's `lastModified` epoch from a flake.lock.
# Prefers jq (precise JSON path); falls back to an awk scan scoped to the
# `"nixpkgs": {` node so an input *reference* of the same name can't fool it.
_flake_lock_last_modified() {
  local lock="$1"
  if command -v jq >/dev/null 2>&1; then
    local v
    v=$(jq -r '.nodes.nixpkgs.locked.lastModified // empty' "$lock" 2>/dev/null) || v=""
    if [[ -n "$v" ]]; then
      printf '%s\n' "$v"
      return 0
    fi
  fi
  # Pure-text fallback: enter the nixpkgs node (a key followed by `{`, not a
  # string-valued input ref), then print the first lastModified integer in it.
  awk '
    /"nixpkgs"[[:space:]]*:[[:space:]]*\{/ { innode = 1 }
    innode && /"lastModified"[[:space:]]*:/ {
      if (match($0, /[0-9]+/)) { print substr($0, RSTART, RLENGTH); exit }
    }
  ' "$lock" 2>/dev/null
}

check_flake_staleness() {
  local lock="${1:-flake.lock}"
  local threshold="${FLAKE_LOCK_STALE_DAYS:-7}"
  [[ "$threshold" == "0" ]] && return 0
  [[ -f "$lock" ]] || return 0

  local last_modified
  last_modified=$(_flake_lock_last_modified "$lock")
  [[ "$last_modified" =~ ^[0-9]+$ ]] || return 0

  local now age_days
  now="${FLAKE_LOCK_NOW:-}"
  [[ "$now" =~ ^[0-9]+$ ]] || now=$(date +%s)
  age_days=$(( (now - last_modified) / 86400 ))
  if (( age_days > threshold )); then
    echo "WARNING: flake.lock's pinned nixpkgs is ${age_days} days old (threshold: ${threshold})." >&2
    echo "    Consider refreshing it:  nix flake update" >&2
    echo "    (set FLAKE_LOCK_STALE_DAYS=0 to silence this warning)" >&2
  fi
  return 0
}
