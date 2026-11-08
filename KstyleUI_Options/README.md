# KstyleUI_Options

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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Options.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## How it opens

The core's `Options.Open(page)` loads this addon with `C_AddOns.LoadAddOn` the first time, and `Window.lua` hands it `Window.Show` through `Options.SetWindow`. `/kstyle`, the KstyleUI category in Blizzard's Settings panel and the addon compartment all call `Options.Open` (see `Core/OptionsEntry.lua` and `docs/core-services.md`).

- `Show(page)` builds the window on first use, opens it on `page`, or on the last page this session, and raises it. `page` is a page id: `General`, `Elements`, `Profiles`, `About` or a module name, in any letter case. `Appearance`, `Icons` and `Widgets` open General.
- `Show()` with no page closes an open window, so `/kstyle` toggles it.
- The window plays the kit panel's open motion: alpha 0 to 1 over `panelOpen` while it rises `panelRise` with a `panelOvershoot` overshoot. It closes with a `panelClose` fade.
- Escape closes it through `Widgets.EscapeCloses`, its own key handler. It never touches `UISpecialFrames`. Escape in the search field only clears the field's focus.
- It sits in the `HIGH` strata as a top-level frame, so dialogs (`DIALOG`), dropdown menus (`FULLSCREEN_DIALOG`) and the colour picker show above it, and it shows over Blizzard's Settings panel.
- It registers with Layout as `Options.Window` (module `Options`, label "Settings window"), resizable from 880 by 520 to 1800 by 1040 units and scalable. Dragging the header saves a `CENTER` position through `Layout.Set`. When its own scale changes, `LayoutChanged` makes the kit restyle so borders stay whole pixels.

## Layout of the window

| Part | What it is |
| --- | --- |
| Header | The logo, the spaced title, the search field with its clear button, and the close button. The header is the drag handle. |
| Rail | `Rail.lua`: a `ScrollList` of pages. The selected page has an accent bar and an accent wash that fades to the right. |
| Rows | A `ScrollList` of 48-unit rows (`Rows.lua`). Each row is a header, a note, or a label with help text and one kit control on the right, 220 units wide. |
| Preview | `Preview.lua`: a `buttonFill` tile captioned "Live preview". |
| Footer | **Layout Mode** (primary) and **Reset** under the preview. |

## Pages

`Pages.List()` builds the pages each time the window opens or the profile changes. A page's rows are rebuilt each time it renders, so they always show the current values.

| Page | Rows |
| --- | --- |
| General | The schemas of the core's `Appearance` section and, when they are registered, the `Icons`, `IconsColour` and `Widgets` sections, in that order. The preview is a kit sample (status bar, switch, slider, button) that follows accent, font, size and motion changes. |
| Elements | The `Layout` section's schema (grid and snapping) when Layout registers one, then every element from `Layout.Elements()`, grouped under its module. |
| One per module | Each module in `Options.List()` or `Modules.List()`, except `Options` and the General sections, in the spec's module order and then by name. A module's page starts with an **Enable** switch unless its schema has an `enabled` row, then its schema rows, then **Positions and sizes** for its own elements. |
| Profiles | Active profile, new, copy from, rename, delete, reset, export, import, and every known character's profile. |
| About | Version, commands, the smoke checks and first-run setup buttons, and credits. |

### Element rows

