# KstyleUI Roadmap

> **For agentic workers:** This roadmap is not executed directly. Each phase has its own detailed plan in `docs/superpowers/plans/`. Execute a phase plan with superpowers:subagent-driven-development or superpowers:executing-plans. Read this roadmap first for the shared interfaces every phase uses.

**Goal:** Build the full KstyleUI suite for WoW Forever in five phases, each ending in a state the owner can test in game.

**Architecture:** One core addon at the repository root holds the design system and every shared service. Each module is a `KstyleUI_<Module>` addon that depends on the core and talks only to the core's public API, `_G.KstyleUI`. Modules in the same phase are independent and are built in parallel worktrees.

**Tech Stack:** Lua 5.1 (WoW client), XML load files, Python 3.12 for tooling, luacheck 1.2.0, pre-commit 4.x, LuaJIT locally and Lua 5.1 in CI, the BigWigs packager, Higgsfield `gpt_image_2_5` for generated art.

**Spec:** [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](../specs/2026-11-07-kstyleui-design.md)

## Global Constraints

These apply to every task in every phase:

- Every TOC: `## Interface: 16001`, `## AllowLoadGameType: camelot`, `## Group: KstyleUI`. Module TOCs add `## Dependencies: KstyleUI` and list only the module's XML file.
- Lua 5.1 only: no `goto`, no labels, no `//`.
- `.lua`, `.toc` and `.xml` files outside `Tools/` and `docs/` are ASCII only with CRLF line endings. Run `python3 Tools/dev/crlf.py` before committing.
- One comment per file, its first line: `-- <File>.lua: <what it is>.`
- No hex or RGB colour literal outside `Core/Tokens.lua`.
- No module code runs until its `Enable` is called. Code defaults leave every module off.
- Secret values (health, power, casts of other units, aura data under restriction) pass only to widget setters, `AbbreviateNumbers`, `UnitHealthPercent` and curves. Never compare them, do arithmetic on them, test them as booleans, index with them or take their length.
- No `COMBAT_LOG_EVENT_UNFILTERED`, no `CombatLogGetCurrentEventInfo`.
- No `SetScript` on a Blizzard frame, no field writes onto a Blizzard frame, no `Hide()` on a Blizzard layout frame. Hide Blizzard frames only through `KstyleUI.Safe.HideBlizzard`.
- Protected work in combat goes through `KstyleUI.Combat.Queue`.
- Nothing copied from another addon. Every generated asset gets a row in `Media/PROVENANCE.md`.
- Branch `<type>/<scope>-<slug>` from `origin/staging`, in its own worktree under `~/KstyleUI.worktrees/`. PR into `staging`, one coherent piece of work with no line limit (waived by the owner on 2026-11-07), title `type(scope): summary`, body with a `## Changelog` line (`Added:`, `Changed:` or `Fixed:`) or the `no changelog` label.
- Before opening a PR: `pre-commit run --all-files`, `LUA=luajit bash Tools/regression/run-all.sh`, `python3 -m unittest discover -s Tools/tests`, then `/codex:review`. KstyleUI does not use CodeRabbit; the owner removed it on 2026-11-07.

## Review Focus

These failure modes are implied by the spec but easy to miss. Each one has an owning task whose tests must pin it.

1. **The player logs in on a different class.** The accent must change to the new class colour on `PLAYER_LOGIN` without a reload, in every open window. Owner: Phase 1, `Theme`.
2. **The game window moves to a monitor with a different resolution.** `DISPLAY_SIZE_CHANGED` must rescale the root and redraw every border as whole physical pixels. Owner: Phase 1, `Scale`.
3. **Combat starts while Layout Mode or the settings window is open.** Layout Mode must exit and restore saved positions, and no protected call may fire (`ADDON_ACTION_BLOCKED` must not appear). Owner: Phase 1, `Layout` and `Combat`.
4. **The player switches to gamepad mode.** No module may error or taint `Blizzard_GamepadActionBars`. Owner: Phase 2, `KstyleUI_ActionBars`, and the taint scan.
5. **A pasted profile string is truncated, from another addon, or hostile.** Import must reject it before applying anything and say why. Owner: Phase 1, `Store`.

## Core public API

Phase 1 creates these names. Later phases use them exactly as written. A phase plan that needs a new core function adds it to the core in its own task first.

