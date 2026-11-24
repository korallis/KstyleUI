# KstyleUI handoff (2026-11-23)

Paste this to a fresh coordinator (or read it yourself) to pick KstyleUI back up. Repo: `korallis/KstyleUI`, default branch `staging`, releases tag `main`. Rules of the repo are in `AGENTS.md` (gate, CRLF/ASCII, Forever API proof, conventions). Coordinator scratch (specs, helpers, the running log) lives on branch `handoff/coordinator-state` under `specs/` (it is gitignored on staging; check it out with `git worktree add ../ks-handoff handoff/coordinator-state`).

## State of play

- **Released**: v0.3.4.2 hotfix on v0.3.4 (2026-11-23, the crest for every class + Baine's map fixes #784) is the latest tag on `main`; v0.3.3 and hotfix v0.3.3.1 shipped the same day. Posted in #chat with one crest GIF per class. CurseForge/Wago upload automatically from the release workflow; README did not change in v0.3.4, so store descriptions and galleries (01-11) are still current as of v0.3.1.
- **Baine (Discord)**: missing world map art (only parchment and pins after the zone dance) is unexplained; waiting on his answers (Reveal on? /reload or zone switch fixes it? world map skin off? Questie off?). His minimap double party dot is not KstyleUI (the client draws party blips; KstyleUI never touches them); asked him to test with only KstyleUI on and `/fstack` each dot.
- **CI**: staging pushes and releases are gated on GitHub-hosted runners (8 Lua shards, `checks.yml`, PR #758). The three self-hosted Macs only run `mac-budgets.yml`, non-blocking CPU-budget monitoring.
- **Roadmap** (`docs/ROADMAP.md`, mirrored to the Discord roadmap post): v0.3.5 = "the crest, tuned in game" (in-game check fixes, trinkets on the rim, energy tick spark, readable expiring aura timers; #787). Discord roadmap post updates with `gh workflow run release.yml --ref staging -f roadmap=true -f message_ids=1573443520474120352`.

## Merged since v0.3.2 (for the v0.3.3 notes)

- #765 party frames readable (larger on ultrawide, readable names and numbers, dark missing health, offline members show empty tracks, crown on the rim). Owner decided (A): the 16:9 percent text keeps its size so names keep 12 letters; readability comes from the divider and backing.
- #767 polish batch D (keybinds on the icon art, autocast dots, vehicle button socket, travel menu on top, minimap plaque and drawer, threat mark, world map stand-in matches the game).
- #772 Medallions unit frames fitted to the crest (Fitted slabs: arms under the ring, even insets, power in its colour, status sockets on the slab with steel rivets for empty player slots, raid marker on the portrait rim; heal prediction in the bar's colour; aura stacks inside the corner; boss and focus cast tracks).
- #773 polish batch E (quest tracker counts and chevron, quest card, RestedXP configurator, arrow text yields to the zone banner, RestedXP boxes as chips, spellbook tabs, merchant names). Its RestedXP parts only show once the v4.11.39 hotfix lands.
- #774 polish batch B (Options list fade, one search heading, preview paints its own portrait so the live level-up burst stays put, Welcome pictures fill their cards, setup card accent edge, module rows aligned in every locale, guard exempts only a scroll view's bottom fade).
- #768 polish batch C (chat edit box inside its glass, bag cooldown numbers, compare tooltip tab, data bars aligned with a new Match the other bars switch for honour, aura samples in order).
- #775 RestedXP skin works with RestedXP 4.11.39 (renamed API and rebuilt boxes; perf ceiling UpdateSubTheme = 29 beside UpdateVisuals).
- #777 polish batch F (minimap buttons inside the ring, drawer and zoom slider, tracked-bar counts, proc glow width and ShowProc resting at alpha 1). Owner decided A: the tracked-buff row keeps its fixed slot above an empty utility row (no shifting mid-fight).
- #769 meters polish (swing timer stays full, readable damage meter rows with tracks, finished empty cards).

## Crests merged so far

- #776 (ae54bdb0f): warrior, paladin and rogue crest trackers plus the shared crest system (SlabMedals, SlabTrackers Register API, docs/medallions-effects.md). Ships in v0.3.4 with the healer and ranged crests.
- #778: hunter, mage and warlock crest trackers (Soul Shards from bags, old shard jewels removed).
- #771: priest, druid (full crest per form incl. bear tank) and shaman extension. All nine classes are now on staging for v0.3.4.

## Open pull requests (all target staging)

| PR | Branch | What | Status / next step |
| --- | --- | --- | --- |

## Work in progress without a PR yet

- **Crest rule set by the owner**: every class tracks everything it needs around the crest (one place to look): crown, shoulders, hips, foot perches, top gem, inner rim, a cooldown rim for every major cooldown and enhancement (racials, trinkets, potions too), every form/stance/spec gets a full crest with no empty seats, tanks and healers included. Research for all specs: `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/complete/{melee,ranged,healers}.md` (local, not in git; summarised in the builder specs on the handoff branch). Hunter stings track any sting; Rapid Fire burns on the rim.

- v0.3.4.1 (2026-11-24, #788 party defensive indicators) and v0.3.4.2 (2026-11-24: #789 world map opens without its fade so the terrain art stays, #791 setup nil-rect error, #792 setup scroll lists call UpdateScrollChildRect) released; all credit Baine, who confirmed the map fix in game. Setup/Options glass stays 75% (owner decided: keep as is).
- Baine still to check: the minimap double party dot when next in a group (KstyleUI draws no party blips).
- Otherwise nothing in flight: no workers running. Next is v0.3.5 (see the roadmap line above and the crest completeness list below). Still ask Baine to confirm the Medallions card title on his German client.

## Crest completeness: what "maximise the crests for every class" still needs

The owner's rule: every class has everything it needs around the crest, so there is one place to look; every form, stance and spec (damage, tank, healer) gets a full crest with no empty seats; every major cooldown and enhancement (plus racials and potions) burns on a cooldown rim. The full per-spec research is in `specs/crest-research/` (`complete-melee.md`, `complete-ranged.md`, `complete-healers.md`, plus the original design reports, the healer forms plan and the cooldown research). The three builds cover the research's add-to-the-builder lists. What is NOT yet covered, so the job is not finished until these are resolved:

1. **Unverified in game**: 32 checks (11 melee, 9 ranged, 12 healers; section 9/10 of each `complete-*.md`) decide whether several pieces work on the live client (e.g. duration bars on a target aura slot in combat, stack pips, Frozen, PLAYER_SWING Auto Shot, energy ticks, Spell Lock cooldown on a pet spell, weapon-stone enchants, trinket buffs). Anything that fails must be fixed or replaced with a provable route.
2. **Deferred pieces**: rogue and cat energy-tick spark (belongs on the energy bar in `KstyleUI_UnitFrames`, needs its own task after the in-game check); trinket on-use buffs on the cooldown rim (needs in-game check 7); a target-cast interrupt flare (unprovable so far); Riptide only if trainable.
3. **Not possible on Forever** (documented in the research, keep out): rune spells (Avenging Wrath 407788, Readiness, Icy Veins, Pain Suppression, Berserk, Tiger's Fury, Earth/Water Shield, Metamorphosis...), the Holy Power and Soul Shard power types (Soul Shards are bag items, item 6265: the warlock soul wisps count them from the bags), Bloodlust/Heroism, Shamanistic Rage, Tree of Life, Feral Faerie Fire. Hunters, mages and warlocks have no tank or healer specs on Forever.
4. **Merged and released** in v0.3.4 (#776, #778, #771, #785) after evidence and one cross-family review each.
5. **Final art**: the builds generate new art (flames, leaves, stones, wisps, gust, ward ring) with `Tools/media` generators; the owner should see the moment GIFs before release and post them in #chat.
6. **Fit check**: once all nine classes are merged, run one pass at native size per class and spec to confirm the crest stays readable with everything lit (no overlapping seats with the cooldown row, cast bar or slabs, especially at 1920x1080 and in Frames).

## After the open work merges

1. Release recipe (last used for v0.3.4): notes PR (pattern: `specs/notes-034.md`), merge, wait for the hosted staging run on that SHA, `git commit-tree <sha>^{tree} -p origin/main -p <sha>`, push main, annotated tag, the release workflow publishes. Then #chat post in the owner's voice, roadmap PR + Discord roadmap update, and refresh the store description (CurseForge authors console textarea 1 on `#/projects/1812141/description`; Wago settings) if the README/store page changed.
2. README/store GIFs for the crest trackers (the owner wants previews posted in #chat for finished visual work; mockups were already posted).

## Follow-ups already identified

- Dropdowns and Options preview panes: make them end visible even if their first fade is lost (same as #764 did for pages), without changing the shared fade's look; and the root cause of the lost first tween (the owner can run the alpha-write trace in `specs/hotfix-setup-blank-welcome.md` history).
- Unit Frames Options preview redesign: the specimen is width-bound (about 6 px text at 1080); readable text needs the preview pane about 400 units wide instead of 280, a window layout change (the black disc is fixed in batch B).
- RestedXP 4.11.39 Guide Configurator rows: RestedXP's 40-unit icon covers the skin's full-width tile hairlines by 3 units (pre-existing). Recommended fix: start the skin's tile 22 units in, where RestedXP starts its own background, so the icon reads as a badge (Chrome.lua Option).
- Crest follow-ups: an equipped-trinket cooldown-rim family (after in-game check 7) and a Dark/Demonic Rune consumable kind.
- Expiring aura timers turn a low-contrast red over scenery: needs Core Duration.ExpiringColor (audit C35).
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