Every element gets the same rows, with no module code: **Shown** (from `Layout.SHOWN_OPTIONS`), **Anchor** (`Layout.ANCHOR_OPTIONS`), **X offset** and **Y offset** (plus or minus the root's size, from `Layout.RootSize()`), **Width** and **Height** for a `resizable` element within its `minWidth` to `maxWidth` and `minHeight` to `maxHeight`, **Scale** for a `scalable` element (`Layout.SCALE_MIN` to `SCALE_MAX`), **Opacity in combat** and **Opacity out of combat** (0 to 100%), **Strata** (`Layout.STRATA_OPTIONS`) and **Reset this element** (`Layout.Reset`). Without Layout's option lists the page uses its own copies with the same values. Each change goes through `Layout.Set(key, field, value)`. The settings window's own element has no **Shown** row and keeps at least 25% opacity, so it cannot hide itself for good. Its sliders, and General's **Interface size**, apply when the mouse is released, so the window does not resize under the pointer.

### Schema rows

Each schema row becomes one row bound to `Options.Read` and `Options.Write`, so every change fires `SettingChanged`.

| Row | Control |
| --- | --- |
| `header` | Upper-case caption with a fading rule above. Element names are second-level headers with an accent mark. |
| `toggle` | `Widgets.Toggle` |
| `slider` | `Widgets.Slider` with the row's `min`, `max` and `step` |
| `dropdown` | `Widgets.Dropdown`. A stored value that no option holds is listed under its raw value, so it still shows. |
| `color` | `Widgets.ColorSwatch` and the colour as `#RRGGBB`. Rows with `hasAlpha` keep the alpha. |
| `font`, `texture` | `Widgets.FontPicker`, `Widgets.TexturePicker`: KstyleUI's media, then LibSharedMedia's |
| `text` | `Widgets.EditBox`. Enter saves; `maxLetters` limits the length. |

`showWhen(settings)` and `disableWhen(settings)` get `Store.Module(module)`. A row whose `showWhen` is false is left out. A header whose `showWhen` is false hides its whole section, up to the next header of the same or a higher level. A header with no visible row under it is left out. A condition that raises an error counts as shown and enabled, and is logged once. Disabled rows grey their label, help and control.

### Search

The search field matches every visible row on every page. The query splits on spaces; each word must appear, as plain text and ignoring case, in the row's page name, section names, label or help text. Results show under the page and section they come from, and their controls work as they do on the page. Clicking a rail entry or the clear button ends the search.

A row with a `scope` belongs to one choice of a picker, such as the unit frames' **Frame to customise** or the action bars' **Bar to edit**. Search runs its `showWhen` as if the picker held that choice, and leaves the picker as it is, so it finds the rows of every frame and bar. Each result stays bound to its own key, such as `target.castbarTexture`, and shows under its own section, such as "Target: cast bar". The row's other conditions still apply: a custom colour row stays hidden while its colour source is not custom. `test-options-search.lua` checks that search finds every row the unit frames and action bars pages can show.

### Live preview

A schema may carry `preview = function(parent) -> frame` (see `Options.Preview` in `docs/core-services.md`). The window calls it once, the first time the module's page opens, with the preview tile's content frame, and anchors the frame to fill it unless the builder placed it. After any of that module's settings changes it calls `frame:Refresh()` when the frame has one. A builder that fails or returns no frame is logged, and the page shows the placeholder.

### Reset

**Reset** asks first, then puts the page's schema settings back to their defaults through `Options.Write`, and resets the page's elements through `Layout.Reset`. It never changes a module's `enabled` switch. On Elements it calls `Layout.ResetAll`. Profiles and About have nothing to reset.

## Why

- **Rows are data first.** `Model.lua` turns schemas, elements and profile actions into plain item tables before anything is drawn. Visibility, section pruning and search are pure functions over those tables, so `test-options-model.lua` checks them without frames, and the window draws whatever list it is given.
- **One row height.** The rows use the kit's virtualised `ScrollList`, which needs a fixed row height. 48 units fits a label, a help line and the tallest control (the slider with its readout and range). Only the rows on screen exist, and each row makes a control kind the first time it needs one.
- **Refresh after any change.** A setting can change another row's `showWhen`, and a profile action changes the profile list, so every change queues one refresh on the next frame. The refresh rebuilds the visible list and keeps the scroll position.
- **Profile pickers.** Copy and Delete are dropdowns whose first entry is a "Choose a profile" placeholder; choosing a profile asks for confirmation. A dropdown cannot hold no value, so the placeholder is a real option that does nothing.
- **Layout Mode closes the window.** The window would cover the elements being moved. The button is disabled in combat, because Layout Mode opens only out of combat.