```lua
KstyleUI.VERSION                                  -- string, set by the packager
KstyleUI.Modules.Register(def)                    -- def = { name, defaults, Enable, Disable }
KstyleUI.Modules.IsEnabled(name) -> boolean
KstyleUI.Callbacks.Register(event, owner, fn)     -- events: ThemeChanged, ClassChanged, ScaleChanged, ProfileChanged, IconsChanged
KstyleUI.Callbacks.Fire(event, ...)
KstyleUI.Tokens.Color(name) -> r, g, b, a         -- names from the spec's colour table
KstyleUI.Tokens.Size(name) -> number              -- root units
KstyleUI.Tokens.Duration(name) -> seconds
KstyleUI.Tokens.Font(role) -> path, size, flags   -- roles: display, heading, body, caption, number, world
KstyleUI.Theme.Accent() -> r, g, b
KstyleUI.Scale.Root() -> Frame                    -- KstyleUI_Root
KstyleUI.Scale.Pixel(n) -> units                  -- n whole physical pixels in root units
KstyleUI.Scale.Border() -> units                  -- the current border thickness
KstyleUI.Scale.Snap(units) -> units               -- nearest whole physical pixel
KstyleUI.Motion.Ease[name](t) -> number           -- linear, outSine, inOutSine, outQuad, outQuart, outQuint, outBack
KstyleUI.Motion.Tween(obj, setter, from, to, duration, easing, onDone) -> handle
KstyleUI.Motion.FadeIn(frame, duration) / FadeOut(frame, duration)
KstyleUI.Widgets.Panel(parent, opts) -> Frame     -- chamfer, bevel, shadow
KstyleUI.Widgets.Button(parent, opts) -> Button
KstyleUI.Widgets.IconButton(parent, opts) -> Button
KstyleUI.Widgets.Tabs(parent, opts) -> Frame
KstyleUI.Widgets.Toggle(parent, opts) -> Frame
KstyleUI.Widgets.Slider(parent, opts) -> Frame
KstyleUI.Widgets.Dropdown(parent, opts) -> Frame
KstyleUI.Widgets.EditBox(parent, opts) -> EditBox
KstyleUI.Widgets.ScrollList(parent, opts) -> Frame
KstyleUI.Widgets.StatusBar(parent, opts) -> StatusBar
KstyleUI.Widgets.Tooltip() -> GameTooltip-like Frame
KstyleUI.Widgets.Glow(frame, opts) -> handle      -- proc and selection glow
KstyleUI.Layout.Register(frame, key, defaultPosition, opts)  -- position = { anchor, x, y }; opts = { resizable, scalable, aspect, minWidth, minHeight, maxWidth, maxHeight, label }
KstyleUI.Options.Register(module, schema)        -- declarative rows: toggle, slider, dropdown, color, font, texture, text, header
KstyleUI.Store.Profile() -> table                 -- the active profile, with defaults
KstyleUI.Store.Module(name) -> table              -- one module's settings
KstyleUI.Store.Export() -> string / Import(string) -> ok, err
KstyleUI.Features.Get(store, key) -> boolean      -- errors on an unknown store or key
KstyleUI.Combat.Queue(fn)                         -- runs now out of combat, else on PLAYER_REGEN_ENABLED
KstyleUI.Safe.HideBlizzard(frame)                 -- reparent to a hidden frame, deferred, guarded
KstyleUI.Safe.Side(frame) -> table                -- weak-keyed per-frame state
KstyleUI.L[key] -> string                         -- locale table
```

## Phase 0: Foundation

**Detailed plan:** [`2026-11-07-kstyleui-phase-0-foundation.md`](2026-11-07-kstyleui-phase-0-foundation.md)

Repository rules, the TOC walker, a loadable addon skeleton, the regression runner and stubs, generated globals and luacheck, pre-commit, the taint scan, the secret-value lint, packaging and CI, the spike addon, the ability data extraction, and one in-game spike session with the owner.

**Exit:** CI is green on a PR, the empty addon loads on Forever, every spike question has a recorded answer, and `Tools/data/abilities.json` exists.

## Phase 1: Core and settings

**Detailed plan:** written when Phase 0 exits, using the spike results.

