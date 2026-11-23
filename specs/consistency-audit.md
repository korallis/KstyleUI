# Task: consistency audit: one bar, one font set, one card across the whole UI (read-only)

**Goal**: the owner's core rule: "Your whole interface, forged as one piece in one consistent style." Example: the damage and threat meter bars should have the same height and texture as the nameplate bars, and the same fonts. Find every place where elements of the same kind look different, so they can be unified on shared tokens and builders.

**Target**: KstyleUI on latest `origin/staging` (all `Core/` and `KstyleUI_*` modules), `Core/Tokens.lua`, `Core/Widgets/**`, and the render harness (`Tools/render/`, scenes listed in `docs/feature-map.md`).

**Change** (investigation, no code changes):
1. Inventory each element kind and every variant in use, with file:line and the actual values:
   - **Status bars**: health, power, cast, threat, damage meter, XP/reputation, swing, group frames, nameplates. Record the height per style, the texture, the background, the border/rim, the spark and the fill colours.
   - **Text**: name, number, label and heading. Record the face, size per screen scale, the outline/shadow, and number formatting (k/M, %, decimals).
   - **Cards and windows**: frame chrome, header cap, padding, spacing and corner treatment.
   - **Icons**: aura, cooldown and action-button icons. Record the size, border, timer text and stack text.
   - **Rows and lists**: meter, quest, bags, options and trainer rows. Record the row height, hover and selection.
2. For each kind, list the variants. Mark which differences are deliberate owner rulings (Medallions one action row; meter bars keep class colour; class-coloured health; red/blue Orbs; HUD style differences between Frames, Orbs and Medallions). Mark the rest as inconsistencies.
3. Propose the smallest unification: one token or builder per kind. Say which existing value should win (prefer what the most-seen element uses, such as the nameplates for bars) and which call sites change. Give an estimate in lines changed, grouped into PR-sized batches with disjoint files.
4. Back it with real pictures. Make side-by-side crops of the main inconsistencies from the render harness at 1920x1080 and 3840x2160 over a real backdrop (`--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_NN.png`), at most 2 renders at a time.

**Constraints**: read-only; change no code. Cite file:line for every value. Be fast and concrete: tables, not prose.

**Evidence of done**: a report at `%TEMP%\orca-<dispatch>\consistency-audit.md` with the inventory tables, the inconsistency list, the proposed batches, and the crop paths.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`.
