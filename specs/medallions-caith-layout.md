# Task: Medallions centre layout: cooldowns centred, auras in straight rows above the unit frames (CaithUI style)

**Goal**: the owner reviewed the Medallions HUD and wants three changes, for v0.2.7:
1. **The Cooldown Manager (CDM) should be central, not off to the side.** Today the tracked cooldowns (`cooldowns.essential`, `utility` and `buffs`; `Core/Setup/Layouts.lua:191-193` and the Medallions overrides) sit left of centre at 1920x1080.
2. **The auras in a semicircle don't look good.** That is the crest debuff fan (`KstyleUI_UnitFrames/Fan.lua`; the README's "Medallions crest debuffs", element `unitframes.crestDebuffs`).
3. **Auras should look like CaithUI**: the owner's reference video is "CaithUI Classic in ... WOW RETAIL?" (youtube 8WPBCQLa4BA); its thumbnail is saved at `C:/Users/leeba/.cache/kstyleui-evidence/cithui/maxresdefault.jpg`, so look at it. In CaithUI, each unit's auras sit in a **short straight row just above its own unit frame**: the player's above the player frame, left-aligned to the frame; the target's above the target frame, right-aligned to the frame. They are small square icons, with no arc.

**Move the cast bars if needed** to make room.

**Change** (Medallions only; Frames and Orbs unchanged):
- **Your debuffs on the target:** replace the fan with a straight row above the target frame, aligned to the target frame's outer edge as in CaithUI. Keep the fan's aura set (`HARMFUL|PLAYER`), its tile style (KstyleUI chamfered tiles), the timers and the count. Rows wrap upwards if there are more than fit.
- **The player's auras:** a straight row above the player frame, mirrored, if Medallions currently puts them elsewhere.
- **The CDM:** its default sits horizontally centred above the crest and slab, with essential centred, utility centred under or beside it as one centred block, and the tracked buff icons centred too, or in the auras rows if that reads cleaner. Explain which in the PR.
- **Cast bars:** move them only as needed so nothing overlaps; for example, centre them above the CDM block or directly above the crest.
- **Toggleable** (owner rule): add "Aura layout" on the Unit Frames page in Medallions, with "Rows above frames" (the new default) and "Crest fan" (today's look). Existing players get the new default too, unless they had moved `unitframes.crestDebuffs` in Layout Mode. In that case keep the fan and their position, since they chose it.
- **Saved positions** for any element are never moved. Only defaults change.

**Tests**:
- the row layout (left- and right-aligned, wrapping);
- the fan option restores today's look pixel for pixel;
- the CDM default is centred (its centre x equals the screen centre at every aspect);
- the #504 overlap matrix in Medallions for DPS, Tank and Healer at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160, including the consumables bar (#513), the extra-bar presets (#511) and the Medallions data bar dock if it has merged;
- `test-perf-path-budgets` (staging is at about 15.54M against 15.7M, so build lazily).

Before and after renders of the Medallions HUD at the four sizes, with a target that has 5 of your debuffs and the player with buffs, over real game backdrops. Also render the fan option at 1920x1080. Put a side-by-side of before, after and the CaithUI thumbnail in the evidence folder.

**Constraints**: minimal code, reusing the existing aura row builders (unit-frame aura rows and `Widgets.Slot` tiles) and building no new framework. AGENTS.md rules: secret values (never compare aura fields), combat lockdown for secure aura frames, one event handler per owner, CRLF/ASCII, locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/medallions-caith/`). Update `docs/statecharts/` only if a charted flow changes. Open a **draft** PR against `staging` titled `feat(medallions): centred cooldowns and aura rows above the unit frames` with:
- `## Changelog`: `Changed: In Medallions, your cooldowns sit centred above the crest and your target debuffs line up in a row above the target frame. Prefer the old crest fan? Pick it under Aura layout in Options.`
- `## Options`, `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_Cooldowns/**` (only the default placement and the centring), `Core/Setup/Layouts.lua` (defaults only; no new top-level local), `Core/Store.lua` (only a migration if needed; take the next free number), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the module READMEs.

**Gate**: lint, python and the touched tests plus the reach and overlap tests, under PUC Lua 5.1. CI is hosted and fast. Send worker_done once proof is in.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, reload count and render paths, including the side-by-side.
