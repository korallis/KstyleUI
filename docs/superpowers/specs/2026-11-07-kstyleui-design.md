# KstyleUI design

| Field | Value |
| --- | --- |
| Status | Approved in conversation on 2026-11-07. This file awaits the owner's review. |
| Target | World of Warcraft: Forever only: product `wowf`, client 1.60.1, TOC `16001`, game type `camelot` |
| Repository | `korallis/KstyleUI`, public, all rights reserved |
| Research | [`reports/KstyleUI research for WoW Forever.md`](../../../reports/KstyleUI%20research%20for%20WoW%20Forever.md) and the notes in `research_notes/` |
| Visual reference | [`docs/design/mockups/`](../../design/mockups/README.md). `05_kit_hunter.jpg` is canonical for components. The `v3/` set is canonical for the combat HUD: one image per scene and class. |

## Goal

KstyleUI replaces or restyles the whole Forever interface with one art direction: near-black smoked glass, chamfered corners, a live class-colour accent, crisp type and eased motion everywhere. It must look as finished as Narcissus, cover as much as EllesmereUI, and be the most reliable suite on Forever's edge cases.

KstyleUI succeeds when all of the following are true:

- Every module in [Modules](#modules) works on live Forever with no Lua errors and no taint, with Blizzard's forced-restriction CVars switched on.
- Components match `05_kit_hunter.jpg` at 1920x1080, 2560x1440, 3840x2160 and 3456x2234, with whole-pixel borders on each.
- A player who never enables a module pays nothing for it: no events, no hooks, no frames.
- Every check in [Checks](#checks) passes in CI on every pull request.
- The owner confirms each release in game before `staging` moves to `main`.

## Decisions

The owner made these decisions on 2026-11-07. Each one is binding on the plan.

| Topic | Decision |
| --- | --- |
| Scope | The full suite in the first release, built in phases |
| Approach | Fully our own code: no oUF and no Ace3 runtime. LibSharedMedia is optional interop only. |
| Look | "Obsidian and class colour": neutral glass, accent is the current character's class colour |
| Reference | `05_kit_hunter.jpg` for components. `v3/` for the combat HUD. |
| Scaling | Same proportions on every screen, borders snapped to whole physical pixels |
| Unit frames | Portraits on by default, with a switch to turn them off. Player and target sit centred above the action bars, on either side of the Cooldown Manager. |
| Action bars | Compact: two rows of 12 buttons of 34 units at the 1080 reference, 3-unit gaps, no name labels. Keybind, stack and cooldown text sit on the button. |
| Cooldown Manager | Always part of the combat HUD, in its own module: essential cooldowns centred above the action bars, utility cooldowns beneath them, tracked buff bars beside them. |
| Minimap | Square, with the zone and clock on a strip inside its bottom edge and buttons down one side |
| Icons | Two custom icon sets for every ability: set A (white light art, tinted in game) and set B (full colour). Generated at high quality. An option switches between custom and Blizzard icons. |
| Combat text | Wanted, built after an in-game spike proves what Forever allows |
| Positioning | KstyleUI's own Layout Mode, not Blizzard's Edit Mode |
| Gamepad | Never break or taint Forever's gamepad UI. A gamepad layout comes after the first release. |
| Audience | Public release on CurseForge, Wago and GitHub |
| Licence | All rights reserved |
| Line endings | CRLF, for parity with NaowhForever's checks |
| Branches | Every change merges into `staging`. `main` moves only after the owner's in-game pass. |
| Build method | An in-session multi-agent workflow from the owner's Claude Code session, not the agent factory |

## Forever facts the design relies on

The research report has the sources. These facts were confirmed in game on 2026-11-07:

- `WOW_PROJECT_ID` and `WOW_PROJECT_CAMELOT` both return `18`.
- `GetPhysicalScreenSize()` returns `3456, 2234` on the owner's Mac, which is the real Retina pixel count.

These facts come from Blizzard's code and posts:

- Forever runs the Retail 12.1.5 UI under a `Camelot/` override layer. Edit Mode, the Settings API, the Cooldown Manager, the Damage Meter, nameplates and the AuraContainer aura frames all exist.
- Midnight's secret values apply in full. `UnitHealth`, `UnitHealthMissing`, `UnitHealthPercent` and `UnitInRange` are always secret. Code can pass a secret to a widget setter, but comparing it, doing arithmetic on it, testing it as a boolean, using it as a table key or taking its length raises an error.
- Aura data turns secret during a boss pull before `InCombatLockdown()` returns true. Guard every aura read with `C_Secrets.ShouldAurasBeSecret()`.
- The combat log is closed to addons. Forever adds `C_SwingTimer` and the `PLAYER_SWING` event.
- Threat values are readable on Forever.
- Forever uses classic-era spell IDs and does not load Blizzard's deprecated shims. Use `C_SpellBook.IsSpellKnown`, not `IsPlayerSpell`.
- Forever does not load the Encounter Timeline, Encounter Warnings, Housing, Delves, Mythic+, the Encounter Journal, the Retail Group Finder, the PvP UI, Garrisons or the Trading Post. There is no Extra Action Button and no hero talents, and each class has one spec.
- Addons can load power-of-two PNG, TGA, JPEG and BLP textures, but cannot register atlases. There is no blur or shader API.
- `ReloadUI()` is blocked from addon code. A reload button must be a secure macro button that runs `/reload`.

The authoritative API source is the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever), which matches build 70840. The in-game `/api` browser confirms anything the branch leaves unclear.

## Architecture

### Addons and folders

The repository root is the core addon. Each module is a folder at the root named `KstyleUI_<Module>`. The BigWigs packager moves each module folder out to its own addon through `move-folders` in `.pkgmeta`.

```
KstyleUI.toc               core addon
Core/                      services listed below, each area loaded by its own XML file
Media/                     fonts, procedural textures, logo, UI glyphs
KstyleUI_Options/          settings window, load-on-demand
KstyleUI_UnitFrames/
KstyleUI_GroupFrames/
KstyleUI_ActionBars/
KstyleUI_Cooldowns/
KstyleUI_Auras/
KstyleUI_Nameplates/
KstyleUI_CombatText/
KstyleUI_Minimap/
KstyleUI_Chat/
KstyleUI_Bags/
KstyleUI_Tooltips/
KstyleUI_DataBars/
KstyleUI_Meters/
KstyleUI_Skins/
KstyleUI_Icons/            icon set A, load-on-demand
KstyleUI_IconsColour/      icon set B, load-on-demand
Tools/                     checks, tests, art pipeline, data extraction. Never packaged.
docs/                      specs, plans, design references
```

Every TOC carries these lines:

```
## Interface: 16001
## AllowLoadGameType: camelot
## Group: KstyleUI
```

Each module TOC also carries `## Dependencies: KstyleUI` and lists one file: the module's own XML. Each XML file loads that module's Lua files in order, so adding a file never edits a TOC. The core TOC declares `## SavedVariables: KstyleUIDB` and the addon compartment entry.

### Core services

The core exposes one namespace, `KstyleUI`, through the addon's private table. Modules read services from it and never from each other.

| Service | Responsibility |
| --- | --- |
| `Tokens` | Every colour, size, gap, duration and font in one table. The only place a hex or RGB literal may appear. |
| `Theme` | Resolves tokens to the current accent: the class colour from `C_ClassColor.GetClassColor`, or the player's fixed colour. Fires `ThemeChanged` and `ClassChanged`. |
| `Scale` | The root canvas and whole-pixel maths described in [Scaling](#scaling). Fires `ScaleChanged`. |
| `Motion` | Easing functions, AnimationGroup presets and one pooled tween driver. |
| `Widgets` | The component kit: panel, button, icon button, tab strip, toggle, slider, dropdown, edit box, scroll list, tooltip, status bar, cooldown, glow. Every module builds its UI from these. |
| `Icons` | Maps a game icon file ID to a custom texture when the custom-icon option is on. |
| `Layout` | Layout Mode and the stored positions of every movable element. |
| `Store` | SavedVariables, profiles, defaults and migrations. |
| `Features` | Every module's and setting's on/off default, in one strict table. |
| `Combat` | A queue that holds protected work while in combat and runs it on `PLAYER_REGEN_ENABLED`. |
| `Safe` | Taint-safe helpers: hide a Blizzard frame by reparenting it to a hidden frame, deferred with `C_Timer.After(0)`, never during Edit Mode or combat. Side tables for per-frame state. |
| `Events` | One event frame per module. A module registers events only while it is on. |
| `Setup` | The first-run setup. |
| `DevTest` | `/kstyle test` and its SavedVariables log. See [In-game testing](#in-game-testing). |

Callbacks (`ThemeChanged`, `ClassChanged`, `ScaleChanged`, `ProfileChanged`, `IconsChanged`) go through one dispatcher in the core. A frame that subscribes restyles itself when the callback fires. Nothing polls.

### Module lifecycle

Every module follows the same contract:

1. At load, the module registers itself with the core: its name, its settings defaults and its `Enable` and `Disable` functions. It creates no frames and registers no events.
2. At `PLAYER_LOGIN`, the core enables each module that the active profile switches on. A module that creates secure frames creates them here. `PLAYER_LOGIN` is the one time protected setup is allowed while the player is in combat.
3. `Enable` builds frames on first use and registers events.
4. `Disable` unregisters events and hides the module's own frames. A module that reskinned Blizzard frames asks the player to reload, because Blizzard frames keep the changes.

Code defaults leave every module off, as NaowhForever's first rule requires. The first-run setup switches on the modules the player picks.

### Saved data

`KstyleUIDB` holds the following:

```lua
KstyleUIDB = {
	version = 1,           -- migrations run when this is lower than the code's version
	profiles = {},         -- [profileName] = settings that differ from defaults
	characters = {},       -- [realm-name] = profileName
	layouts = {},          -- [profileName] = { [elementKey] = position }
	account = {},          -- account-wide settings such as the icon set choice
	devlog = {},           -- results from /kstyle test, newest last
}
```

Profiles store only values that differ from the defaults. Defaults come from `Features` and each module's declared defaults through a metatable lookup. A profile exports as one string: `C_EncodingUtil.SerializeCBOR`, then `CompressString`, then `EncodeBase64`, with a `KSUI1:` prefix. Phase 0 confirms these functions exist on Forever. Import validates the shape before applying anything.

## Design system

### Colour tokens

| Token | Value | Use |
| --- | --- | --- |
| `surface` | `#101010` at 88% | Panels |
| `raised` | `#1c1c1c` | Cards, tiles, inputs |
| `edgeOuter` | `#000000` at 60% | Outer bevel line |
| `edgeInner` | `#ffffff` at 8% | Inner bevel hairline |
| `text` | `#ababab` | Body text at rest |
| `textEmphasis` | `#ebebeb` | Titles and values |
| `textHover` | `#ffffff` | Text under the mouse only |
| `textDisabled` | `#666666` | Disabled text |
| `accent` | Class colour, live | Hairlines, selected states, fills, player health, proc glows |
| `rare` | `#4fc3ff` | Rare quality |
| `epic` | `#b67cff` | Epic quality |
| `hostile`, `neutral`, `friendly` | Tuned in phase 1 against the glass | Reaction colours |

Quality and reaction values outside the table come from Blizzard's colour tables at run time, brightened by the `Theme` service for contrast on dark glass.

### Shape

- Panels have 45-degree chamfered corners of 6 units. Tiles and buttons have 3 units.
- HUD sizes at the 1080 reference: action buttons 34 units with 3-unit gaps, essential cooldown icons 40 units, utility cooldown icons 30 units, player and target frames 220 by 46 units, portraits 46 units. Players can resize each in Layout Mode.
- Every panel edge is a double-line bevel: `edgeOuter` outside and `edgeInner` inside, each one physical pixel at 1080p and 1440p, and two at 4K and on the Mac.
- Panels cast a soft outward shadow of about 12 units, made from one nine-sliced falloff texture whose corner pieces are centred on the panel's corners.
- Dividers are gradients that fade out at both ends.
- The KstyleUI signature motif is the chamfered diamond from the logo in `05_kit_hunter.jpg`.

Chamfers come from mask textures, so the same art works at every size.

### Type

- **Body font.** Source Sans 3 Semibold or Inter Semibold. Both are under the SIL Open Font Licence. A phase 0 spike renders both in game at 9, 11, 16 and 24 units, and the owner picks one. The repository ships the font's `OFL.txt`.
- **Scale.** Display 24, heading 16, body 11, caption 9. Captions are uppercase with letter spacing.
- **Numerals.** Numbers that change, such as health and timers, use tabular figures.
- **Shadow.** Text gets a soft shadow offset by 0.6 units instead of an outline. Text over the 3D world uses a thin outline.
- **Slug.** The `SLUG` font flag is used only for large numerals and text that scales during an animation, after the spike confirms it renders cleanly.

### Motion

The core implements Penner's easing formulas itself: `linear`, `outSine`, `inOutSine`, `outQuad`, `outQuart`, `outQuint` and `outBack`.

| Element | Motion |
| --- | --- |
| Hover | 0.15 s `outQuart`. The hairline brightens and the text moves to `textHover`. |
| Press | Content moves down 1 unit while the button is held |
| Panel open | Alpha 0 to 1 over 0.25 s while rising 16 units over 0.4 s with a 2-unit overshoot |
| Panel close | Alpha to 0 over 0.15 s |
| Lists | Each row fades in 0.05 s after the row above it |
| Cast bar | A light sheen crosses the bar in 0.6 s |
| Proc glow | Pulses on a 1.2 s loop |
| Health and power | The engine eases the bar. Lua never reads the value. |
| Scroll | Eased scrolling with a short bounce at either end |

AnimationGroups do the work wherever they can. Values Lua may read, such as XP, use the pooled tween driver. The driver runs one `OnUpdate`, removes it when no tween is active and allocates no tables per frame.

### Scaling

KstyleUI draws everything inside one root frame, `KstyleUI_Root`, parented to `UIParent`. The root is a canvas exactly 1080 units tall on every screen, so a frame occupies the same share of the screen on every device.

```lua
-- Effective scale 768/1080 makes the root 1080 units tall at any resolution.
local REFERENCE_SCALE = 768 / 1080

local function ApplyRootScale(root, userScale)
	root:SetScale(REFERENCE_SCALE / UIParent:GetEffectiveScale() * userScale)
end
```

The core reapplies the scale on `PLAYER_LOGIN`, `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`. `userScale` is the size slider, from 0.75 to 1.50.

One physical pixel is `1080 / physicalHeight` units at a user scale of 1. The core snaps sizes and offsets to whole physical pixels and draws every border with a whole number of physical pixels:

| Screen | Physical pixels per unit | Border |
| --- | --- | --- |
| 1920x1080 | 1.00 | 1 px |
| 2560x1440 | 1.33 | 1 px |
| 3840x2160 | 2.00 | 2 px |
| 3456x2234 | 2.07 | 2 px |

The root is 1920 units wide at 16:9 and about 1671 units wide on the Mac. Every movable element stores its position against one of nine anchors (the corners, the edge midpoints and the centre), so one layout fits all four screens.

### Art pipeline

| Asset | Source | Format |
| --- | --- | --- |
| Chamfer masks, bevels, shadows, glows, gradients, glass noise, rings | A Python script in `Tools/media/` draws them at 4x and downsamples, so they can be redrawn at any time | Power-of-two PNG |
| Ability icons | Higgsfield `gpt_image_2_5`, high quality. See [Custom icons](#custom-icons). | 128x128 PNG |
| Logo and ornament | Higgsfield, then cleaned up by hand | Power-of-two PNG |
| UI glyphs for the minimap, rail and buttons | Drawn as simple monochrome line icons, tinted in game | Power-of-two PNG sheet with a coordinate table |

Every generated asset gets an entry in `Media/PROVENANCE.md` with its model, prompt, settings and date. No asset may be copied from Narcissus, Plumber, DialogueUI, WaypointUI or any other addon.

## Modules

Each module either replaces Blizzard's frames with its own, mirrors a Blizzard data source into its own display, or reskins Blizzard's frame in place.

| Addon | Scope | Approach |
| --- | --- | --- |
| `KstyleUI_Options` | Settings window: category rail, search, option cards, live preview, Layout Mode button. Registered as a canvas category in Blizzard's Settings panel and opened by `/kstyle`. | Our own window |
| `KstyleUI_UnitFrames` | Player, target, target of target, focus, focus target, pet and boss 1 to 5. Portraits (switchable), cast bars, frame auras, class resources, threat glow, raid markers, leader and role icons. | Replace |
| `KstyleUI_GroupFrames` | Party and raid frames up to 40: class colours, role icons, range fade, incoming heals, dispellable debuff highlight | Replace |
| `KstyleUI_ActionBars` | Main bar with stance, stealth, form and possess paging, extra bars, pet bar, stance bar, keybind text, cooldown sweeps, proc glows, usable and range shading, mouseover fade | Replace |
| `KstyleUI_Cooldowns` | Blizzard's Cooldown Manager shown in KstyleUI's style: essential cooldowns (40 units), utility cooldowns (30 units), tracked buff icons and tracked buff bars (180 by 18 units), placed in the HUD band | Mirror, or reskin in place if the spike shows mirroring cannot work in combat |
| `KstyleUI_Auras` | The player's buff and debuff panel under the minimap | Replace |
| `KstyleUI_Nameplates` | A KstyleUI plate on each nameplate: health, cast bar, threat colour, debuffs | Replace the visible plate |
| `KstyleUI_CombatText` | Animated damage and heal numbers on KstyleUI frames and plates, and the KstyleUI font for the game's own world numbers | Mirror, after the spike |
| `KstyleUI_Minimap` | Square minimap, chamfered frame, zone and clock strip, side button column, addon-button drawer, coordinates | Reskin |
| `KstyleUI_Chat` | Chat panels, tabs with an accent underline, edit box, copy chat, clickable links, class-coloured names | Reskin |
| `KstyleUI_Bags` | Combined bags and bank, keyring, search, sort, quality borders, selling junk | Replace |
| `KstyleUI_Tooltips` | Glass tooltips, quality and class colours, optional spell and item IDs, cursor anchoring | Reskin |
| `KstyleUI_DataBars` | XP, reputation and honour bars, micro menu, bag bar, a data strip with FPS, latency, gold, durability and time | Reskin, plus our own strip |
| `KstyleUI_Meters` | Damage Meter skin, our own threat meter, swing timer | Mirror |
| `KstyleUI_Skins` | Character sheet, spellbook and talents, quest log and objective tracker, world map, game menu, group finder, mail, merchant, trainer, professions, social windows, Legacy, loot, popups, ready check | Reskin, one window per task |
| `KstyleUI_Icons`, `KstyleUI_IconsColour` | Icon sets A and B | Data addons |

### Module rules

These rules come from the research. Each module's own README repeats the rules that apply to it.

- **Unit and group frames** use `SecureUnitButtonTemplate` buttons with `RegisterUnitWatch`, and `SecureGroupHeaderTemplate` headers for groups. Health goes straight to the bar with `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`. Health text comes from `UnitHealthPercent` or `AbbreviateNumbers`, never from Lua arithmetic. Bar colours that depend on health come from `C_CurveUtil` colour curves. Incoming heals come from `CreateUnitHealPredictionCalculator`. Range fade uses `SetAlphaFromBoolean`. Combo points draw as one-point status bars so the comparison happens in the engine.
- **Cast bars** use `StatusBar:SetTimerDuration` with the duration object from the cast APIs. Casts by units other than the player and pet can be secret, so the bar never reads the spell name except through widget setters.
- **Auras** use the 12.1 AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). No module scans auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true.
- **Action bars** are KstyleUI's own secure buttons. Keybinds use `SetOverrideBindingClick`. Paging uses `RegisterStateDriver`. Cooldowns use `C_ActionBar.GetActionCooldownDuration` with `Cooldown:SetCooldownFromDurationObject`. Blizzard's bars are reparented to a hidden frame through `Safe`. The module never touches `Blizzard_GamepadActionBars`.
- **Nameplates** attach a KstyleUI frame to each plate on `NAME_PLATE_UNIT_ADDED` and fade Blizzard's plate with alpha. Names of non-player units can be secret in combat, so they pass through whole.
- **Reskins** hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames. They never call Blizzard functions that open or refresh Blizzard windows. Tooltip changes use `TooltipDataProcessor.AddTooltipPostCall`.
- **Windows** handle Escape with their own key handler, not `UISpecialFrames`.

### Custom icons

The icon work has its own pipeline. It runs in parallel with the modules from phase 0.

1. **List.** A script in `Tools/icons/` builds `Tools/data/abilities.json` from the game's data tables for the current `wowf` build: `SkillLineAbility` for each class and race, `SpellName`, `SpellMisc` for the icon file ID and the spell school, and `SpellEffect` where needed. The script reads wago.tools DB2 exports. If those fail, it reads the installed client's CASC storage read-only. Wowhead Forever is used only to spot-check results, because its terms restrict automated scraping. The list covers class abilities, pet abilities, racials, profession spells and Forever's new spells.
2. **Group.** Abilities are grouped by icon file ID, because spell ranks and related spells share one icon. Each group becomes one icon to generate. The current estimate is 700 to 900 icons.
3. **Pilot.** The pipeline generates 24 icons in each set from a style reference and the owner approves them before the full run.
4. **Generate.** Each icon is one `gpt_image_2_5` image at `1:1`, `--resolution 1k --quality high`, with the approved pilot icons passed as `image_references`. The prompt uses the spell's name, its school and a short visual description written from its tooltip. Set A asks for white light art on pure black. Set B asks for full-colour painted art.
5. **Check.** A script rejects images with a coloured cast in set A, blank or clipped silhouettes, or text. The owner reviews contact sheets of 64 icons at a time and marks rerolls.
6. **Package.** Accepted images are downscaled to 128x128 PNG. Set A keeps luminance only. Each set ships as a load-on-demand addon with a table that maps icon file ID to texture path.
7. **Record.** Every icon gets a provenance row: model, prompt, seed if available, date and the file ID it replaces.

Set A is generated and shipped first. Set B follows and is expected to need a credit top-up: both sets at high quality cost about 2,400 credits before rerolls, against 2,933 available on 2026-11-07.

At run time the `Icons` service swaps a texture when all three conditions hold: the option is on, the icon is in the active set's table, and KstyleUI drew the icon from data Lua can read. That covers action bars, the spellbook skin, the player cast bar, cooldown displays and tooltips. Auras and enemy casts that are secret keep the game's icon. Set A is tinted with `SetVertexColor`, plus an additive copy at low alpha so highlights stay bright. Its tint options are class colour, spell school colour and white.

### Combat text

`KstyleUI_CombatText` has two layers:

1. **World numbers.** The game draws damage numbers over units itself. KstyleUI sets `DAMAGE_TEXT_FONT` to its own font when the module is on. The change takes effect at the next login, not after a reload, and the options say so.
2. **Frame numbers.** KstyleUI animates incoming damage and heals on its own unit frames, group frames and, if the spike allows it, nameplates. The source is the `UNIT_COMBAT` event. Amounts pass straight to `FontString:SetText` through `AbbreviateNumbers`, so Lua never compares or adds them.

The phase 0 spike decides the second layer. It records which units fire `UNIT_COMBAT`, which arguments are secret in and out of restricted states, and whether nameplate units fire it. If the event does not fire for a unit type, that unit type gets no frame numbers.

### Layout Mode

`/kstyle layout`, or the button in the settings window, enters Layout Mode out of combat. Entering combat leaves it and restores the last saved positions.

- Every movable element shows a mover plate with its name.
- A grid and snapping guides align elements to each other and to the screen's anchors.
- The arrow keys nudge the selected element by one physical pixel, or ten with Shift.
- Undo, redo and revert work through a history of changes.
- Positions save per profile, as an anchor plus offsets in root units.

Layout Mode never moves Blizzard frames. A Blizzard frame that needs a new place is hidden through `Safe` and replaced by a KstyleUI frame.

### Customisation and resizing

The owner requires that every visible KstyleUI element can be resized and customised from the settings window, and resized directly in Layout Mode.

Every element a module shows registers with `KstyleUI.Layout.Register(frame, key, defaultPosition, opts)`. `opts` declares what the element supports: `resizable` (width and height, with `minWidth`, `minHeight`, `maxWidth` and `maxHeight`), `scalable` (a scale from 0.5 to 2.0), and `aspect` when the element keeps its proportions. Layout Mode draws resize handles on the corners and edges of a resizable element and snaps sizes to whole physical pixels.

Every registered element gets these settings in the settings window without any module code, on a shared Elements page and on its module's page:

| Setting | Values |
| --- | --- |
| Shown | Always, in combat only, out of combat only, with a target, on mouseover, never |
| Position | Anchor (one of nine), X and Y offsets |
| Size | Width and height, or scale, as the element declares |
| Opacity | In combat and out of combat, 0 to 100% |
| Strata | Background, low, medium, high |

Modules add their own settings through `KstyleUI.Options.Register(module, schema)`. The schema is a list of declarative rows: `toggle`, `slider`, `dropdown`, `color`, `font`, `texture`, `text` and `header`, each with a key into the module's settings, a label, a one-sentence help line, and optional `showWhen` and `disableWhen` conditions. The settings window builds every page from these schemas, so search covers every setting.

Every module offers at least these customisations where they apply: text elements choose font, size and outline; bars choose texture, colour source (class, reaction, custom) and orientation; icon groups choose icon size, spacing, rows, columns and growth direction; and every accent use can follow the class colour or a custom colour. The per-module lists in the roadmap's Phase 2 to 4 rows are the minimum.

### Settings and first-run setup

The settings window follows `04_settings_druid.jpg`, built entirely from the `Widgets` kit. Its parts:

- A category rail with one entry per module.
- A search field that matches setting names and help text.
- Option cards whose help text is one short sentence, under 100 characters.
- A live preview pane for the selected module.
- The Layout Mode button.

The first-run setup opens on an account's first login with KstyleUI and runs in four steps:

1. A welcome screen.
2. A layout choice: DPS, Tank or Healer.
3. A module picker with every module switched on and a short note on each.
4. A summary with an Apply button.

Apply switches on the chosen modules, writes the layout and asks for a reload through a secure `/reload` button. `/kstyle setup` reopens it.

## Quality rules

Every change meets these five rules, adapted from NaowhForever's contribution guide:

1. **Off in code, free while off.** Code defaults are off. A module that is off has no events, no hooks, no frames and no `OnUpdate`. The first-run setup switches modules on.
2. **Cheap while on.** Code is event-driven. `OnUpdate` runs only while something moves or counts down. Combat paths allocate no tables.
3. **No taint, no Lua errors.** The rules in [Module rules](#module-rules) apply everywhere. Protected work waits for the `Combat` queue.
4. **Forever only.** No Retail branches, classic-era IDs, the current API only.
5. **Our own code and art.** Nothing is copied from another addon. Every generated asset has a provenance row.

Code style:

- Lua 5.1 only: no `goto`, no labels, no integer division.
- ASCII only in `.lua`, `.toc` and `.xml` files, with CRLF line endings. `.gitattributes` sets `* -text` so git never rewrites them. Agents write LF, so `Tools/dev/crlf.py` converts changed addon files before each commit.
- A file has one comment, its first line: `-- <File>.lua: <what it is>.` Anything else a reader needs goes in the module's README under "Why".
- Sizes, gaps, durations and IDs are named constants. Colours come only from `Tokens`.
- UI comes only from the `Widgets` kit. A missing component is added to the kit, never copied into a module.

## Checks

The checks are KstyleUI's own implementations of NaowhForever's checks. NaowhForever is all rights reserved, so no file is copied from it.

| Check | Runs in | What fails it |
| --- | --- | --- |
| `pre-commit-hooks` | pre-commit | Merge markers, invalid YAML or XML, filename case conflicts, private keys, trailing whitespace, files over 5 MB, mixed line endings |
| `luacheck` 1.2.0 | pre-commit | Unknown globals, unused variables. `read_globals` is generated from the Gethe `forever` branch, and a deny list of deprecated shims such as `IsPlayerSpell` and `GetSpellInfo` fails any use. |
| `addon-crlf`, `addon-ascii` | pre-commit | An addon file with LF endings or a non-ASCII byte |
| `no-goto` | pre-commit | `goto` or `::label::` in an addon file. LuaJIT and this Mac's luacheck accept both, and the game does not. |
| `toc-files` | pre-commit | A file listed by a TOC or an XML include that is missing or has the wrong case |
| `actionlint`, `zizmor` | pre-commit | Invalid or insecure GitHub Actions workflows |
| `conventional-pre-commit` | commit-msg | A commit message that is not `type(scope): summary` |
| `test-syntax.lua` | tests | A TOC-loaded file that real Lua 5.1 cannot compile |
| `test-taint-scan.lua` | tests | A call on a Blizzard frame, a protected call without a combat check, a write into a Blizzard table or a field write onto a Blizzard frame, `SetParent` without an Edit Mode guard nearby, or `Hide()` on a Blizzard layout frame. Each allowed site is listed with a count and a reason. |
| `test-secrets.lua` | tests | Comparison, arithmetic, `#`, table-key use or a boolean test on a value from a secret source such as `UnitHealth`, `UnitPower`, `UnitCastingInfo` or aura data, without an `issecretvalue` guard first. Any use of `COMBAT_LOG_EVENT` or `CombatLogGetCurrentEventInfo`. |
| `test-pixels.lua` | tests | A border or line that is not a whole number of physical pixels at 1080, 1440, 2160 and 2234 lines, including chamfer slices |
| `test-tokens.lua` | tests | A hex or RGB colour literal outside `Core/Tokens.lua` |
| `test-features.lua` | tests | A switch that is not a boolean, is on by default, or does not match a module's declared defaults |
| `test-perf.lua` | tests | A combat path over its per-call time budget, or one that allocates memory |
| `test-*.lua` per module | tests | Module behaviour against stubs, loaded through the shared TOC-and-XML walker |
| `package` | CI | A packaged zip that is missing a TOC file or library, or that contains `Tools/`, `docs/`, `research_notes/`, `reports/` or lint config |
| `pr-rules` | CI | A PR that changes shipped files without a `## Changelog` line starting `Added:`, `Changed:` or `Fixed:`, or that changes a TOC version outside a release |
| `title` | CI | A PR title that is not `type(scope): summary` |

`Tools/regression/run-all.sh` runs every `test-*.lua` with `$LUA`. On the Mac use `LUA=luajit`. CI on Ubuntu installs `lua5.1`. One Lua module, `Tools/regression/toc_files.lua`, walks the TOCs and XML includes, and every test and the package check uses it. GitHub Actions are pinned by commit SHA, set `persist-credentials: false` and request minimal permissions.

## In-game testing

The owner's Forever `Interface/AddOns` folder links each addon folder to the owner's checkout at `~/KstyleUI`, which stays on `staging`. Merged changes reach the game after `git -C ~/KstyleUI pull --ff-only` and a `/reload`. Agents never edit that checkout. Each agent works in its own worktree.

`/kstyle test` runs smoke checks in the live client:

- Each enabled module loaded and built its frames.
- No Lua error was caught since login.
- The API probes for the open questions returned what the code expects.

Results go to `KstyleUIDB.devlog`. After the owner types `/reload`, the agent reads the result from `WTF/Account/<account>/SavedVariables/KstyleUI.lua`, so most in-game checks need one action from the owner.

Every PR description lists its in-game checks. A release candidate also runs with `addonCombatRestrictionsForced`, `addonEncounterRestrictionsForced`, `addonMapRestrictionsForced` and `addonChatRestrictionsForced` switched on, and with `/console taintLog 1`.

## Branches and releases

- Each task gets a branch named `<type>/<scope>-<slug>`, such as `feat/unitframes-player-frame`, in its own worktree under `~/KstyleUI.worktrees/`.
- Before a PR opens, the task's checks and tests pass locally, `cr review --agent` runs on the changes (critical and major findings fixed, at most two rounds), and one cross-family review runs (`/codex:review`).
- A PR targets `staging`, covers one coherent piece of work, and is squash-merged. KstyleUI has no PR line limit: the owner waived the global 400-line rule on 2026-11-07.
- When the owner confirms in-game tests pass on `staging`, `staging` fast-forwards to `main` and `main` is tagged `vX.Y.Z`. The tag starts the release workflow, which packages with the BigWigs packager and uploads to CurseForge, Wago and GitHub. The CurseForge and Wago API tokens live in GitHub Actions secrets, set by the owner. They are never printed or committed.

## Build mode

On 2026-11-07 the owner asked for the whole suite to be built before the first in-game test. Code therefore cannot wait for the spikes. Each module builds the approach the spec names and guards every assumption the spikes would have checked: it tests that an API exists before calling it, checks `issecretvalue` before any comparison, and falls back to a safer path (for example, restyling a Blizzard frame in place) when the preferred path is unavailable. The spike addon still ships in `Tools/spikes/` so the owner's first test session can confirm each assumption, and each fallback logs which path it took to `KstyleUIDB.devlog`.

Build agents work in an in-session workflow with no merge queue. An agent merges its own pull request into `staging` with a squash merge once the checks pass, so later agents start from the merged code.

## Build phases

The build runs as an in-session multi-agent workflow. Each task runs in its own worktree. Tasks in the same phase run in parallel. A phase starts only when every task it depends on has merged into `staging`.

| Phase | Work | Depends on |
| --- | --- | --- |
| 0 | Repository tooling: `.gitattributes`, `.pre-commit-config.yaml`, `.luacheckrc` with the generated globals, `Tools/regression/` with the walker and the cross-cutting tests, CI workflows, `.pkgmeta`, `AGENTS.md`. In-game spikes listed in [Spikes](#spikes). Icon data extraction. | Nothing |
| 1 | Core services, the `Widgets` kit, Layout Mode, `KstyleUI_Options`, first-run setup. Icon pilot. | Phase 0 |
| 2 | `KstyleUI_UnitFrames`, `KstyleUI_ActionBars`, `KstyleUI_Cooldowns`, `KstyleUI_Auras`, `KstyleUI_Minimap`, `KstyleUI_Chat`, `KstyleUI_Tooltips`, `KstyleUI_DataBars`. Icon set A. | Phase 1 |
| 3 | `KstyleUI_GroupFrames`, `KstyleUI_Nameplates`, `KstyleUI_CombatText`, `KstyleUI_Meters`, `KstyleUI_Bags` | Phase 1. Combat text also depends on its spike. |
| 4 | `KstyleUI_Skins`, one Blizzard window per task. Icon set B. | Phase 1 |

## Spikes

Each spike is a small throwaway test in the live client. It answers one question before the code that depends on it is written.

| Question | Unblocks |
| --- | --- |
| Do Source Sans 3 and Inter render cleanly at 9, 11, 16 and 24 units, with and without `SLUG`? | Font choice |
| Do `RegisterStateDriver`, `WrapScript` and `SecureGroupHeaderTemplate` work on live, including stance, stealth, form and possess paging? | Action bars, group frames |
| Which units fire `UNIT_COMBAT`, and which arguments are secret in and out of restriction? | Combat text |
| Does setting the scale of a frame parented to `UIParent` cause taint, and do the pixel maths hold on all four screens? | Scaling |
| Do `C_EncodingUtil.SerializeCBOR`, `CompressString` and `EncodeBase64` exist on Forever? | Profile export |
| When does `C_Secrets.ShouldAurasBeSecret()` turn true relative to `ENCOUNTER_START` and `InCombatLockdown()`? Are combo points secret outside restriction? | Unit frames, auras |
| Do `C_DamageMeter` values go secret in combat? Which power types are never secret? | Meters, unit frames |
| Can `C_CooldownViewer` data and duration objects drive KstyleUI's own cooldown icons in combat, or must Blizzard's viewers be restyled in place? | Cooldowns |
| Do masks read a PNG's alpha channel, and does a 2048x2048 texture load? | Art pipeline |
| How do the Classic and Enhanced experience presets change the default frames KstyleUI hides? | Every replace module |

## Out of scope for the first release

- A dedicated gamepad layout. KstyleUI stays gamepad-safe throughout.
- Click-casting.
- Extra themes such as gold or arcane accents.
- Boss timelines and anything that needs the combat log.
- Translations beyond English. Strings go through a locale table from the start so translations can follow.