| Task | Delivers |
| --- | --- |
| Tokens and Theme | `Core/Tokens.lua`, `Core/Theme.lua`, `test-tokens.lua`. Class accent and `ClassChanged`. |
| Scale | `Core/Scale.lua`, `test-pixels.lua`. Root canvas, pixel snapping, rescale on display change. |
| Motion | `Core/Motion.lua`, `test-motion.lua`. Easing, pooled tween driver, fade helpers. |
| Store and Features | `Core/Store.lua`, `Core/Features.lua`, `test-store.lua`, `test-features.lua`. Profiles, migrations, export and import. |
| Modules, Callbacks, Events, Combat, Safe, Locale | `Core/Modules.lua` and siblings, `Core/Locale.lua`, `test-lifecycle.lua`, `test-combat.lua`. |
| Performance budget | `Tools/regression/measure.lua` and `test-perf.lua`: average time and allocated memory per call over 1,000 calls with the garbage collector stopped. Phase 2 and 3 modules register their combat paths with a budget. |
| Procedural media | `Tools/media/make_media.py` and the textures it draws: chamfer masks, bevels, shadow, glow, noise, rings, logo. `Media/PROVENANCE.md`. |
| Fonts | The chosen OFL font in `Media/Fonts/` with `OFL.txt`. |
| Widgets: panel, button, icon button, tabs | `Core/Widgets/*.lua` with tests |
| Widgets: toggle, slider, dropdown, edit box | `Core/Widgets/*.lua` with tests |
| Widgets: scroll list, status bar, tooltip, glow | `Core/Widgets/*.lua` with tests |
| Layout Mode | `Core/Layout/*.lua`, `test-layout.lua` |
| Icons service | `Core/Icons.lua`, `test-icons.lua`. Lookup and tinting, no art yet. Removed on 2026-11-08: the icons ship as a loose-file pack ([`docs/icons.md`](../../icons.md)) |
| Options window | `KstyleUI_Options/`, the rail, search, cards and preview pane |
| First-run setup | `Core/Setup/*.lua` |
| DevTest | `/kstyle test` and the `devlog` |
| Icon pilot | 24 icons per set, reviewed by the owner |

**Exit:** the owner opens the settings window in game, runs the setup, and moves a test frame in Layout Mode on two screen sizes.

## Phase 2: Combat HUD and chrome

Eight module plans, run in parallel, plus icon set A.

| Module | First tasks |
| --- | --- |
| `KstyleUI_UnitFrames` | Secure unit button, health and power bars, portraits, cast bar, frame auras, class resources, boss frames |
| `KstyleUI_ActionBars` | Secure button, compact bar layout (34-unit buttons, two rows), paging drivers, keybinds, cooldowns, glows, range and usability, pet and stance bars, hide Blizzard bars |
| `KstyleUI_Cooldowns` | Essential and utility cooldown rows, tracked buff icons and bars, placed in the HUD band between the player and target frames |
| `KstyleUI_Auras` | Player buff and debuff panel on the AuraContainer engine |
| `KstyleUI_Minimap` | Square mask, frame, zone and clock strip, button column, addon drawer |
| `KstyleUI_Chat` | Panel and tabs, edit box, copy, links, names |
| `KstyleUI_Tooltips` | Glass tooltip, colours, IDs, anchoring |
| `KstyleUI_DataBars` | XP and reputation bars, micro menu, bag bar, data strip |
| Icon set A | Full generation, review and the `KstyleUI_Icons` data addon. Superseded on 2026-11-08: set A and the `Icons` service were removed, and the set B repaints ship as a loose-file pack ([`docs/icons.md`](../../icons.md)) |
| Release workflow | `.github/workflows/release.yml`: on a `v*` tag on `main`, package with the BigWigs packager and upload to CurseForge, Wago and GitHub, using secrets the owner sets |

**Exit:** the owner levels a character with the full HUD and confirms it in game. `staging` may be promoted to `main` as the first public beta.

## Phase 3: Group play

| Module | First tasks |
| --- | --- |
| `KstyleUI_GroupFrames` | Party header, raid header, range fade, heal prediction, dispel highlight |
| `KstyleUI_Nameplates` | Plate attach and fade, health, cast bar, threat, debuffs |
| `KstyleUI_CombatText` | World font, frame numbers from `UNIT_COMBAT`, plate numbers if the spike allows |
| `KstyleUI_Meters` | Damage Meter skin, threat meter, swing timer |
| `KstyleUI_Bags` | Combined bags, bank, keyring, search, sort, junk |

**Exit:** the owner runs a dungeon and a battleground with every module on and forced restrictions enabled.

## Phase 4: Window skins and icon set B

One task per Blizzard window in `KstyleUI_Skins`: character sheet, spellbook and talents, quest log and objective tracker, world map, game menu, group finder, mail, merchant, trainer, professions, social, Legacy, loot, popups, ready check. Icon set B runs alongside after the owner tops up Higgsfield credits; it ships as a loose-file pack, not the `KstyleUI_IconsColour` addon first planned ([`docs/icons.md`](../../icons.md)).

**Exit:** every window in the list wears KstyleUI, and the owner confirms version 1.0 in game.
