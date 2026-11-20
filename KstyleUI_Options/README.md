# KstyleUI_Options

## EllesmereUI parity audit (2026-11-20)

This is the profile, general appearance and Options-window inventory for public EllesmereUI v9.9.1, using its [CurseForge page](https://www.curseforge.com/wow/addons/ellesmereui), [Wago release listing](https://addons.wago.io/addons/ellesmereui/versions?stability=stable), [patch notes](https://www.curseforge.com/wow/addons/ellesmereui/files/9341121), [settings screenshot](https://media.forgecdn.net/attachments/1663/776/3-png.png) and [HUD examples](https://media.forgecdn.net/attachments/1664/342/9-png.png). The source links below pin `8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5`; source was read for labels and behaviour only, with no code or data copied. Wago's JavaScript-only detail body supplies no additional readable menu rows. Layout Mode has its own complete table in `Core/Layout/README.md`.

Repeated swatches and module mirrors are enumerated in their row. A module mirror is the same option as the module's own control, not a requirement for a second settings page. Other module-specific controls remain in their module audits. The General page's gamepad, combat/gameplay CVars, glow-effects editor and Numbers formatter are outside this task's appearance/window/profile scope.

| Publicly documented option | KstyleUI status | Control or remaining work | Public source |
| --- | --- | --- | --- |
| Active profile | Present | Profiles > Profile | [Profiles source] |
| New profile | Present | Profiles > New profile | [Profiles source] |
| Copy current / another profile | Present | Profiles > Copy from | [Profiles source] |
| Rename profile | Present | Profiles > Rename | [Profiles source] |
| Delete profile | Present | Profiles > Delete; active profile is protected | [Profiles source] |
| Reset profile | Present | Profiles > Reset profile; recovery backup available | [Profiles source] |
| Assign to specialization / class | Present | Use a profile per specialization: client spec IDs when available, assigned-role fallback otherwise | [Profiles source] |
| Whole profile import from string | Present | Profiles > Import; decode, checksum, validation, review and backup | [Profiles source] |
| Whole profile export to string | Present | Profiles > Export; selected text ready to copy | [Profiles source] |
| Export addon checklist | Present | Share scope > Selected modules; independent toggles, Select all and Clear | [Profiles source] |
| Import addon checklist | Present | The same Selected modules toggles restrict review and application | [Profiles source] |
| Include Unlock Mode layout on import | Present | Include layout; off keeps positions and named layouts | [Profiles source] |
| Include Unlock Mode layout on export | Present | Include layout; available for Everything and Selected modules | [Profiles source] |
| Include global appearance | Present | Selected modules includes Appearance, Widgets, Hud Style and Readability | [Profiles source] |
| Include window / tooltip skins | Present | Selected modules > Window Skins and Tooltips; these remain per profile | [Profiles source] |
| Import profile name | Missing, fits | Follow-up P1: optional name on import review; current importer generates a unique name | [Profiles source] |
| Assign imported profile to original specs | Missing, fits | Follow-up P1: optional explicit assignment import; current character's assignments stay local | [Profiles source] |
| Profile hotkey / right-click unbind | Missing, fits | Follow-up P1: saved profile binding using the existing binding surface | [Profiles source] |
| Include spec / conditional overrides | Missing, breaks consistency | Whole-profile and layout-per-spec assignment are the supported model; no per-setting condition engine | [Profiles source] |
| Include per-spec cooldown spell assignments | Missing, fits | Follow-up P2 with Cooldowns owner: optional curated spell layout sharing | [Profiles source] |
| Include Blizzard Edit Mode layout | Missing, fits | Follow-up P2: optional native layout export/import through existing setup integration | [Profiles source] |
| Warn about a different imported UI scale | Present | Warn about imported interface size, on by default; adds review text, changes no saved size | [Profiles source] |
| Match imported scale / keep own | Present | Include Appearance or leave it unchecked in Selected modules; review warns on an effective size-setting change | [Profiles source] |
| Import full account data | Missing, fits | Follow-up P2: opt-in export of named profiles and character assignments with recovery | [Profiles source] |
| Community presets / popular preset browser | Missing, fits | Follow-up P2: curated preset import; current first-run role/style presets remain available | [Profiles source] |
| Wago installer profile protocol | Missing, fits | Follow-up P2: validate public installer contract before adding an adapter | [Profile protocol] |
| Global font | Present | General > Text > Font; inherited module fonts follow it | [Fonts source] |
| Global outline: shadow / outline / thick outline | Missing, fits | Follow-up A1: one inherited default with existing module overrides preserved | [Fonts source] |
| Apply global font to all game text | Missing, fits | Follow-up A1: optional native font-object integration, separate from inherited addon typography | [Fonts source] |
| Blizzard Default / Blizzard Chat / System Default font entries | Missing, fits | Follow-up A1: explicit built-in font choices; locale fallback already exists | [Fonts source] |
| Force Latin-only font in non-Latin locales | Missing, breaks consistency | Locale fonts preserve readable translated text; no supported switch that knowingly removes its letters | [Fonts source] |
| Icon-text outlines per Action Bars / Unit Frames / CDM / Raid Frames / Bags | Missing, fits | Action Bars, Unit Frames, Cooldowns and Bags have outline rows; separate raid-aura icon outlines are follow-up A2 | [Fonts source] |
| Disable SLUG outline | Missing, fits | Follow-up A1: optional flag policy in shared font application | [Fonts source] |
| Game name font | Missing, fits | Follow-up A1: optional world-name font, with Forever CVar proof | [Fonts source] |
| Game text scale | Missing, fits | Follow-up A1: optional native game-text scale; General Text size already scales addon text | [Fonts source] |
| Module font overrides: Action Bars, Nameplates, Unit Frames, Raid Frames, CDM | Present | The modules' shared Text rows with Font, Text size and Outline | [Fonts source] |
| Resource health / power / class resource / cast text | Present | Unit Frames' player text, class-resource and cast text rows | [Fonts source] |
| Separate totem-bar text | Missing, fits | Follow-up A2 with Cooldowns owner: optional timer/label rows for a dedicated totem surface | [Fonts source] |
| Aura stack size | Present | Auras and frame aura text size controls | [Fonts source] |
| Healer mana text size | Missing, fits | Follow-up A2 with Group Frames owner: optional power text and size beside the current thin power bar | [Fonts source] |
| Aura reminder name / item-count / mana-warning fonts and sizes | Missing, fits | Follow-up A2 with aura owner: keep equivalent text on existing reminders/consumable surfaces | [Fonts source] |
| QoL FPS-counter / movement-alert / battle-res text fonts, sizes, outline | Missing, fits | Follow-up A2 with QoL owner; Data Bars already has a shared FPS readout font | [Fonts source] |
| Chat font / size / outline | Present | Chat > Text; input shares message font | [Fonts source] |
| Separate chat tab font / size | Missing, breaks consistency | Tab text keeps the shared caps role; role font can change globally | [Fonts source] |
| Separate chat input font / size | Missing, fits | Follow-up A2 with Chat owner: optional readable input size without changing panel chrome | [Fonts source] |
| Meter header / timer / history text sizes and timer font | Missing, fits | Follow-up A2 with Meters owner; current text rows cover the meter's shared type | [Fonts source] |
| Quest-tracker font and per-line sizes | Missing, fits | Follow-up A2 with Skins owner: use the shared role fonts in the existing tracker skin | [Fonts source] |
| Tooltip font size scale | Present | Tooltips > its three text role sizes; General Text size is the common multiplier | [Fonts source] |
| Enchant text size | Missing, fits | Follow-up A2 with Skins owner: native enchant-label role sizing | [Fonts source] |
| Minimap clock / zone / coordinates / FPS / difficulty text | Present | Minimap text rows; FPS on Data Bars | [Fonts source] |
| Bags count / item-level text | Present | Bags > Font, Font size and Font outline | [Fonts source] |
| Bags category / label text sizes | Missing, fits | Follow-up A2 with Bags owner: size rows for category labels using the shared roles | [Fonts source] |
| Data bar text scale | Present | Data Bars > Text size | [Fonts source] |
| Standalone native combat-text font / scale | Missing, fits | Follow-up A1: native font integration; KstyleUI Combat Text has font, size and outline now | [Fonts source] |
| Mythic+ timer/objective/threshold/spell text; keystone popup size | Not possible on Forever | `Blizzard_ChallengesUI.toc` at `9dc84f0` allows standard,mists, not camelot; no keystone system | [Fonts source] |
| Skyriding speed text and font | Not possible on Forever | `Blizzard_FrameXMLUtil.toc:52` at `9dc84f0` loads DragonridingUtil only for mainline | [Fonts source] |
| Texture previews and SharedMedia textures/fonts | Present | Shared FontPicker/TexturePicker, bundled media plus LibSharedMedia | [Textures source] |
| XP / reputation / favor bar textures | Present | Data Bars > each bar > Bar texture | [Textures source] |
| Unit-frame health / power / cast textures | Present | Unit Frames > shared Bar texture rows | [Textures source] |
| Nameplate health / cast textures | Present | Nameplates > shared Bar texture rows | [Textures source] |
| Raid / party health textures | Present | Party and Raid > shared Bar texture rows | [Textures source] |
| Absorb / heal-absorb / max-health artwork styles | Missing, breaks consistency | Existing prediction overlays use the same bar finish; independent art styles split sibling bars | [Textures source] |
| Nameplate highlight / textured bar background | Missing, breaks consistency | Target and focus marks use the shared accent and material | [Textures source] |
| Tracking / buff-bar textures | Present | Cooldowns > selected bar > Bar texture | [Textures source] |
| Class resource / cast bar textures | Present | Unit Frames > Bar texture; existing class resource shares the player style | [Textures source] |
| Standalone GCD bar texture | Missing, fits | Follow-up A2 with Unit Frames owner: optional GCD bar using shared BarRows | [Textures source] |
| Chat background / tab textures | Missing, breaks consistency | Chat uses the same global card material and tab finish as the rest of the UI | [Textures source] |
| Movement alert / cursor / GCD ring / cast ring textures | Missing, breaks consistency | A cursor/effects texture library adds separate visual styles instead of the shared kit | [Textures source] |
| Meter bar / breakdown / spell-history textures | Present | Meters > Bar texture, shared across its views | [Textures source] |
| Data-bar background texture | Missing, breaks consistency | Data Bars uses the global card material | [Textures source] |
| Minimap / icon / popup / tooltip border style pickers | Missing, breaks consistency | Chrome follows the global material; no independent border zoo | [Textures source] |
| Mythic timer / forces / spell bar textures | Not possible on Forever | `Blizzard_ChallengesUI.toc` excludes camelot at `9dc84f0` | [Textures source] |
| Dragonriding bar texture | Not possible on Forever | `Blizzard_FrameXMLUtil.toc:52` restricts DragonridingUtil to mainline | [Textures source] |
| Shared accent: class / custom colour | Present | General > Accent colour and Custom accent | [General source] |
| Dark Mode independently for Unit Frames / Raid Frames / class resource | Missing, breaks consistency | Separate module themes make siblings look unrelated; one shared material is the rule | [Colours source] |
| Dark Mode fill colour and opacity | Missing, breaks consistency | Uses shared global material and element opacity, rather than a second dark-mode theme | [Colours source] |
| Dark Mode background colour and opacity | Missing, breaks consistency | Same shared material; element combat/idle opacity already exists | [Colours source] |
| Class / resource / power / power-background colour darkening | Missing, fits | Follow-up A3: global palette modifiers, preserving semantic colour families | [Colours source] |
| Class palette swatches: Warrior, Paladin, Hunter, Rogue, Priest, DK, Shaman, Mage, Warlock, Monk, Druid, DH, Evoker | Missing, fits | Follow-up A3: shared supported-class palette, never per-element copies | [Colours source] |
| Power palette swatches: Mana, Rage, Focus, Energy, Runic Power, Fury, Astral Power, Insanity, Maelstrom, Ebon Might | Missing, fits | Follow-up A3: shared supported-power palette with safe fallback for absent types | [Colours source] |
| Class-resource swatches: Combo Points, Runes, Soul Shards, Holy Power, Arcane Charges, Icicles, Chi, Essence, Soul Fragments | Missing, fits | Follow-up A3: shared palette only for resources the client exposes | [Colours source] |
| Each class / power / resource swatch Reset | Missing, fits | Follow-up A3: reset shared palette entry to its semantic default | [Colours source] |
| Apply palette section to all profiles | Missing, fits | Follow-up A3: explicit optional palette sharing; default remains per profile | [Colours source] |
| Pull palette section from another profile | Missing, fits | Follow-up A3: copy palette values without linking unrelated settings | [Colours source] |
| Whole game UI scale | Present | Equivalent: General Interface size and Auto; intentionally scales only KstyleUI's root | [General source] |
| Options theme and custom background tint | Missing, breaks consistency | The settings window uses the same chosen global material and accent as every other window | [General source] |
| Options language override | Missing, fits | Follow-up W1: optional language override through the existing locale service | [General source] |
| Hide pause-menu settings button | Missing, fits | Follow-up W1: optional native menu entry through the existing Options opener | [General source] |
| Hide pause-menu Unlock Mode button | Missing, fits | Follow-up W1: optional native menu entry through the existing Layout opener | [General source] |
| Show minimap settings button | Present | Minimap drawer / KstyleUI addon compartment opens Options | [General source] |
| Disable sidebar sync icons / only hide fully synced | Missing, breaks consistency | Sync icons belong to the excluded per-setting override system | [General source] |
| Remember search picks | Missing, fits | Follow-up W1: small optional search history using existing rows | [General source] |
| Clear search-pick history | Missing, fits | Follow-up W1 with remembered search picks | [General source] |
| Search all modules | Present | Window header search, translated player synonyms, every lazy schema | [Panel source] |
| Search current module | Missing, fits | Follow-up W1: optional current-page filter on the same search field | [Panel source] |
| Module categories / sidebar sections | Present | Category rail, module pages and their section links | [Panel source] |
| Collapse sidebar groups | Missing, fits | Follow-up W1: optional collapsed groups, no second navigation system | [Panel source] |
| Enable/disable module from sidebar | Present | Equivalent module page Enable toggle | [Panel source] |
| Live preview | Present | Shared live preview pane and selected module's real preview | [Panel source] |
| Resize / scale Options window | Present | General > Window size and opacity; same shared deferred element rows as Elements | [Panel source] |
| Move Options window | Present | Drag header; position saved by Options.Window | [Panel source] |
| Collapse Options window | Missing, fits | Follow-up W1: optional compact header state with a clear restore button | [Panel source] |
| Reset module settings | Present | Reset footer with confirmation | [Panel source] |
| Reload UI button | Present | Existing reload dialog after settings that require it; font and appearance changes apply live | [Panel source] |
| Close / Done / Escape | Present | Close button, own Escape handler and `/kstyle` toggle | [Panel source] |
| CPU metric picker: session / recent / encounter / last / peak | Missing, fits | Follow-up W2: opt-in diagnostic readout, updated only while visible | [Panel source] |
| Patch notes / What's New | Missing, fits | Follow-up W2: optional release-note link or data, built on opening | [Panel source] |
| Credits / EUI Legends | Present | About > Credits | [Panel source] |
| Developer suppress-Lua-errors toggle | Missing, breaks consistency | Hiding errors would undermine the project's fatal functional checks; existing devlog retains failures | [General source] |

Follow-up batches: **P1** named imports, imported assignments and profile hotkeys; **P2** optional native/CDM/account/preset exchange; **A1** inherited outline and native font integration; **A2** coordinate missing module text rows with their owners; **A3** one shared class/power/resource palette; **W1** search/navigation and native menu conveniences; **W2** optional diagnostics/release notes. Combined with Layout L1/L2 these exceed a 600-line batch and several require files outside this task's allowlist. This PR prioritises mover interactions, height matching and offsets, several-module sharing including appearance, import-size review and discoverable window sizing. Missing, fits means deferred work, never an unsupported Forever claim.

Defaults retain today's fonts, textures, colours, geometry, dim grid, ten-pixel Shift nudge, Alt-scroll cycling and exact width matching. Height matching starts off; match adjustments start at zero. Selected modules starts with none checked and is only used when explicitly chosen. Import-size warnings start on because explaining a size change before application is expected review behaviour; this adds no visual change to the HUD. The v0.2.8-shaped profile regression omits every new field, keeps its explicit font/scale/position and verifies the old interactions. No schema is built on reload, and no new frame/event/update handler is registered.

API proof: Forever `9dc84f0d3bbae1768ac3405b3716000bd93eda06`, under `Interface/AddOns/Blizzard_APIDocumentationGenerated/`: `InputDocumentation.lua` for guarded modifier predicates; `SimpleScriptRegionAPIDocumentation.lua` for size getters; `SimpleScriptRegionResizingAPIDocumentation.lua` for setters; `SimpleRegionAPIDocumentation.lua` and `SimpleTextureBaseAPIDocumentation.lua` for existing grid alpha/colour painting. Layout's safe measurement and combat-queue paths are reused; sharing and warnings use validated local profile data and introduce no game API. Unsupported rows above cite the actual TOC game filters, not an inferred missing API. Existing specialization assignment uses the guarded spec-ID APIs and a role fallback; the precise IDs/names returned by the Forever client, including a primary/secondary talent-group switch, remain an in-game check. The Profiles render deliberately shows the role fallback, while `test-spec-layouts` exercises supplied spec IDs.

Verification: `test-core-parity`, `test-profiles-scopes`, `test-spec-layouts`, Options/Layout/Appearance/Scale/Store scoped tests and PUC Lua 5.1 `test-perf-path-budgets`. `parity_core` with `RENDER_CORE_PAGE=profiles`, `sharing`, `appearance`, `window`, `layout`, `links` or `mode` drives the actual window/movers; `RENDER_CORE_KEY` chooses a visible section. Renders and logs go to `C:/Users/leeba/.cache/kstyleui-evidence/parity-core/`.

[Profiles source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Profiles_Options.lua
[Profile protocol]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUI_Profiles.lua
[General source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI__General_Options.lua
[Fonts source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Fonts_Options.lua
[Textures source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Textures_Options.lua
[Colours source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Colors_Options.lua
[Panel source]: https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUI_Panel.lua

The settings window: category rail, search, option cards, live preview and the Layout Mode button. It is registered as a canvas category in Blizzard's Settings panel and opened by `/kstyle`.

| Field | Value |
| --- | --- |
| Module name | `Options`: its switch in `Core/Features.lua` |
| Approach | Our own window |
| Loads | On demand: the settings window when the player opens it |
| Files | `KstyleUI_Options.toc` lists `Options.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Every page is built from the schemas modules declare through `KstyleUI.Options.Register` and from the elements registered with `KstyleUI.Layout.Register`, so search covers every setting.
- The window follows `docs/design/mockups/04_settings_druid.jpg` and is built entirely from `KstyleUI.Widgets`.
- Option help text is one short sentence, under 100 characters.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- The addon is load-on-demand: the core loads it the first time the player opens the settings window, so it costs nothing before then.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## How it opens

The core's `Options.Open(page)` loads this addon with `C_AddOns.LoadAddOn` the first time, and `Window.lua` hands it `Window.Show` through `Options.SetWindow`. `/kstyle`, the KstyleUI category in Blizzard's Settings panel and the addon compartment all call `Options.Open` (see `Core/OptionsEntry.lua` and `docs/core-services.md`).

- `Show(page)` builds the window on first use, opens it on `page`, and raises it. With no page, a closed window opens on Tasks: six 36-unit links with destination help and the shared typography preview, to Change HUD, Choose role (the existing setup entry), Readable text, Bind keys, Healing clicks and Existing addons. General > Start with tasks restores the previous last-page opening when off. Page ids include `Tasks`, `General`, `Elements`, `Profiles`, `About` and module names, in any letter case. General section names also open General.
- `Show()` with no page closes an open window, so `/kstyle` toggles it.
- The window plays the kit panel's open motion: alpha 0 to 1 over `panelOpen` while it rises `panelRise` with a `panelOvershoot` overshoot. It closes with a `panelClose` fade.
- Escape closes it through `Widgets.EscapeCloses`, its own key handler. It never touches `UISpecialFrames`. Escape in the search field only clears the field's focus.
- It sits in the `HIGH` strata as a top-level frame, so dialogs (`DIALOG`), dropdown menus (`FULLSCREEN_DIALOG`) and the colour picker show above it, and it shows over Blizzard's Settings panel.
- It registers with Layout as `Options.Window` (module `Options`, label "Settings window"), resizable from 880 by 520 to 1800 by 1040 units and scalable. Dragging the header saves a `CENTER` position through `Layout.Set`. When its own scale changes, `LayoutChanged` makes the kit restyle so borders stay whole pixels.

General uses the live typography sample for Text and the other appearance sections; only Existing addons selects the boss lane preview when a lane is enabled. Scrolling between sections updates the preview.

## Layout of the window

General > Settings window contains the presentation choices, all on by default: player-word search, readable settings text, larger top-aligned previews (maximum 1.6), slim bright switches (20 units, 65% accent mix), aligned headings and 180x90 ornament samples. Turning each off restores its previous presentation. The reading floor is reapplied when a window opens at a saved scale or changes scale; `test-options-polish` reproduces the old 7.8 px label at 0.65 and checks the fix. Search synonyms are translated along with labels and help.

| Part | What it is |
| --- | --- |
| Header | The logo, the spaced title, the search field with its clear button, and the close button. The header is the drag handle. |
| Rail | `Rail.lua`: a `ScrollList` of pages, and under the open page its sections. The selected page has an accent bar and an accent wash that fades to the right. A section row is shorter (26 units) and indented; the section whose header is on screen, or last scrolled past, carries a 2-unit accent tick. Clicking a section scrolls the rows so its header sits at the top. The rail lists no sections while a search is on. |
| Rows | A `ScrollList` of 48-unit rows (`Rows.lua`). Each row is a header, a note, or a label with help text and one kit control on the right, 220 units wide. |
| Preview | `Preview.lua`: a `buttonFill` tile captioned "Live preview". |
| Footer | **Layout Mode** (primary) and **Reset** under the preview. |

## Pages

`Pages.List()` builds the pages each time the window opens or the profile changes. A page's rows are rebuilt each time it renders, so they always show the current values.

| Page | Rows |
| --- | --- |
| General | The schemas of the core's `HudStyle` section (the HUD style pictures), its `Appearance` section and, when it is registered, the `Widgets` section, in that order. The preview is a kit sample (status bar, switch, slider, button) that follows accent, font, size and motion changes. |
| Elements | The `Layout` section's schema (grid and snapping) when Layout registers one, then every element from `Layout.Elements()`, grouped under its module. |
| One per module | Each module in `Options.List()` or `Modules.List()`, except `Options` and the General sections, in the spec's module order and then by name. A module's page starts with a header named after the module and an **Enable** switch unless its schema has an `enabled` row, then its schema rows, then **Positions and sizes** for its own elements. A schema whose first row is a level-1 header with the module's own name (`Unit frames` under `Unit Frames`) and no `showWhen` or `disableWhen` shares that header with the switch instead of repeating it; a conditional header keeps its own row, so it still hides its section. |
| Profiles | Active profile, specialization profiles and layouts (or assigned-role fallback), new, copy, rename, delete, reset, selected-module/appearance sharing, optional layout, import size warning and recovery, and every known character's profile. Assignments default on, start on the current profile, and switch after combat. |
| About | Version, commands, the smoke checks and first-run setup buttons, and credits. |

### Element rows

Every element gets the same rows, with no module code: **Shown** (from `Layout.SHOWN_OPTIONS`), **Anchor** (`Layout.ANCHOR_OPTIONS`), **X offset** and **Y offset** (plus or minus the root's size, from `Layout.RootSize()`), **Width** and **Height** for a `resizable` element within its `minWidth` to `maxWidth` and `minHeight` to `maxHeight`, **Scale** for a `scalable` element (`Layout.SCALE_MIN` to `SCALE_MAX`), **Opacity in combat** and **Opacity out of combat** (0 to 100%), **Strata** (`Layout.STRATA_OPTIONS`) and **Reset this element** (`Layout.Reset`). Without Layout's option lists the page uses its own copies with the same values. Each change goes through `Layout.Set(key, field, value)`. The settings window's own element has no **Shown** row and keeps at least 25% opacity, so it cannot hide itself for good. Its sliders, and General's **Interface size**, apply when the mouse is released, so the window does not resize under the pointer.

### Schema rows

Each schema row becomes a row bound to `Options.Read` and `Options.Write`, so every change fires `SettingChanged`. An `order` row expands into one row per entry.

| Row | Control |
| --- | --- |
| `header` | Upper-case caption with a fading rule above. Element names are second-level headers with an accent mark. |
| `toggle` | `Widgets.Toggle` |
| `slider` | `Widgets.Slider` with the row's `min`, `max` and `step`; a row with `shown` paints `shown(stored)` instead of the stored value |
| `dropdown` | `Widgets.Dropdown`. A stored value that no option holds is listed under its raw value, so it still shows. |
| `order` | One row per ordered entry, with a toggle, Left / Centre / Right dropdown and up/down buttons built from the kit. The end buttons are disabled; moving past either end does nothing. |
| `segmented` | `Widgets.Tabs` at the control width: one tab per option, the stored value's tab underlined. For a short list of choices that should all show at once, such as the Widgets **Ornaments** level (Off, Subtle, Full). A disabled row disables every tab. |
| `pictures` | Up to three picture cards, as many to a row as keep each picture 200 units wide and the rest on a second row, at the control width on the button body, each its option's `picture` (a 2:1 texture) over its label; the stored value's card has the `accent` edge and its label in `textEmphasis`, a click saves that option. For a choice that reads best as a picture, such as the **HUD style** at the top of General (Frames or Orbs). A disabled row disables both cards. |
| `color` | `Widgets.ColorSwatch` and the colour as `#RRGGBB`. Rows with `hasAlpha` keep the alpha. |
| `font`, `texture` | `Widgets.FontPicker`, `Widgets.TexturePicker`: KstyleUI's media, then LibSharedMedia's |
| `text` | `Widgets.EditBox`. Enter saves; `maxLetters` limits the length. |

`showWhen(settings)` and `disableWhen(settings)` get `Store.Module(module)`. A row whose `showWhen` is false is left out. A header whose `showWhen` is false hides its whole section, up to the next header of the same or a higher level. A header with no visible row under it is left out. A condition that raises an error counts as shown and enabled, and is logged once. Disabled rows grey their label, help and control.

An `order` row's default and stored value are a complete ordered list of `{ id = "clock", shown = true, zone = "centre" }` records. Zones are `left`, `centre` and `right`. Its `options` list declares each id as `{ value = "clock", label = L["Clock"], rows = { ... } }`; values must be unique and each must appear once in the stored list. Optional `rows` are ordinary schema rows, with their own keys, help and conditions. They follow their entry as it moves and show only while it is switched on, with `showWhen` filtering them further. Reset includes these child settings. Entry names remain searchable while switched off, and the expanded rows use the same virtual list as other controls. Right-click resets the whole ordered setting, including order, visibility and zones.

`Tools/render/scenes/options_order.lua` shows sample modules without changing the live DataBars schema. Render it through `Tools/render/shoot.sh options_order`; `RENDER_ORDER_BEFORE=1` shows the existing DataBars page for comparison.

### Search

The search field matches every visible row on every page. The query splits on spaces; each word must appear, as plain text and ignoring case, in the row's page name, section names, label or help text. Results show under the page and section they come from, and their controls work as they do on the page. Clicking a rail entry or the clear button ends the search.

A row with a `scope` belongs to one choice of a picker, such as the unit frames' **Frame to customise** or the action bars' **Bar to edit**. Search runs its `showWhen` as if the picker held that choice, and leaves the picker as it is, so it finds the rows of every frame and bar. Each result stays bound to its own key, such as `target.castbarTexture`, and shows under its own section, such as "Target: cast bar". The row's other conditions still apply: a custom colour row stays hidden while its colour source is not custom. `test-options-search.lua` checks that search finds every row the unit frames and action bars pages can show.

### Live preview

A schema may carry `preview = function(parent) -> frame` (see `Options.Preview` in `docs/core-services.md`). The window calls it once, the first time the module's page opens, with the preview tile's content frame, and anchors the frame to fill it unless the builder placed it. After any of that module's settings changes it calls `frame:Refresh()` when the frame has one. A builder that fails or returns no frame is logged, and the page shows the placeholder.

### Reset

**Reset** asks first, then puts the page's schema settings back to their defaults through `Options.Write`, and resets the page's elements through `Layout.Reset`. It never changes a module's `enabled` switch. On Elements it calls `Layout.ResetAll`. Profiles and About have nothing to reset.

## Why

- **Rows are data first.** `Model.lua` turns schemas, elements and profile actions into plain item tables before anything is drawn. Visibility, section pruning and search are pure functions over those tables, so `test-options-model.lua` checks them without frames, and the window draws whatever list it is given.
- **Sections come from the rows.** `Model.Sections(items)` lists the level-1 headers of the visible rows with their indices, and `Rail.Entries(pages, selected, sections)` weaves them under the selected page, dropping one that repeats the page's name. Both are pure, so the tests check them without a window. The window tracks the current section from the first row on screen each time the rows scroll, and a section click asks the rows for `ScrollToIndex(index, false, "TOP")`. A page too short to put a header at the top scrolls as far as it can, and the mark stays on the section the first row belongs to.
- **The gallery shows the real pages.** `gallery_options.lua` loads KstyleUI_UnitFrames as the game loads it, so `kstyle_options_window.png` is the Unit Frames page from the module's own schema (over 90 settings for the picked frame), and `gallery_options_modules.lua` does the same for Party and Raid, Nameplates, Action Bars and Cooldowns. Before this, the gallery drew a seven-row stand-in schema, and reviewers took it for the real page.
- **One row height.** The rows use the kit's virtualised `ScrollList`, which needs a fixed row height. 48 units fits a label, a help line and the tallest control (the slider with its readout and range). Only the rows on screen exist, and each row makes a control kind the first time it needs one.
- **Refresh after any change.** A setting can change another row's `showWhen`, and a profile action changes the profile list, so every change queues one refresh on the next frame. The refresh rebuilds the visible list and keeps the scroll position.
- **Profile pickers.** Copy and Delete are dropdowns whose first entry is a "Choose a profile" placeholder; choosing a profile asks for confirmation. A dropdown cannot hold no value, so the placeholder is a real option that does nothing.
- **Layout Mode closes the window.** The window would cover the elements being moved. The button is disabled in combat, because Layout Mode opens only out of combat.
