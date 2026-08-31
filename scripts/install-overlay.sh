#!/bin/sh
# Places this overlay into a brave-core checkout.
#
# This repository is the single source of truth for everything that is ours
# rather than Brave's. The brave-core tree is Brave's, and nothing of ours is
# edited there — a `git clean` in that tree must never be able to destroy work.
#
# One exception is unavoidable: a Chromium source file that Brave itself
# regenerates from an authored .patch on every `apply_patches` run cannot be
# fixed by junctioning something over it — apply_patches would just overwrite
# the junction's target file inside brave-core on the next build. For a file
# like that, the durable edit belongs in the .patch (or a Plaster rewrite
# under brave-core's own rewrite/ tree) that produces it, kept in this overlay
# only as a copy/reference, and applied by a small script here rather than by
# junction. Confirm which situation you're in — a one-time direct edit to a
# file nothing regenerates is fine to junction or edit in place; a generated
# file is not — before adding either kind of entry below.
#
# Uses a Windows directory junction rather than a copy, so there is exactly one
# copy of every asset and no chance of the two drifting. A junction needs no
# administrator rights and no developer mode, unlike a symlink.
#
# Usage: sh scripts/install-overlay.sh [path-to-brave-core]
#        default: D:/brave/src/brave
#
# Safe to re-run. Refuses to clobber a real directory.

set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
core="${1:-D:/brave/src/brave}"

[ -d "$core" ] || { echo "FAIL: brave-core not found at $core"; exit 2; }

# One line per link: <path in this overlay>|<path inside brave-core>.
#
# Empty by design — this is a fresh start. Add entries as the project grows
# real assets to place, e.g.:
#   theme/mybrand|app/theme/mybrand
LINKS="
"

link_one() {
  rel_src="$1"; rel_dst="$2"
  src="$here/$rel_src"
  dst="$core/$rel_dst"
  win_src="$(cygpath -w "$src" 2>/dev/null || echo "$src")"
  win_dst="$(cygpath -w "$dst" 2>/dev/null || echo "$dst")"

  if [ -e "$dst" ]; then
    # A junction reports as an ordinary directory to most tools, so query the
    # reparse point directly. `dir /al` is NOT reliable here.
    if fsutil reparsepoint query "$win_dst" >/dev/null 2>&1; then
      echo "  already linked: $rel_dst"
      return 0
    fi
    echo "FAIL: $dst exists and is a real directory, not a junction."
    echo "      Refusing to clobber it. Move or delete it first, then re-run."
    return 1
  fi

  mkdir -p "$(dirname "$dst")"
  cmd //c mklink //J "$win_dst" "$win_src" >/dev/null
  echo "  linked $rel_dst -> $rel_src"
}

if [ -z "$(printf '%s' "$LINKS" | tr -d '[:space:]')" ]; then
  echo "(LINKS is empty — nothing to link yet. Add entries above as the"
  echo " overlay grows, then extend this script with a verification step —"
  echo " e.g. read one known file back through the link and check its"
  echo " content, not just that mklink reported success — the way an earlier"
  echo " version of this script proved a BRANDING file was reachable through"
  echo " the junction rather than trusting mklink's exit code alone.)"
else
  echo "$LINKS" | while IFS='|' read -r rel_src rel_dst; do
    [ -n "$rel_src" ] || continue
    link_one "$rel_src" "$rel_dst" || exit 1
  done
fi
