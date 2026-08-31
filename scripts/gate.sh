#!/bin/sh
# The gate. Its verdict is this script's EXIT CODE plus the summary line it
# prints itself — never a count of green ticks in a runner's output. A check
# that crashes prints no failure line, and counting ticks would hide that
# behind a passing score.
#
# Stages run in order and the gate stops at the first failure, so a later
# stage can never report green over an earlier broken one.
#
# Usage: sh scripts/gate.sh [all|<stage>]
#
# Every check here must be able to fail on demand. Document how to break each
# one deliberately, right next to it, and exercise that before trusting the
# check — a check only ever observed passing is not known to work.
#
# To add a stage:
#   1. Write check_<name>() that prints its own findings and returns 0 or 1.
#   2. Add `run <name> check_<name> \` to the `all)` chain below.
#   3. Add `<name>) run <name> check_<name> || true ;;` as its own case.

set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
what="${1:-all}"
failed=0
ran=0

run() {
  name="$1"; shift
  ran=$((ran + 1))
  printf '\n--- %s ---\n' "$name"
  if "$@"; then
    printf '    ok\n'
  else
    printf '    FAILED\n'
    failed=$((failed + 1))
    return 1
  fi
}

# --- shell ------------------------------------------------------------------
# Every shell script in the overlay must parse. Cheap, dependency-free, and a
# real check: it fails on demand.
# To break deliberately: add an unmatched `fi` to any script in scripts/.
check_shell() {
  found=0
  for f in "$here"/scripts/*.sh; do
    [ -e "$f" ] || continue
    found=1
    sh -n "$f" || return 1
    printf '    parses: %s\n' "$(basename "$f")"
  done
  [ "$found" = 1 ] || printf '    (no shell scripts yet)\n'
  return 0
}

# Add further check_<name>() stages here as the project grows. Two habits are
# worth keeping from the project this gate was carried over from:
#
#   - A stage that finds nothing to check must print SKIPPED and still return
#     0, never pass silently as if it verified something. The distinction
#     matters most for a stage that only runs where some prerequisite exists
#     (a model host, a local build) — CI commonly won't have it.
#
#   - Verify the built artefact, not just the source tree. A check that reads
#     only source can sit green while what actually ships is wrong — that
#     happened twice in the prior project: once with a branding check that
#     never looked at the compiled executable, and again when a direct edit to
#     a Chromium file was silently reverted by the next `apply_patches`,
#     because that file is generated from a Brave-authored patch rather than
#     lived in permanently. Where a Chromium source file is regenerated like
#     that, the durable edit belongs in the .patch (or a Plaster rewrite) that
#     produces it, not in the working tree, and a check should read whichever
#     one actually governs the build.

case "$what" in
  all)
    run shell check_shell || true
    ;;
  shell) run shell check_shell || true ;;
  *) echo "unknown stage: $what" >&2; exit 2 ;;
esac

printf '\n=========================================\n'
if [ "$failed" -gt 0 ]; then
  printf 'GATE FAILED — %d of %d stage(s) failed\n' "$failed" "$ran"
  exit 1
fi
printf 'GATE PASSED — %d stage(s) ok\n' "$ran"
exit 0
