#!/usr/bin/env bash
# Sourceable helper: warn (never block) when the flake's pinned nixpkgs is stale.
#
# Reproducible nix builds pin nixpkgs in flake.lock. If that pin drifts too far
# behind, you build against an aging toolchain/security baseline. We only nudge
# -- auto-updating nixpkgs mid-build would be surprising and could change build
# results unexpectedly.
#
# Usage:  check_flake_staleness [path-to-flake.lock]   (default: ./flake.lock)
# Config: DIRTREE_FLAKE_STALE_DAYS  threshold in days (default 7; 0 = silent)
# Output: a multi-line WARNING to stderr if stale; nothing otherwise.
# Returns: always 0 (advisory only).
check_flake_staleness() {
  local lock="${1:-flake.lock}"
  local threshold="${DIRTREE_FLAKE_STALE_DAYS:-7}"
  [[ "$threshold" == "0" ]] && return 0
  [[ -f "$lock" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  local last_modified
  last_modified=$(FLAKE_LOCK_PATH="$lock" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    with open(os.environ["FLAKE_LOCK_PATH"]) as f:
        lock = json.load(f)
    node = lock.get("nodes", {}).get("nixpkgs", {})
    print(node.get("locked", {}).get("lastModified", ""))
except Exception:
    pass
PY
)
  [[ "$last_modified" =~ ^[0-9]+$ ]] || return 0

  local now age_days
  now=$(date +%s)
  age_days=$(( (now - last_modified) / 86400 ))
  if (( age_days > threshold )); then
    echo "WARNING: flake.lock's pinned nixpkgs is ${age_days} days old (threshold: ${threshold})." >&2
    echo "    Consider refreshing it:  nix flake update" >&2
    echo "    (set DIRTREE_FLAKE_STALE_DAYS=0 to silence this warning)" >&2
  fi
  return 0
}
