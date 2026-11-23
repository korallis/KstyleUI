# KstyleUI handoff (2026-11-23)

Paste this to a fresh coordinator (or read it yourself) to pick KstyleUI back up. Repo: `korallis/KstyleUI`, default branch `staging`, releases tag `main`. Rules of the repo are in `AGENTS.md` (gate, CRLF/ASCII, Forever API proof, conventions). Coordinator scratch (specs, helpers, the running log) lives on branch `handoff/coordinator-state` under `specs/` (it is gitignored on staging; check it out with `git worktree add ../ks-handoff handoff/coordinator-state`).

## State of play

- **Released**: v0.3.2 (2026-11-23) is the latest tag on `main`. v0.3.0, v0.3.1 and v0.3.2 all shipped today. CurseForge/Wago upload automatically from the release workflow; store descriptions and galleries (01-11) are current as of v0.3.1.
- **CI**: staging pushes and releases are gated on GitHub-hosted runners (8 Lua shards, `checks.yml`, PR #758). The three self-hosted Macs only run `mac-budgets.yml`, non-blocking CPU-budget monitoring.
- **Roadmap** (`docs/ROADMAP.md`, mirrored to the Discord roadmap post): v0.3.3 = "polish and the crest for every class". Discord roadmap post updates with `gh workflow run release.yml --ref staging -f roadmap=true -f message_ids=1573443520474120352`.

## Open pull requests (all target staging)

| PR | Branch | What | Status / next step |
| --- | --- | --- | --- |
| #765 | korallis/fix-party-frame-readability | Party frames readable (Larger on ultrawide, readable names/numbers, dark missing health) | Fix round at 7fc7a9e3d: all 11 findings fixed (incl. one-token Core/Scale.lua key); left: adapt test-groupframes-raid-tile:34 and -healer:9 to the new tile ink, parity diff, python gate, tests-first commit order, PR body, hosted CI. Owner note: the 16:9 percent text stays its old size (bigger broke the twelve-letter name contract); fixed by a divider instead. |
| #767 | korallis/platy-2 | Polish batch D: nameplates, action bars, cooldowns, minimap, world map | Review overturned 9 of the author's 17 'not real' dismissals and found drawer/travel regressions, hidden vehicle refresh overhead, a threat/skull collision, a world-map fixture mismatch and an unrelated XP-strip change (report: kstyleui-evidence/verify-767-1dadc386/REPORT.md). Fix round in progress; then spot-check and merge. |
| #768 | korallis/lumpfish-2 | Polish batch C: chat, bags, tooltips, data bars, auras | Green at feab22893; in its one cross-family review (Codex). Then fix round if needed, spot-check, merge. Follow-ups outside its files: audit A#3 (UnitFrames player aura row) and A#9 (bars 3/4 unbound '-' hotkey). |
| #769 | korallis/sander-2 | Polish batch A: meters (swing timer, damage/threat cards) | Fix round at b5d87cd75: findings 1-7 and 9 fixed with regressions; left: rerun 9 hang-guarded tests with fewer jobs, evidence in polish-meters/fix, python gate, hosted CI 45192275768, PR body. Then spot-check and merge. |
| #771 | korallis/healer-crest-trackers | Crest trackers: priest, druid, shaman extension | d4b326c89, stacked on the melee crest branch (2d2f87d1f): registered on SlabTrackers with per-form choices, cooldown families, all research additions, generated art, 21 switches, 4 locales. Left: switch to the shared foot seats, five-second rule and threat emblem when the melee owner pushes them; evidence set; module sweep, python gate, hosted CI; PR body with the 12 in-game checks. |
| #772 | korallis/fix-medallions-unit-frame | Medallions unit frames fitted to the crest (Fitted slabs, heal prediction tint), audit fixes | Fix round at 3c71f0171: findings 1-9 and 11 fixed with regressions; left: raise the spread player cast slot in Core/Setup/Layouts.lua (reach tests fail until then), README/PR body, gates, evidence, CI. Decisions given: both switches stay ON; zero pixel diff with both off; empty steel status sockets always shown; the player cast slot raised 7 units into the gap under the target cast (zero default diffs), or the socket row starts clear of the cast column if the two casts look cramped; one line in `KstyleUI_UnitFrames/Unit.lua` for the heal tint. |

## Work in progress without a PR yet

- **Melee crest trackers + the shared crest system** (branch `korallis/melee-crest-trackers` at bc0c2165c, no PR yet): `KstyleUI_ActionBars/SlabMedals.lua` (Medal, Rim, Socket, CooldownRim, Threat, Plaque, Emblem; seats incl. topGem, hips, footLeft/footRight; counts, pips; focus/pet/target refresh; Engine; Rest/OnRest) and `SlabTrackers.lua` (one lifecycle, `Register(class, rows, hooks)`, per-form choices, known functions, custom build/place, class hooks), docs in `docs/medallions-effects.md`. Warrior, paladin and rogue rows with the research additions and fixes; shared racial and potion rim families; five-second plaque sweep for mana classes; Frames row above the stance bar or Spirit Poles; Options rows and 4 locales. All shared pieces landed at bc0c2165c (topGem, hips, foot seats, counts, pips, Threat, Plaque, Emblem, item feed, auto five-second rule for mana classes, crestTankGlow, shared racial and potion rim families). Test fix and debug print done. Left: the evidence set, python gate, rebase, open the PR; then the ranged and healer PRs rebase onto it. Not done (out of scope or unprovable): rogue energy tick spark (would live in KstyleUI_UnitFrames), trinket rim families (needs in-game check 7), target-cast interrupt flare.
- **Ranged crest trackers** (branch `korallis/ranged-crest-trackers` at 00b8b627c, on the shared seats, soul wisps from bag item 6265 with the exact count above five, shard jewels removed, stacked on the melee branch, no PR yet): hunter, mage and warlock registered on SlabTrackers with per-build, pet-state and level-band choices and all research additions (hunter shot medal, Auto Shot ring, Bestial Wrath pet family, any Sting; mage Counterspell, school hip, Frozen perch; warlock Bane 1014 fix, Curse perch, Conflagrate and weapon-stone jewels, Spell Lock, soul wisps replacing the shard jewels), new art via Tools/media/crest_trackers.py, Options and locales. Left: rebase onto 4711eb6b4 and use its topGem, pips and foot seats; evidence set; perf tests and gate; PR with the nine in-game checks; hosted CI.
- **Polish batch B** (branch `korallis/polish-batch-b-tiny` at 16a3a4114; Options + setup rows): rows done (search heading, Options list fade, General accent bar, UnitFrames preview portrait, Welcome pictures fill their cards, layout card edge, module rows aligned). Left: guard.lua rule that a one-sided fade to alpha 0 never hides text (decided), Options evidence, zero-diff check, gate, rebase onto #764, PR. Follow-up: UnitFrames preview microtype and framing.
- **Polish batch E** (branch `korallis/polish-batch-e-tiny` at 0ddd2d2e9; quest tracker, quest card, RestedXP, spellbook, merchant, talents): PR #773: review found arrow ownership failures, a tracker resize defect, two visible overlaps and a fixture mismatch (kstyleui-evidence/verify-773-0ddd2d2e/REPORT.md); fix round in progress. Decisions: RestedXP boxes become chips when docked; merchant names wrap to two lines at caption size (no ellipsis); shared `Parts.PlaceDock` padding stays.
- **Crest rule set by the owner**: every class tracks everything it needs around the crest (one place to look): crown, shoulders, hips, foot perches, top gem, inner rim, a cooldown rim for every major cooldown and enhancement (racials, trinkets, potions too), every form/stance/spec gets a full crest with no empty seats, tanks and healers included. Research for all specs: `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/complete/{melee,ranged,healers}.md` (local, not in git; summarised in the builder specs on the handoff branch). Hunter stings track any sting; Rapid Fire burns on the rim.

- **Hotfix: RestedXP skin and RestedXP v4.11.39** (`specs/fix-restedxp-4-11-39.md`): the installed RestedXP v4.11.39 fails the skin's entry check, so the RestedXP skin doesn't run at all for players on that version (pre-existing, found in #773's review). Worker building the fix with a v4.11.39 fixture; ship as a hotfix once green.

## Crest completeness: what "maximise the crests for every class" still needs

The owner's rule: every class has everything it needs around the crest, so there is one place to look; every form, stance and spec (damage, tank, healer) gets a full crest with no empty seats; every major cooldown and enhancement (plus racials and potions) burns on a cooldown rim. The full per-spec research is in `specs/crest-research/` (`complete-melee.md`, `complete-ranged.md`, `complete-healers.md`, plus the original design reports, the healer forms plan and the cooldown research). The three builds cover the research's add-to-the-builder lists. What is NOT yet covered, so the job is not finished until these are resolved:

1. **Unverified in game**: 32 checks (11 melee, 9 ranged, 12 healers; section 9/10 of each `complete-*.md`) decide whether several pieces work on the live client (e.g. duration bars on a target aura slot in combat, stack pips, Frozen, PLAYER_SWING Auto Shot, energy ticks, Spell Lock cooldown on a pet spell, weapon-stone enchants, trinket buffs). Anything that fails must be fixed or replaced with a provable route.
2. **Deferred pieces**: rogue and cat energy-tick spark (belongs on the energy bar in `KstyleUI_UnitFrames`, needs its own task after the in-game check); trinket on-use buffs on the cooldown rim (needs in-game check 7); a target-cast interrupt flare (unprovable so far); Riptide only if trainable.
3. **Not possible on Forever** (documented in the research, keep out): rune spells (Avenging Wrath 407788, Readiness, Icy Veins, Pain Suppression, Berserk, Tiger's Fury, Earth/Water Shield, Metamorphosis...), the Holy Power and Soul Shard power types (Soul Shards are bag items, item 6265: the warlock soul wisps count them from the bags), Bloodlust/Heroism, Shamanistic Rage, Tree of Life, Feral Faerie Fire. Hunters, mages and warlocks have no tank or healer specs on Forever.
4. **Evidence and review not done**: none of the three crest PRs has its evidence set, review or merge yet; each must show every class in every form/stance/spec at four sizes in both HUD styles, with 2x polish crops and concept-vs-build sheets, before merge.
5. **Final art**: the builds generate new art (flames, leaves, stones, wisps, gust, ward ring) with `Tools/media` generators; the owner should see the moment GIFs before release and post them in #chat.
6. **Fit check**: once all nine classes are merged, run one pass at native size per class and spec to confirm the crest stays readable with everything lit (no overlapping seats with the cooldown row, cast bar or slabs, especially at 1920x1080 and in Frames).

## After the open work merges

1. v0.3.3 notes PR (pattern: `specs/notes-032.md`), merge, wait for the hosted staging run on that SHA, `git commit-tree <sha>^{tree} -p origin/main -p <sha>`, push main, annotated tag, the release workflow publishes. Then #chat post in the owner's voice, roadmap PR + Discord roadmap update, and refresh the store description (CurseForge authors console textarea 1 on `#/projects/1812141/description`; Wago settings) if the README/store page changed.
2. README/store GIFs for the crest trackers (the owner wants previews posted in #chat for finished visual work; mockups were already posted).

## Follow-ups already identified

- Dropdowns and Options preview panes: make them end visible even if their first fade is lost (same as #764 did for pages), without changing the shared fade's look; and the root cause of the lost first tween (the owner can run the alpha-write trace in `specs/hotfix-setup-blank-welcome.md` history).
- Unit Frames Options preview redesign (tiny text, black disc fixed in batch B).
- Loot-roll window: 14 off-grid regions vs 12 allowed on staging (pre-existing).
- Consumables spacing slider keeps the -1 "HUD default" sentinel (dropping it needs a Store migration).
- Zygor errors seen in the owner's BugGrabber (`ZygorGuidesViewerForever/ActionBar.lua:421` nil arithmetic, ADDON_ACTION_BLOCKED): check whether KstyleUI's Zygor skin causes them.
- Medallions totem fan arc covers the crest spires while open (accepted as transient).
- More languages polished by native speakers (needs people).

## Waiting on the owner (in game)

- v0.3.0 first-run setup pictures; whether the Medallions slab end caps are bold enough; the open totem fan on its forged band.
- Party/raid dispel tint (#756) when in a group.
- The in-game checks listed in each crest research report (11 melee, 9 ranged, 12 healers) and in each PR's "In-game checks".

## How the work was run (Orca + Jev)

Each task is a spec file dispatched with `node C:/Users/leeba/orca-jev-router/orca-route.mjs dispatch --spec-file <spec> --worktree new-child`; one cross-family review per PR (`specs/_rv.sh`: `AVOID=claude rv <PR> <sha> <base> <spec> <evidence>`), an author fix round (`specs/_fixpr.sh`: `fixpr <PR> <review> <spec>`), a spot-check, squash-merge. `done_w <dispatch>` releases a worker and its worktree. `specs/QUEUE.md` is the running log; `specs/_v030-common.md` the shared rules for UI work; `specs/_verify-audit.tmpl` the review template with the "Polish details" checklist (2x crops at 1920x1080 and 5120x1440). Discord posts: `specs/_dpost.sh` / `_dpost2.sh` through Orca's browser tab on #chat. Evidence lives in `C:/Users/leeba/.cache/kstyleui-evidence/` (never committed).

## Owner preferences that shape everything

Minimal code; every change toggleable and on by default; one consistent style; both HUD styles (Medallions default, Frames kept; no Orbs); evidence at 1920x1080, 2560x1440, 5120x1440, 3840x2160; polish is judged by tiny details at native size in game, so believe the game over the harness; perf changes must be pixel-identical; never fight other addons; store pages, README and Discord posts in the owner's own voice; release often (feature releases on the coordinator's call, bug-only batches as hotfixes).
