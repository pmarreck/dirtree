#!/usr/bin/env bash
# Regenerate the embedded Nerd Font subset used by the HTML output adapter.
#
# Reads the icon codepoints from src/icons.zig, subsets the MIT-licensed
# Symbols Nerd Font (Mono) to ONLY those glyphs, compresses to woff2, and
# writes src/assets/symbols-nerd-font-subset.woff2. That asset is committed and
# @embedFile'd by src/html_font.zig (base64 at comptime) — so the build needs no
# font tooling and stays reproducible. Re-run this whenever src/icons.zig gains
# or drops glyphs.
#
# Tools (harfbuzz hb-subset, woff2_compress) and the font come from nixpkgs, so
# no system install is required. Deterministic: same icons.zig -> same woff2.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICONS="$ROOT/src/icons.zig"
OUT="$ROOT/src/assets/symbols-nerd-font-subset.woff2"

# Distinct icon codepoints, as a comma-separated U+XXXX list for hb-subset.
UNICODES="$(grep -oE '\\u\{[0-9a-fA-F]+\}' "$ICONS" \
  | sed -E 's/\\u\{([0-9a-fA-F]+)\}/U+\1/' | sort -u | paste -sd, -)"
if [[ -z "$UNICODES" ]]; then echo "no codepoints found in $ICONS" >&2; exit 1; fi
echo "Subsetting $(printf '%s' "$UNICODES" | tr ',' '\n' | wc -l | tr -d ' ') glyphs..."

# Resolve the font package path outside the build shell (robust vs. store-scan).
FONT_OUT="$(nix build --no-link --print-out-paths 'nixpkgs#nerd-fonts.symbols-only' 2>/dev/null | head -1)"
FONT="$(find "$FONT_OUT" -name 'SymbolsNerdFontMono-Regular.ttf' 2>/dev/null | head -1)"
if [[ -z "$FONT" ]]; then echo "Symbols Nerd Font (Mono) not found under $FONT_OUT" >&2; exit 1; fi
echo "Font: $FONT"

FONT="$FONT" UNICODES="$UNICODES" OUT="$OUT" \
  nix shell 'nixpkgs#harfbuzz.dev' 'nixpkgs#woff2' -c bash -s <<'SUBSET'
set -e
tmp="$(mktemp -d)"
hb-subset --unicodes="$UNICODES" --output-file="$tmp/sub.ttf" "$FONT"
woff2_compress "$tmp/sub.ttf" >/dev/null
cp "$tmp/sub.woff2" "$OUT"
rm -rf "$tmp"
SUBSET
rc=$?
if [[ $rc -ne 0 ]]; then echo "subset failed" >&2; exit $rc; fi
echo "Wrote $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
