# Brave overlay

A fresh start. This repository holds everything that is ours — brave-core
holds everything that is Brave's — and nothing here is edited in place inside
a brave-core checkout. That split exists for three reasons: `git clean` in
brave-core must never be able to destroy work, rebasing onto a newer Chromium
should not have to fight our own changes, and MPL-2.0 is file-level copyleft.

Nothing project-specific is carried over from prior work. What's here is two
scripts and the pattern behind them.

```
scripts/gate.sh             The gate. Exit code plus its own summary line is
                             the verdict — never a count of green ticks.
scripts/install-overlay.sh  Junctions this overlay into a brave-core checkout.
```

## The gate

```sh
sh scripts/gate.sh all      # or: shell
```

One stage exists so far — every shell script in `scripts/` must parse. Add a
stage by writing a `check_<name>()` that prints its own findings and returns
0/1, wiring it into the `all)` chain, and giving it its own case. Document how
to break each stage deliberately, right next to it, and exercise that before
trusting it: a check only ever observed passing is not known to work.

`.github/workflows/gate.yml` runs `sh scripts/gate.sh all` on every pull
request and on pushes to `main`. The job passes or fails on the gate's own
exit code — CI adds nothing to the verdict, it just runs it somewhere that
isn't a laptop.

Two habits worth keeping as this grows:

- A stage that finds nothing to check must print `SKIPPED` and still return 0
  — never pass silently as if it verified something.
- Verify what actually ships, not just what the source tree says. A check
  that stops at source can sit green while the built artefact is wrong.

## The overlay

```sh
sh scripts/install-overlay.sh [path-to-brave-core]     # default: D:/brave/src/brave
```

Links entries from `LINKS` in the script into the brave-core checkout via
Windows directory junctions — no admin rights or developer mode needed, one
copy of every asset, no drift between the two. Currently empty; add entries as
real assets accumulate. Safe to re-run; refuses to overwrite a real directory.

One case a junction can't cover: a Chromium file Brave itself regenerates from
an authored `.patch` on every `apply_patches` run. Editing that file directly,
or junctioning something over it, gets silently discarded on the next build.
The durable edit there belongs in the `.patch` (or a Plaster rewrite under
brave-core's own `rewrite/`) that produces it — worth remembering before it
costs a rebuild to rediscover.
