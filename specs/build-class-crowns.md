# Task: build the class crowns for warrior, priest, shaman, mage, bear druid and hunter

The owner approved (2026-11-21) the crown concepts in `C:/Users/leeba/.cache/kstyleui-evidence/class-crowns/concepts-crowns.png`; research with sources is in `C:/Users/leeba/.cache/kstyleui-evidence/class-crowns/REPORT.md`. They join the rogue crown of blades and cat-druid claws from PR #678 (branch `korallis/animated-class-themed-resource`, shared builder `Core/Widgets/ClassPip.lua`, toggle "Class-themed pips"). Build on #678's branch as a stacked PR (base it on that branch; retarget to `staging` once #678 merges). Paladin and warlock are dropped: do not add them.

| Class | Crown | Source |
| --- | --- | --- |
| Warrior | 5 war-banners | Sunder Armor stacks on the target |
| Priest | 5 candles | Shadow Weaving stacks on the target (Shadow talent; nothing without it) |
| Shaman | 4 elemental spires (fire, earth, water, air) | totem slots, the hawk-perch route (`GetTotemInfo`, `SetAlphaFromBoolean`, duration objects) |
| Mage | 4 arcane shards | Arcane Blast stacks (400573) |
| Druid, Bear Form | 5 talons | Lacerate stacks on the target |
| Hunter | 3 arrows | Sniper Shot's empowered shots; must sit with the Hawk perches without overlap (both on by default) |

- Stacks: never compare secret values in Lua. Use the engine-fed route from the report (CustomAuraContainer `AddAuraSlot` + `SetApplicationBar`, Blizzard_CustomAuraButton.lua:419-431, AuraContainerUtil.lua:68-86) so each piece is a one-point bar fed by the engine, or the safest proven alternative; correct `KstyleUI_Cooldowns/README.md:237` if the report disproves it. Where a class's source is unavailable (no talent, API missing), draw nothing.
- Same crown family and size as the rogue crown (full approved size, the cast bars move to the frames in a separate PR): dormant when empty, ignite on gain, a themed spend/expiry, max lights the ring in the class colour; Motion Full/Calm/Off; no idle OnUpdate; hidden-not-alpha-0. Frames/Orbs use the same art in the class row. Art in `Media/` with provenance, no AI credit lines.
- Each class behind the one "Class-themed pips" toggle (ON by default); off restores today pixel-for-pixel.
- Tests per class: counts, max, spend/expiry, no source = nothing, secret path, Motion Off, toggle off, no events registered for other classes.
- Evidence: GIFs per class (0 -> max -> spend) for Medallions at 1920x1080 and 5120x1440 plus a Frames row, over real backdrops, `--strict`, in `C:/Users/leeba/.cache/kstyleui-evidence/class-crowns/build/`; stills at 2560x1440 and 3840x2160.

Lint, python, UnitFrames and ActionBars tests, `test-perf*`, `test-taint-scan`, `test-perf-path-budgets`, `test-secrets` under PUC Lua 5.1; hosted CI green. PR title `feat(unitframes): class crowns for warrior, priest, shaman, mage, bear druid and hunter`, `Added:` line; list each class's in-game check (the stack source showing in combat). Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_ActionBars/**`, `KstyleUI_Cooldowns/README.md`, `Core/Widgets/ClassPip.lua`, `Core/Tokens.lua` (new tokens only), `Media/**` with provenance, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/medallions-effects.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and GIF paths.
