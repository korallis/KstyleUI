# Task: data bar batches 3 and 4: the new readout modules

**Goal**: build batches 3 and 4 of the approved XIV-style data bar. The design is `C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/design.md` (section 3 "Modules for Forever" and the PR 3 and PR 4 rows). Owner decisions: the bar is on for everyone; there is one clock (the minimap's hides while the bar shows one); it is top first and movable; and it has a Forged artwork choice. Batch 1 (the top bar and its zones) is draft PR #512 on branch `korallis/databar-top-bar-zones`, and batch 2 (the ordered list row, #507) is already on staging. **Base your branch on `korallis/databar-top-bar-zones`**, open a PR stacked on it, and rebase onto staging once #512 merges.

**Scope**:
- New readouts in `KstyleUI_DataBars/Readouts.lua`, added to the same VALUES, tooltip and ACTIONS tables, so there is one source system and one look:
  - clock in the centre zone, with calendar pending invites;
  - bag free space;
  - specialization: click switches dual-spec group out of combat if Forever allows it, otherwise it opens talents through the proxy;
  - Hearthstone: cooldown and bind location, click uses it through the item proxy out of combat. **Reuse `KstyleUI_ActionBars/TravelData.lua`** from #508, now on staging;
  - guild online count: hidden with no guild, roster request throttled;
  - friends online count;
  - tracked currencies;
  - gold for every character in the tooltip, stored per character in the account store.
- Defaults per the design table: every module ON except XP. Each module appears in #507's ordered module list with its zone (Left, Centre or Right) and its own child rows.
- Secret values show "--" and are never compared.
- Combat-protected clicks wait out combat with a tooltip note.
- Build lazily, with near-zero reload cost: `test-perf-path-budgets` must stay under 15.7M on top of staging.

**Tests**: each readout's value and tooltip, with secret and missing-API fallbacks; throttles; the module list toggles, zones and order; the clock hand-off with the minimap; renders of the full bar in Frames and Orbs at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, Forged and Plain.

**Constraints**: minimal code; AGENTS.md rules; Forever API cited per readout (`C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`). Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/databar-34/`). Open a **draft** PR with base `korallis/databar-top-bar-zones`, titled `feat(databars): clock, bags, spec, hearth, guild, friends, currencies and gold`, with `## Changelog` (`Added: The data bar shows your spec, Hearthstone, guild and friends online, bag space, currencies and every character's gold, each one switchable and movable between zones.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_DataBars/**`, `KstyleUI_ActionBars/TravelData.lua` (read-only use; edit only to export what you need), `Core/Store.lua` (account gold default only), `KstyleUI_Options/**` (module rows), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the module README.

**Gate**: lint, python and the DataBars tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
