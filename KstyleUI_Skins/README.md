# KstyleUI_Skins

Character sheet, spellbook and talents, quest log and objective tracker, world map, game menu, group finder, mail, merchant, trainer, professions, social windows, Legacy, loot, popups and ready check, and the windows of RestedXP Guides.

| Field | Value |
| --- | --- |
| Module name | `Skins`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin, one window per task |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Skins.toc` lists `Skins.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Tests | `Tools/regression/test-skins-*.lua`, through `Tools/regression/skins_env.lua` |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Load order

`Skins.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Style.lua` | `ns.Style`: the shared look settings and the functions that apply them |
| `Parts.lua` | `ns.Parts`: quality rims and accent lines drawn on KstyleUI's own child frames |
| `Lumen.lua` | `ns.Lumen`: the Lumen pieces the skins share (gilt and quest gold, the gem, the section cap, the ring check box), and the one place that switches to S1's names |
| `Registry.lua` | `ns.Skins`: the skin registry |
| Part A, B and C sections | One file per skin. Each part adds its `Script` lines between its own two comment lines, so parallel branches never edit the same lines. |
| Other addons section | One folder per addon whose windows the module restyles, such as `Addons/RestedXP/`, between its own two comment lines. |
| `Preview.lua` | `ns.Preview.Build`, the settings window's live preview |
| `Module.lua` | Registers the module, its defaults and its settings. It must load last: it reads every skin the files above added. |

## Adding a skin

A skin file calls `ns.Skins.Add(def)` at load and does nothing else at load:

```lua
local _, ns = ...

ns.Skins.Add({
	key = "mail",                        -- lower camel; the window's settings live under it
	label = KstyleUI.L["Mail"],          -- the switch's label in the settings
	help = KstyleUI.L["Restyles the mailbox and the send mail window."],  -- under 100 characters
	addon = "Blizzard_UIPanels_Game",    -- the Blizzard addon that creates the window; nil if the game's own interface does
	frame = "MailFrame",                 -- the window's global name; the skin waits for its first show
	defaults = { borders = true },       -- optional: the skin's own settings, read with ns.Skins.Setting("mail", "borders")
	rows = {                             -- optional: settings rows for them, keyed relative to the skin
		{ type = "toggle", key = "borders", label = KstyleUI.L["Item borders"], help = KstyleUI.L["Colours item borders by quality."] },
	},
	Apply = function(def)                -- runs once, out of combat, the first time the window shows
		KstyleUI.Skin.Window(MailFrame)
	end,
})
```

| Field | Rule |
| --- | --- |
| `key` | A lower-camel name, unique, at most 32 characters. `text`, `bars`, `accent` and `enabled` are reserved. |
| `label`, `help` | Required. `help` is one sentence under 100 characters. |
| `addon` | The Blizzard addon whose `ADDON_LOADED` creates the window, such as `Blizzard_PlayerSpells`. Leave it out for a window the game's interface creates before any addon loads. |
| `frame` | The window's global name. The skin applies on the window's first `OnShow`, or at once if it is open. Without `frame`, the skin applies as soon as the addon has loaded. |
| `Apply(def)` | Required. Runs once per session through `KstyleUI.Call`, so an error is reported and logged and other skins still apply. |
| `OnSetting(def, field, value)` | Optional. Runs after one of the skin's own settings changes, once the skin has applied: `field` is the key without the skin's prefix, such as `"borders"`. After a profile change it runs once with `field` `nil`, because any setting may have changed. |
| `sweep`, `sweepSkip` | Optional. After `Apply`, the registry sweeps the window (`Style.Sweep` below): every Blizzard font string under `frame` takes the skin's body face. `sweep = false` keeps Blizzard's fonts (the tracker, which paints Blizzard's font objects itself). `sweepSkip` lists dotted paths under the window whose subtrees the sweep leaves alone: the talent tree's nodes, the world map's canvas, the quest log's parchment details. A skin whose windows are several globals (popups, loot rolls, the open letter) sweeps each one from its `Apply`. |
| `OnSwitch(def, on)` | Optional. Runs once the skin has applied, each time the window's switch or the module turns off (`false`) or on again (`true`), and after a profile change that turns the switch. `Apply` covers the first switch on. Use it for changes a skin can undo, such as another addon's setting; frames keep their skin until reload either way. |
| `defaults`, `rows` | Optional. `rows` follow the `Options.Register` rules with keys relative to the skin; a bad row stops the module from loading with the row's key in the error. A row's `showWhen` and `disableWhen` get the skin's own settings table. Every row hides while the window's switch is off. Do not put `enabled` in `defaults`: the registry adds the switch. |

The registry adds the window's switch, `<key>.enabled`, default on, to the module's settings page, under the Windows header in the order `Skins.xml` loads the files.

### When a skin applies

1. `Enable` arms every skin whose switch is on.
2. A skin whose `addon` has not loaded waits for that addon's `ADDON_LOADED`. `C_AddOns.IsAddOnLoaded` answers the check; on a client without it, a window whose `frame` already exists counts as loaded.
3. Once the addon has loaded, the skin hooks the window's `OnShow` and applies on its first show, or at once if the window is open.
4. In combat the skin waits for `KstyleUI.Combat.Queue`.
5. Each step logs to the devlog: `<key>: waits for <addon> to load`, `<key>: applied`, `<key>: Apply failed`, or `<key>: <frame> is missing on this client`.

`/kstyle test` adds one line, `skin windows`, listing the windows that are applied, waiting (for their addon or their first show), switched off, or failed. It fails when any skin's `Apply` raised an error.

Switching a window on while the module runs arms it at once. Switching off a window that is already skinned asks for a reload, because Blizzard's frames keep the skin. `Disable` stops arming; the hooks it left behind do nothing until `Enable` runs again.

### Functions

| Function | Behaviour |
| --- | --- |
| `ns.Skins.Add(def) -> def` | Adds a skin. Raises an error for a bad definition, and for any call after `Module.lua` has registered the module. |
| `ns.Skins.List() -> { def, ... }`, `Get(key) -> def` | The skins in load order. |
| `ns.Skins.Setting(key, field) -> value` | A skin's setting in the active profile, or its default when the saved value is missing or of the wrong type. |
| `ns.Skins.IsOn(key)`, `IsApplied(key)` | The window's switch, and whether its skin has run this session. |

## Grades

Every piece a skin draws takes one of the three grades `~/.local/share/kstyleui-handoff/THEME_SPEC.md` measured on the owner's mockup (see the Chrome table in [`Core/Widgets/README.md`](../Core/Widgets/README.md)). `test-grades.lua` fails on a skin or core skin helper that asks for the grey `raised` tile, which the mockup does not have, and `test-skins-grades.lua` checks each piece's grade.

| Piece | Grade | Chrome |
| --- | --- | --- |
| A window (`Skin.Window`, the game menu, the world map, popups, the friends dialogs) | window | `window` shape, `surface` fill, shadow: the chat's and tracker's 12-unit chamfer |
| A toast the size of a unit frame (the loot rolls) | panel | `panel` shape, `surface` fill, shadow |
| Rows, insets, list bodies, the quest log, the navigation bar, the battle tag bar | panel | `tile` shape, `surface` fill, no shadow; the edge lights to the accent for a selection |
| Controls: buttons, edit boxes, check boxes, dropdowns, scrolling text boxes, the bottom tabs' strip (inside the window's glass, which `Parts.Dock` grows to hold it) | button | `tile` shape, `buttonFill` body, no shadow: the design kit's dark input |
| Item and icon slots, side tabs | button | `Parts.Rim`, the `IconChrome` body with the quality or accent rim |
| Bars (`Kit.Bar`, `Parts.FillBar`, `Kit.MirrorBar`, `Kit.RankBar`) | bar | `tile` shape, `surface` fill, `edgeBar` line, no shadow |

Render: `python3 Tools/render/gallery.py` draws every window the module skins (`Tools/render/scenes/gallery_skins_<window>.lua`, built from `Tools/regression/skins_windows.lua`) over the clean plate into the frame gallery, each window beside the mockup element that shares its grade.

## Shared look

Every skin styles its text, bars and accent lines through `ns.Style`, so the settings below apply to every window:

| Setting | Default | Row |
| --- | --- | --- |
| `text.font` | `appearance`: the Appearance page's face | dropdown: the interface font, then every font `Widgets.MediaOptions("font")` lists |
| `text.size` | 1 | slider, 0.8 to 1.5: multiplies each text role's size |
| `text.outline` | `shadow` | dropdown: soft shadow, thin outline, thick outline |
| `bars.texture` | the Glass bar | texture |
| `bars.color` | `reaction` | dropdown: standing or reaction (Blizzard's colour, lifted by `Theme.Brighten`), class colour, custom colour |
| `bars.customColor` | the kit accent | colour, shown for a custom bar colour |
| `bars.fill` | `left` | dropdown: fill from the left or from the right |
| `accent.source` | `appearance` | dropdown: the interface accent, the class colour, or a custom colour |
| `accent.color` | the kit accent | colour, shown for a custom accent |

| Function | Behaviour |
| --- | --- |
| `Style.Text(fontString, role, colorName)` | `Style.ApplyFont` at the role's size, and a token colour. If no face loads, the text takes the `GameFontHighlight` font object, as the core widget kit's text does. |
| `Style.ApplyFont(object, role, size) -> ok` | The role's face (`Tokens.Font`, or the chosen face) and edge on a font string or a font object, at `size` (default: the role's size times the text size). A face the game cannot load falls back to the KstyleUI face, then to the face of `GameFontHighlight`, the font the core widget kit falls back to, at the same size; each fallback logs once. Returns `false` when no face loaded, and then leaves the object's font alone. |
| `Style.StatusBar(bar)` | The bar texture, fill direction and colour on a status bar. It hooks the bar's `SetStatusBarColor`, so a colour Blizzard sets later is restyled too. A secret colour passes through untouched. |
| `Style.BarColor(r, g, b)`, `Style.BarTexture()`, `Style.ReverseFill()` | The pieces, for bars that are not status bars. |
| `Style.Accent() -> r, g, b`, `Style.TintAccent(region, alpha)` | The module's accent. |
| `Style.Sweep(frame, opts) -> count` | Walks `frame` and its children (ten levels deep, skipping forbidden frames and the subtrees in `opts.skip`) and gives every Blizzard font string the skin's body face: a string with its own size keeps it times the text size setting, at no less than the body size, so dense windows (the addon list, communities, the group finder, professions) read at the body size or above; Blizzard's yellow (`NORMAL_FONT_COLOR`) becomes the `text` token, every other colour (white values, quality colours, red and grey states) stays. A string a skin styled with `Style.Text`, or one already in a kit face, is left alone, so the walk is safe to repeat. Hooks on each swept string's `SetFontObject` and `SetTextColor` keep the face and the mapping when Blizzard sets them again, and `opts.onShow` sweeps the frame again on each show, for strings made later. `Parts.EachRow` sweeps each list row it skins. A swept string follows the Text settings and the Restyle pass. |
| `Style.Track(object)` | `object:Restyle()` runs when a look setting, the theme or the profile changes. |
| `Style.Setting(group, key)` | A checked value, or the default. |

### Lumen

`ns.Lumen` holds the Lumen pieces the tracker, RestedXP and the windows share. S1 (`feat/lumen-material`) owns the material: Lumen's palette tokens, the gem and lens textures, the Cinzel and Alegreya faces and the kit's own section cap widget. Until S1 lands, `Lumen.lua` reads each S1 name when `Tokens` has it and falls back to a shipped token otherwise, so it is the one file to edit when S1 merges:

| Name | S1 token | Fallback |
| --- | --- | --- |
| `Lumen.Color("gilt")` | `gilt` | `neutral` |
| `Lumen.Color("questGold")` | `questGold` | `neutral` lifted 30% toward `textEmphasis` |
| `Lumen.Color("rimLight")` | `rimLight` | `edgeInner` |
| `Lumen.Texture("gem")` | `gem` | `chamferTile`, turned 45 degrees |
| `Lumen.Texture("checkRing")` | `checkRing` | `ringBevel` |
| `Lumen.Texture("gemFill")` | `gemFill` | `dot` |

| Function | Behaviour |
| --- | --- |
| `Lumen.SectionCap(parent, opts) -> cap` | The mockup's section head on its own row frame (`cap.row`, which the caller anchors): a 7-unit gilt gem at `opts.left`, the title after a `gapSmall` in the `caption` face at 13 (the mockup's `Cinzel 13, tracked`), upper case and tracked when the kit face loads, in gilt; a one-border rule from the title's end fading from gilt at 55% to nothing (`SetGradient` where the client has it, the `divider` texture otherwise); and the trail (`cap:SetTrail(value)`, a count or a short text) in the `number` face, muted, right-aligned at `opts.right`. `opts.left`, `right` and `y` are units or functions of the row. `SetTitle`, `SetTrail`, `SetShown`, `Restyle`. When S1's `Widgets.SectionCap` lands, this function becomes a call to it. |
| `Lumen.Ring(host, checked) -> ring`, `Lumen.RingCheck(check) -> ring` | `Ring` draws the Lumen ring on any frame and leaves its state to the caller (`ring:SetChecked(bool)`; RestedXP's configurator check, a plain frame, uses it). `RingCheck` is a Blizzard check button as a Lumen ring: its art is stripped and a 14-unit ring (`checkRing`) with an 8-unit gilt fill (`gemFill`) draws on a KstyleUI frame over it. The ring is `edgeInner` at rest, lights toward gilt under the mouse and turns gilt while checked; `textDisabled` when disabled. It follows `SetChecked`, clicks and `OnShow`. `Lumen.RingOf(check)` returns it. |
| `Lumen.Gem(owner, layer)`, `Lumen.Tint(region, name, alpha)`, `Lumen.Tracked(text)`, `Lumen.Plain(value)` | The gem texture; a tint in a Lumen colour; the caption tracking; a secret-safe string. |

### Parts

`ns.Parts` holds the pieces skins share. Each one draws on KstyleUI's own child frames and hides Blizzard art only through `KstyleUI.Skin`, so parts B and C can use them too.

| Function | Behaviour |
| --- | --- |
| `Parts.Rim(frame, opts) -> rim` | The kit's icon chrome (`Widgets.IconChrome`: the near-black button body) behind `frame`, on a child frame one level below it, `opts.outset` units outside `opts.target` (default `frame`). `rim:SetRimColor(r, g, b, a)` draws a 2-unit chamfered ring and the hairline with its halo in that colour; `nil` removes both and leaves the plain grey hairline. A second call returns the same rim. `Parts.RimOf(frame)` returns it. |
| `Parts.AccentLine(owner, opts) -> line` | A 2-unit accent divider along the owner's `BOTTOM` (default) or `TOP` edge, or across `opts.anchor`. It follows the accent setting. |
| `Parts.Hush(texture)`, `Parts.Divider(owner, texture)` | Hide one Blizzard texture for good, and replace a Blizzard divider texture with an accent line at the same place. |
| `Parts.Dock(window, frames, opts) -> dock`, `Parts.DockOf(window)` | The docked-tab treatment: the window's `Skin.Backdrop` glass grows past any edge the shown `frames` (Blizzard's tabs, or the world map's quest log) reach beyond, by their reach plus a `gapMedium`, through the backdrop's inset, so the tabs stand inside one glass instead of hanging off it. A one-border seam (`dock.seams[edge]`, `edgeInner`) marks the frame's old edge, inset by one `radius` from the corners, unless the tabs straddle that edge (the spellbook's), where a line would cut through them; a side seam starts a `gapTiny` above the topmost docked frame rather than at the window's top corner, so it never runs up through the header band between the title and the close glyph. `opts.title` (a font string) moves by half the horizontal growth through `AdjustPointsOffset`, so the title keeps its place over the glass; `opts.relayout` names a window method to follow with `hooksecurefunc` (the character sheet's `UpdateTabLayout`). The dock measures with `GetLeft` and friends, so a window whose rect is not yet valid waits for its `OnShow`, `OnSizeChanged`, or a tab's show or hide, and places then; nothing of Blizzard's is moved or resized. Bottom tabs keep their `Skin.Tabs` pills and strip; side tabs their `Parts.SideTab` rims. |
| `Parts.SideTab(tab, opts)` | Strips a side tab, a sidebar check button or an icon-only tab-system tab but its `Icon`, and rims the icon (or, with `opts.rimTab`, the tab itself, so tabs whose icons Blizzard sizes differently wear one rim size: the paper doll's stats, titles and equipment-set tabs): accent while checked or selected, `text` at 50% under the mouse. The icon is quiet (60% alpha) until the tab is chosen or under the mouse, so a column of tabs reads as tabs and not as a row of items. It follows `SetChecked`, `SetTabSelected`, clicks and hover, and keeps a selection Blizzard made before the skin. |
| `Parts.Glyph(button, textureName, opts) -> texture` | Strips a small Blizzard button, such as a page arrow or a red size button, and draws a 10-unit line glyph (`glyphChevron`, `glyphClose`) on it: `text` at rest, `textHover` under the mouse, `textDisabled` when disabled. `opts.flip` points a chevron up; `opts.rotation` turns it, in radians. |
| `Parts.Dropdown(dropdown)` | Strips a `WowStyle1DropdownTemplate` button but its `Arrow` and puts a button-body tile behind it. |
| `Parts.StripLeaves(frame)` | Strips each child of `frame` that has no children of its own, such as the scroll lines on a list. |
| `Parts.Wash(highlight)` | Replaces a row highlight frame's art with a flat accent wash at 12%, which Blizzard's own fade of the frame still shows and hides. |
| `Parts.EachRow(scrollBox, fn)` | Runs `fn(row, elementData)` for each row a `WowScrollBoxList` shows now and later, through `ScrollUtil.AddInitializedFrameCallback`; without it, after each `Update`. `fn` must be safe to run again on a recycled row. |
| `Parts.FillBar(bar)` | Restyles a `ColoredProgressBarTemplate` bar, such as a reputation bar: Blizzard's background and rounded mask go, a 10-unit fill in the bar texture sits on a bar-grade track, Blizzard's standing colour goes through `Style.BarColor`, and the fill direction setting anchors the fill left or right. |

While the module runs, a change to any look setting restyles every text and bar the skins styled. The settings window's preview shows the settings whether or not the module runs.

## Skins

### Character sheet (`Character.lua`, key `character`)

Forever's character window (`CharacterFrame` in `Blizzard_UIPanels_Game/Camelot`, created before any addon loads) has side tabs instead of bottom tabs, a left pane with the paper doll and a right pane with the stats. The skin applies on the window's first show:

- **Window.** `Skin.Window` puts the glass panel behind it and restyles the close button and title (`Style.Title`: the heading face, one line, never wrapped). The left and right pane art and the divider between them go. The side mode tabs (character, reputation, skills, PvP, currency, statistics) become `Parts.SideTab`s. Blizzard hangs them off the window's right edge (`CharacterFrameModeTabs`: `TOPLEFT` at the frame's `TOPRIGHT`, 30 down), outside the glass, so the skin docks them with `Parts.Dock`, the one docked-tab treatment every skinned window shares: the window's own glass grows to the right by the tabs' reach plus a `gapMedium`, a one-border seam in the `edgeInner` tone runs down the frame's old right edge between the stats and the tab gutter, from the first mode tab down (the header band above it stays clear), and the title moves over by half the gutter so it stays centred on the glass. The paper doll's three sidebar tabs (stats, titles, equipment sets; `PaperDollSidebarTab1` to `3`, 42 by 42, centred over the right pane) are `Parts.SideTab`s rimmed on the tab, not the icon, since Blizzard sizes the portrait and set icons 36 by 33 and the titles icon 42 by 42; one rim size, inside the pane, clear of the mode column. It follows `CharacterFrameMixin:UpdateTabLayout` through `hooksecurefunc`, so when Blizzard hides every tab the gutter goes; the tabs are never moved. The tabs' icons are Blizzard's own (the player's portrait, then the reputation, skills, honour, currency and statistics icons) and quiet until chosen, as `Parts.SideTab` paints them. The equipment slots themselves sit inside the window. The pane toggle button becomes a chevron that points the way the pane will move.
- **Paper doll.** Every equipment slot loses Blizzard's slot frame and quality border, keeps its icon (cropped 7% each side) and overlays, and gets a `Parts.Rim` whose ring shows the item's quality colour (`Theme.QualityColor`). A hook on `PaperDollItemSlotButton_Update` repaints a slot whenever Blizzard updates it. The model's backdrop and the top strip go, and the level line is a caption.
- **Stats.** The stats list's frame art goes. Category rows read as captions over an accent line, labels in the body font, values in the number font. Rows the list shows later are skinned as they appear.
- **Reputation and currency.** Each list's scroll bar, filter dropdown and scroll lines are restyled. Header rows lose their art and keep their expand icon. Entry rows get a flat accent highlight, and reputation bars become `Parts.FillBar`s. The detail pane's divider, checkboxes, buttons and standing bar are restyled, and its description (`Description`, a `ScrollingFontTemplate`: `ScrollBox.FontStringContainer.FontString`) wears the `body` face, justified LEFT, inside its own box left of the scroll bar. Blizzard's own colours for names, counts and check labels stay, because they carry meaning (inactive currencies, factions at war).

| Setting | Default | Row |
| --- | --- | --- |
| `character.qualityBorders` | `true` | toggle: colour each slot's rim by its item's quality |
| `character.qualityFrom` | 2 (uncommon) | dropdown: the lowest quality that colours a rim, from poor (0) to epic (4) |

A missing part (a slot, the reputation or currency tab, the paper doll hook) is logged as `character: <name> is missing on this client` and skipped.

### Spellbook and talents (`Spellbook.lua`, keys `spellbook` and `talents`)

On Forever the spellbook and the talents live in one window, `PlayerSpellsFrame`, from the load-on-demand `Blizzard_PlayerSpells` (its `Camelot/` files). Forever hides the window's tab strip and opens each part from its own micro button. Both skins wait for the addon to load, so KstyleUI never loads it, and apply on the window's first show. Each has its own switch; both restyle the shared window once.

- **Window.** The glass panel, close button and title. The red maximise and minimise buttons become chevrons.
- **Spellbook.** The book's page art (top bar, page backgrounds, corner, bookmark) goes. Forever's category tabs are icon-only square tabs (`AddIconTab`): each keeps its icon on a `Parts.SideTab` rim, accent while selected, and a category added later (a pet's) is skinned through a hook on the tab system's `AddTab`. The search box gets the button-body tile. Each spell item loses its backplate, border, shadow and sheen; its icon loses Blizzard's rounded mask, is cropped 7%, and sits on a `Parts.Rim`. Names are heading text, sub-names body text. Section headers become display text over an accent line. The paging arrows become chevrons and the page number a caption. A hook on `PagedSpellsFrame.DisplayViewsForCurrentPage` skins every page as it shows; in combat it waits for `Combat.Queue`, because spell buttons can be protected.
- **Talents.** The frame's own background, border and dividers go; the class background art and the tree's animations stay. The tab strip, search box, Apply and inspect-copy buttons, and the unspent-points counter are restyled. The talent nodes keep Blizzard's art: their states (available, maxed, locked, choice) are drawn by the shared talent UI and change too often to restyle safely.

### World map and quest log (`WorldMap.lua`, keys `worldMap` and `questLog`)

`WorldMapFrame` comes from `Blizzard_WorldMap`. Its window chrome is a separate `BorderFrame` in the `HIGH` strata, drawn over the map canvas, so a fill there would cover the map.

- **World map.** The glass panel goes on `WorldMapFrame` itself, one level below the map canvas. `BorderFrame` only loses its art (nine-slice, background, portrait, title bar, inset line): its close button is restyled, its title takes the heading font, and the red maximise and minimise buttons become chevrons. The navigation bar loses its tiled background and sits on a glass tile; its breadcrumb buttons and the tracking-options button keep Blizzard's art, because their art is their only label.
- **Quest log.** `QuestMapFrame` (from `Blizzard_UIPanels_Game`, attached to the map when it loads) sits on a glass tile. The quest list's background, edge and frame go, its scroll bar and search box are restyled, and a hook on `QuestLogQuests_Update` sets the skin font on every header and quest title the list shows. The details view keeps its parchment, because Blizzard colours quest descriptions and objectives dark for it; its frame goes, and its back, abandon, share and track buttons and scroll bar are restyled. Quest and objective colours stay Blizzard's.

### Objective tracker (`Tracker.lua`, key `tracker`)

`ObjectiveTrackerFrame` comes from `Blizzard_ObjectiveTracker`. Edit Mode keeps placing and sizing it, as `v3/` shows it under the minimap's auras. The look follows the Lumen mockup: one section cap, numbered accent discs, quest-gold titles, objective counts at the right, a glass panel aligned with the minimap.

- Blizzard's nine-slice backdrop goes, and a glass panel sits behind what the tracker shows (setting `tracker.panel`). Edit Mode's opacity slider drives Blizzard's backdrop, which the skin hides, so the panel has its own switch.
- Docked under the guide, the panel yields. When the RestedXP skin's story rail holds the guide over the quests and Apply's Edit Mode layout placed the tracker in the slot, the guide's card runs down to the quests' foot and the tracker's own panel hides (`ns.Tracker.Dock(true)`), so the rail reads as one card with two caps (the guide's name, QUESTS). `ns.Tracker.Fit()` is the frame the panel follows, which the guide's card anchors its foot to, and `ns.Tracker.Inset()` its insets, so the card ends where the panel did. The tracker skin asks the rail to place again when it applies, since either skin may apply first. The RestedXP skin's `restedXP.dock` switch turns this off; a tracker moved out of the slot, or the tracker panel switched off, keeps its own glass.
- Blizzard draws part of each quest block outside `ObjectiveTrackerFrame`. Blocks start `blockOffsetX` = 20 units in (`Blizzard_ObjectiveTrackerModule.lua`); the quest POI button, 20 units wide, hangs its right edge 7 units left of the title (`Blizzard_ObjectiveTrackerQuestPOIBlock.lua`), so its centre sits 17 units left of the title. The mockup (1.348 px per unit) puts titles 39 units from the panel's edge and the discs 8 units inside it, so the panel starts 16 units left of the tracker (titles at 36, discs 10 inside) and keeps one window content inset (`Widgets.WindowInset`, 16 units) on the right, where quest text runs to the tracker's edge and the find-group button reaches 5 units past it (`questFindGroupButtonSettings.offsetX`). Blizzard's 32-unit POI art stays inside the panel, hushed.
- The skin never moves or resizes the tracker: Edit Mode owns its position and its 260-unit width. Layout > Apply writes that position into the "KstyleUI <layout>" Edit Mode layout, 16 units in from the story rail's edge (`Core/Setup/README.md`). The panel is at least one window content inset wider than the tracker on the right, and as wide as the story rail (318 units, `Setup.Story`) when the tracker is narrower than that in KstyleUI's units, so the quest card shares the left rail's one edge and one width. At a large UI scale, where Blizzard's 260 units outgrow the rail, the panel keeps the content inset instead.
- The panel follows the content, not the tracker frame: Edit Mode sizes `ObjectiveTrackerFrame` to its height setting, or down to the bottom of the screen in the default position, whatever is tracked. The panel surrounds a KstyleUI frame (`Skin.Backdrop`'s `target`). Its top rises 4 units above the header of the first module with content, in Blizzard's order, so the caption row is the panel's first row, its text centred 17 units below the panel's top and its rule at 30, as the mockup draws them; Blizzard's own "All Objectives" header, 38 units of the frame's top, stays outside the panel. Its bottom is Blizzard's `NineSlice` bottom, which Blizzard anchors 10 units below the last module with content on every layout, plus 8 units, so the panel grows and shrinks with each quest and each collapsed module. When the tracker is collapsed, or nothing is tracked (Blizzard then hides the tracker, except in Edit Mode), the panel wraps the tracker's own header instead, from the tracker's top.
- A hook on the tracker's `UpdateHeaderPosition` re-checks collapse and content after every layout. Blizzard's last step of `ObjectiveTrackerFrameMixin.Update` calls it through `self`, so the hook runs on dirty updates too. A hook on `Update` itself would miss those: `DirtiableMixin` runs the `Update` the container captured at load.
- One header. Blizzard shows two, the container's "All Objectives" and the module's "Quests", with no setting to hide either (`Blizzard_ObjectiveTracker.lua` `ShouldShowHeader`, `Blizzard_ObjectiveTrackerModule.lua` `EndLayout`), and their spacing is hard-coded (`BASE_TOP_PADDING` = 38, `headerHeight` = 25, `fromHeaderOffsetY` = -10). Every header loses its art and its text is hushed (alpha 0, kept at 0 through a hook on `SetAlpha`, as `Skin.Strip` hushes textures), and a Lumen section cap (`Lumen.SectionCap`) takes the header row: the gem's left edge one content inset (`Widgets.Inset` at the window cut) inside the panel, clear of the top-left cut, the module's name as the cap's title, the rule fading toward the count of blocks the module shows (set after each `EndLayout`), which sits 24 units from the right, before the collapse chevron. The title takes its natural width while the row has room for it (`cap:Fit`: the title's unbounded width against the row's width less the gem, the gaps, the count and the insets), so the client draws its own string rect and a measuring gap, such as Cinzel's thin spaces, can never truncate it; only a title wider than the room is clamped to the room, so it ellipsises rather than running under the count or the collapse button. A hook on the row's `OnSizeChanged` refits it when the header resizes. A hook on the header text's `SetText` keeps the title on a renamed module, including the scenario module, which writes its header text directly (`Blizzard_ScenarioObjectiveTracker.lua`). The tracker's own header gets an "Objectives" cap and its collapse-all chevron, shown only while the panel wraps that header (collapsed, or nothing tracked); expanded, Blizzard's collapse-all button stays where it is, invisible, above the panel. Each module's collapse button keeps its KstyleUI chevron at the header's right. Modules the tracker adds later are skinned through a hook on its `AddModule`.
- POI discs. Forever's `POIButtonTemplate` draws a 32-unit atlas disc (`Quest-In-Progress-Icon-yellow`) with no numeral (`Blizzard_POIButton/POIButton.lua` `GetInProgressDisplay`). The button's own art (`NormalTexture`, `PushedTexture`, `HighlightTexture`, `Glow`) and its `Display` icon are hushed through `Skin.Strip`, so Blizzard's `UpdateButtonAlpha` cannot bring them back, and a KstyleUI frame on the button draws an 18-unit accent disc (`dot`) with a dark numeral in the number font, numbered in the module's block order (`firstBlock`, `nextBlock`) after every layout through a hook on the module's `EndLayout`. A 24-unit accent ring (`ring`) shows for the super-tracked quest (`IsSelected`) and, fainter, under the mouse (`HookScript` on `OnEnter` and `OnLeave`). The button keeps its 20-unit click area and Blizzard's click, which super-tracks the quest. With the `questPOI` CVar off Blizzard makes no buttons and there are no discs.
- Titles. Blizzard colours each block's `HeaderText` in `SetHeader` and `UpdateHighlight` (`Blizzard_ObjectiveTrackerBlock.lua`), caching the colour in `colorStyle`. With `tracker.titles` on, hooks on both repaint the title in quest gold (`Lumen.Color("questGold")`), 15 % brighter under the mouse; off, the title takes Blizzard's cached `colorStyle` back at once, so the quest and difficulty colours return. The objective lines keep Blizzard's colours.
- Counts. Blizzard writes each objective as one string, `0/4 Crocolisk Hide` (or `Crocolisk Hide: 0/4`), through `block:AddObjective` into a pooled line's `Text` (`Blizzard_ObjectiveTrackerBlock.lua` `SetStringText`), and keeps the lines in `block.usedLines`. With `tracker.counts` on, after each module's `EndLayout` the skin reads every used line's text, and when it finds a count, sets Blizzard's text to the words and shows the count on a KstyleUI font string anchored to the text's top right, in the `number` face at the line's size, in the muted `text` colour. A line splits only when its full text fits on one line with a `gapMedium` to spare (its unbounded width against the text's width), so the words never wrap under the count and the line keeps the height Blizzard measured; a longer objective keeps Blizzard's text with the count inline. A secret or unreadable text, or one with no count, is left alone. Turning the switch off gives every line Blizzard's text back at once.
- Quest progress bars and timer bars lose their border art, sit on a bar-grade tile, and take the shared bar texture, colour and fill (`Style.StatusBar`), through hooks on each module's `GetProgressBar` and `GetTimerBar`. Their labels take the caption font; a timer keeps Blizzard's colour, which turns red as time runs out.
- With `tracker.font` on, Blizzard's two tracker font objects take the skin face and edge through `Style.ApplyFont`, at Blizzard's size times the shared text size. Quest titles (each block's `HeaderText`) and objective lines (each line's `Dash` and `Text`) inherit `ObjectiveTrackerLineFont` in XML and never set a font of their own, so every pooled line, new or reused, shows the skin face. `ObjectiveTrackerHeaderFont` is painted too, though the headers it feeds are hushed under KstyleUI captions. A face the game cannot load falls back as `Style.ApplyFont` describes, so the tracker matches the rest of the interface. A hook on their `SetFontObject` keeps the skin font when Edit Mode changes the tracker's text size, and reads the new size from the font family's name (`ObjectiveTrackerFont16`). Turning the font off needs a reload.
- Not restyled: the auto-accept quest pop-ups, the scenario stage block, the reward toast and the quest item buttons' hotkey and count. They keep Blizzard's fonts. Blizzard's row pitch (a 10-unit gap between blocks, 4 between lines) stays, since the skin never anchors Blizzard's blocks.

Render: `Tools/render/shoot.sh tracker` builds the tracker the way Forever does (`Tools/render/scenes/tracker.lua`) under the HUD's minimap, so the skin can be checked against the mockup without the game.

| Setting | Default | Row |
| --- | --- | --- |
| `tracker.panel` | `true` | toggle: the glass panel behind the tracker |
| `tracker.font` | `true` | toggle: the skin font for tracker text |
| `tracker.titles` | `true` | toggle: quest titles in quest gold instead of Blizzard's quest colours |
| `tracker.counts` | `true` | toggle: each objective's count moved to the right of its line |

## Part B windows

`PartB/` holds the skins for the game menu, Forever's group finder, mail, the merchant, the trainer and the professions window. `PartB/Kit.lua` loads first and sets `ns.PartBKit`, the helpers the six skins share. Every helper takes a Blizzard frame, logs and skips a missing or forbidden one, waits for `Combat.Queue` when the frame is protected in combat, and returns what it made on a second call.

| Skin | Key | Blizzard addon | Window | What changes |
| --- | --- | --- | --- | --- |
| `GameMenu.lua` | `gameMenu` | `Blizzard_GameMenu` | `GameMenuFrame` | The dialog border and header art go; window-grade glass, the heading font and a button-body tile for each pooled button come. A hook on `InitButtons` skins buttons the menu adds later. |
| `GroupFinder.lua` | `groupFinder` | `Blizzard_GroupFinder_VanillaStyle` | `LFGParentFrame` | The listing, browse and who-list pages become glass windows. Side tabs, dropdowns, check boxes, scroll bars, the comment box and the result and who rows are restyled. |
| `Mail.lua` | `mail` | `Blizzard_MailFrame` | `MailFrame` | The inbox, the send form and `OpenMailFrame`. Every inbox item and attachment gets a quality rim; the cash-on-delivery tint and the coin icons stay. The letter's body (`OpenMailBodyText`, a `SimpleHTML`) takes the `body` face through `Style.Html`, which names each text type (`P`, `H1` to `H3`) first as `SimpleHTML:SetFont`, `SetTextColor` and `SetJustifyH` need, and reads LEFT. |
| `Merchant.lua` | `merchant` | `Blizzard_UIPanels_Game` | `MerchantFrame` | Item rows become glass tiles with quality-rimmed icons on the button body; repair and junk buttons keep their icons; the page buttons get chevrons. |
| `Trainer.lua` | `trainer` | `Blizzard_TrainerUI` | `ClassTrainerFrame` | The skill bar is the kit capsule: the accent fill on the bar-grade track (`Kit.Bar` with `accent`), the skill line's name as a `body` label on the LEFT (the first service's `GetTrainerServiceSkillLine`, refreshed by a hook on `ClassTrainerFrame_Update`; `Skill` when the client has no name) and Blizzard's `rank / max` text in the `number` face on the RIGHT, both a `gapMedium` in from the ends. Category and skill rows become tiles that light while selected. |
| `Professions.lua` | `professions` | `Blizzard_Professions` | `ProfessionsFrame` | Side tabs, the recipe list, the schematic, tool slots and the craft-count spinner. The skill bars on the crafting and overview pages are drawn by KstyleUI status bars. |

The mail, merchant and professions skins add a `qualityRims` switch, on by default, under their window's switch.

| Helper | Behaviour |
| --- | --- |
| `Item(button, opts)` | Hides the slot art, keeps and crops the icon (`opts.icon`, `button.icon` or `button.Icon`; an atlas icon is not cropped), and puts `Parts.Rim` behind it. The rim follows the colour Blizzard gives `IconBorder` through hooks on its `SetVertexColor`, `Show`, `Hide` and `SetShown`; white and grey give no ring. `opts.window` names the skin whose `qualityRims` switch applies. `opts.normal` is for buttons whose icon is the normal texture. |
| `Dropdown(dropdown)`, `SideTab(frame)` | `Parts.Dropdown` and `Parts.SideTab`, so part B's dropdowns and side tabs match part A's. |
| `Arrow(button, direction)` | `Parts.Glyph` with a chevron turned `left` or `right`, for page and spinner buttons. |
| `Hush(frame, ...)` | `Parts.Hush` on each named texture. |
| `Select(frame, marker)` | A glass tile behind a list row whose edge takes the module's accent under the mouse and while `marker`, Blizzard's selection texture, shows. |
| `Square(button)` | An icon button on a near-black `buttonFill` tile that keeps its `Icon`. |
| `Inset(frame)`, `MoneyBox(box)`, `InputScroll(scroll)`, `NumberBox(box)` | Inset art (a glass tile with `opts.tile`), money and spinner boxes, and scrolling text boxes on the button body. |
| `RankBar(frame)` | Hides a `ProfessionsRankBarTemplate`'s art and draws a `Widgets.StatusBar` over it that mirrors Blizzard's `Update(professionInfo)`. A secret value passes straight to the bar. |
| `Bar(statusBar)` | Keeps a Blizzard status bar's fill, applies `Style.StatusBar` and puts a bar-grade tile behind it. |
| `Rows(scrollBox, skinRow)` | `Parts.EachRow`, once per scroll box. Every part B row function is safe to run again on a recycled row. |
| `Window(frame, opts)`, `Text(fontString, role, colorName)` | `Skin.Window` with the title in the module's heading font and its tabs in the module's accent, and `Style.Text`. |
| `Button`, `Tab`, `CheckBox`, `ScrollBar`, `EditBox` | The `KstyleUI.Skin` helper of the same name, then the module's look: labels through `Style.Text`, and hover edges, check marks, tab underlines, scroll thumbs and focus edges in `Style.Accent` instead of the interface accent. |
| `Accent(frame)` | Swaps the painter of a frame `KstyleUI.Skin` already restyled for one that uses `Style.Accent`, and registers it with `Style.Track` so an accent change repaints it. |
| `Rehover(frame, widget)` | Hooks `OnEnter` and `OnLeave` again, for buttons whose scripts Blizzard replaces with `SetScript`. |

Test: `Tools/regression/test-skins-partb-kit.lua` and `test-skins-partb-windows.lua`.

## Part C windows

`PartC/` holds the skins for the social windows, Forever's Legacy window, loot and group loot rolls, popups, the ready check and the addon list. `PartC/Kit.lua` loads first and sets `ns.PartC`, the helpers these skins share. `PartC/Preview.lua` loads last and adds part C's sample to the settings preview.

| Skin | Key | Blizzard addon | Window | What changes |
| --- | --- | --- | --- | --- |
| `Friends.lua` | `friends` | `Blizzard_FriendsFrame` | `FriendsFrame` | Forever's social window: the glass panel and title, the bottom tabs and the friends and recent allies tab strip, the status dropdown, the battle tag bar and broadcast box, the add friend and whisper buttons, and the ignore list window. Friend rows keep Blizzard's status tint and game icons and get an accent highlight; headers read as captions over accent lines, the online divider becomes an accent line, and invite rows get restyled buttons (decline keeps its cross). The raid tab's check box and buttons, the raid info dialog and the quick join list are restyled too. |
| `Communities.lua` | `communities` | `Blizzard_Communities` | `CommunitiesFrame` | The guild and communities window, which Forever opens for the guild: the glass panel, chevron size buttons, the side tabs on `Parts.SideTab` rims, the stream and member dropdowns, and the invite, guild control, recruitment, settings and log buttons. The community list loses its blue menu art and filigree; each community keeps its icon and gets an accent wash while selected. The member list, its column header art and the show offline check box, the chat scroll bar and the chat edit box are restyled; member rows keep their class and rank icons and Blizzard's name colours. |
| `Legacy.lua` | `legacy` | `Blizzard_LegacySystem` (load on demand) | `LegacySystemFrame` | Forever's Legacy window. Waits for its addon, so KstyleUI never loads it. The glass panel and title, the three side tabs on `Parts.SideTab` rims that follow the selected page, the reward track and challenge point bars in the shared bar look on dark tracks, the points text, the challenge filter, search boxes and scroll bars, the page dividers, and the tree's Apply button and points bar. Blizzard's page art behind each page is hidden unless `legacy.pageArt` is on. The reward cards, challenge cards and tree nodes keep Blizzard's art. |
| `Loot.lua` | `loot` | `Blizzard_UIPanels_Game` | `LootFrame` | The flat panel, item card art, quality stripe and list shadows go; a glass panel, the close glyph and a slim scroll bar come. Each row becomes a glass tile; its icon is cropped and rimmed by quality, its quality label takes the quality colour, and Blizzard's highlight becomes an accent wash. |
| `LootRolls.lua` | `lootRolls` | `Blizzard_UIPanels_Game` | `GroupLootFrame1` to `4` | Each roll frame loses its toast art and sits on a glass panel. The item icon is rimmed by the roll's quality (`GetLootRollItemInfo`, repainted through a hook on `GroupLootFrame_SetupItemDisplay`), and a KstyleUI timer bar in the shared bar look mirrors Blizzard's hidden timer, in the module's accent rather than Blizzard's pure yellow: a roll timer carries no standing. The need, greed, transmog and pass buttons keep their icons. |
| `Popups.lua` | `popups` | `Blizzard_StaticPopup_Game` | `StaticPopup1` to `4` | The dialog art goes and a glass panel comes. Buttons, the close button, the edit box, the money boxes (their coin icons stay) and the dropdown are restyled. An item popup's icon is rimmed in the colour Blizzard gives the item's name, through a hook on its `SetTextColor`; white and grey give no ring. The alert icon, separator and progress bar stay. Each popup is swept, so its question, sub text and labels take the skin's face at the size the game's text size setting gave them when the skin applied. |
| `ReadyCheck.lua` | `readyCheck` | `Blizzard_FrameXML` | `ReadyCheckListenerFrame`, on `ReadyCheckFrame`'s first show | A glass panel, a heading, body text and restyled ready and not ready buttons. The portrait goes with the rest of the window art. |
| `AddonList.lua` | `addonList` | `Blizzard_AddOnList` | `AddonList` | The window, its dropdown, search box, check box, buttons and scroll bar. Each addon row gets a KstyleUI check box, a restyled load button and an accent highlight; category rows read as captions over an accent line. |

The loot window and the loot rolls add `qualityBorders` (on) and `qualityFrom` (uncommon) under their switch, as the character sheet does. The Legacy window adds `pageArt` (off): Blizzard's art behind each Legacy page.

| Helper | Behaviour |
| --- | --- |
| `Kit.Window(frame, opts)`, `Kit.Button`, `Kit.CheckBox`, `Kit.ScrollBar`, `Kit.Tab` | The `KstyleUI.Skin` helper of the same name, then part B's `Accent`, so hover edges, check marks, scroll thumbs and tab underlines take the module's accent. `Kit.Button` puts the label in the module's body font and `Kit.Window` the title in its heading font. `Kit.Accent(frame)` is the second step alone. |
| `Kit.Frame(key, name)`, `Kit.Child(key, frame, path)`, `Kit.Each(key, frame, paths, fn)` | A global frame, or a dotted path under a frame, or `fn` on each path found. A missing one is logged once as `<key>: <name> is missing on this client; skipped`. |
| `Kit.Item(button) -> rim` | Hides an item button's slot art and quality border, keeps and crops its icon and overlays, styles its count, and puts `Parts.Rim` behind it. |
| `Kit.Quality(key, rim, quality)`, `Kit.ColorRim(rim, r, g, b)` | Paints a rim by item quality under the skin's `qualityBorders` and `qualityFrom` settings, or by a colour Blizzard gave, brightened; a secret value, white or grey clears it. |
| `Kit.QualityDefaults()`, `Kit.QualityRows(help)` | The quality border settings and their rows. |
| `Kit.TabSystem(system)` | `Kit.Tab` on each tab of a `TabSystemTemplate`, and on tabs its `AddTab` adds later. |
| `Kit.Wash(texture, alpha) -> texture` | Hides a Blizzard selection or highlight texture and shows a flat accent wash in its place while Blizzard shows it, through hooks on its `Show`, `Hide` and `SetShown`. |
| `Kit.Highlight(button)` | Turns a button's highlight texture into a flat accent wash in place. |
| `Kit.Bar(statusBar, opts) -> bar` | Keeps a Blizzard status bar's fill, hides its other art, applies `Style.StatusBar`, and draws a bar-grade track on the bar itself, in its `BACKGROUND` and `BORDER` layers under the fill, so art at the bar's own frame level cannot cover it. `opts.accent` fills it with the kit accent whatever colour Blizzard sets; `opts.label` adds a `body` label at the LEFT (`bar:SetLabel(text)` changes it, hides it when empty or secret) and moves the bar's `rankText` to the RIGHT in the `number` face, each a `gapMedium` in. |
| `Kit.MirrorBar(statusBar, parent, width, height, opts) -> bar` | Hides a Blizzard status bar and draws a `Widgets.StatusBar` one level above `parent` that follows its range, value and colour through hooks on `SetMinMaxValues`, `SetValue` and `SetStatusBarColor`, in the shared bar texture, colour and fill direction. With `opts.accent`, the bar paints the module's accent (through `Style.BarColor`, so the class and custom colour settings still apply) instead of Blizzard's colour, for a bar whose colour carries no meaning. |
| `Kit.EditBox(box, keepKeys)` | Strips an edit box's art and `NineSlice` but the named textures, such as a coin icon, then part B's `EditBox`, whose focus edge takes the module's accent. |
| `Kit.TriState(check)` | After `Skin.CheckBox`, draws the check mark grey while Blizzard desaturates the box's `CheckedTexture`, as the addon list does for an addon on for some characters. |
| `Kit.Texts(frame, role, colorName)`, `Kit.Crop(icon)`, `Kit.Below(panel, frame, levels)` | Styles every font string on a frame; crops an icon; puts a panel a number of levels below a frame. |
| `Kit.Preview(builder)` | Adds a sample to the settings preview. `Preview.lua` calls `builder(frame, anchor)` under the samples before it and keeps the frame it returns; the preview's `Refresh` calls the sample's `Refresh`. |

Tests: `Tools/regression/test-skins-partc-loot.lua`, `test-skins-partc-dialogs.lua`, `test-skins-partc-social.lua` and `test-skins-partc-legacy.lua`.

## Other addons

### RestedXP Guides (`Addons/RestedXP/`, key `restedXP`)

RestedXP Guides (folder `RXPGuides`) is a third-party addon. The skin reads RestedXP's public shape, its frame names, theme fields and functions, and copies none of its code or art. The switch, **RestedXP**, is on by default. The skin waits for `RXPGuides` to load, so nothing happens when RestedXP is not installed or is off. KstyleUI loads before RestedXP, so the skin reaches RestedXP's addon table through `LibStub("AceAddon-3.0"):GetAddon("RXPGuides", true)` once the module starts at `PLAYER_LOGIN`, after RestedXP's own start-up.

| File | What it holds |
| --- | --- |
| `Theme.lua` | `ns.RestedXP.Addon()`, `LogOnce` and `Try`, and the theme: built, registered with RestedXP and drawn by taking over its run-time active theme |
| `Chrome.lua` | KstyleUI's chrome on each RestedXP window: the guide as one card, the others on their own glass |
| `Rail.lua` | The story rail: the guide window placed in the layout's story slot, the quests docked into its card |
| `Skin.lua` | The `ns.Skins.Add` definition and the `restedXP.rail` and `restedXP.dock` switches |

**The theme.** The skin registers a theme named `KstyleUI` through `RegisterTheme` (RestedXP's v1 window) and puts a version 2 theme of the same name in `addon.v2.themes`, so RestedXP's own conversion never replaces it (the v2 window). Surfaces are the `surface` token at the Widgets panel opacity, including the v1 step list body (`bottomFrameBG`) and the v2 common background, so the list reads as the same glass; the guide selector and the step check boxes the `buttonFill` body of the HUD's buttons, borders the `edgeInner` line every HUD panel wears, text `text` (v2) and `textEmphasis` (v1), and titles, highlights, the checked step box and map pins the module's accent (`Style.Accent`). The font is the module's body face (`Style.Font("body")`). RestedXP's own icons, banner art and border art are read from RestedXP's `RXP Blue V2` and `DarkMode` themes at run time. A change to the accent, the font, the panel opacity or the profile rebuilds the two theme tables in place and redraws RestedXP once on the next frame, out of combat.

**Activation.** RestedXP's saved settings are never written, its `activeTheme` included (the owner's rule: never write another addon's saved settings). While the switch and the module are on, the skin takes over RestedXP's run-time theme instead: a `hooksecurefunc` on RestedXP's `LoadActiveTheme`, which every RestedXP draw (`RenderFrame`) and theme reload runs first, sets `addon.activeTheme`, `addon.colors` and `addon.font` to the KstyleUI theme and the guide window's backdrop files as RestedXP's own loader does (`Themes.lua`), so the draw that follows uses it. RestedXP's own theme list still offers `KstyleUI`, since the theme is registered; a player who picks it there has made it their saved choice, and the skin leaves that alone too. Turning the switch or the module off redraws RestedXP once, and its loader puts the player's own theme back; with nothing to remember there is nothing to restore, and the `KstyleUIDB.account.restedXPTheme` memory an earlier KstyleUI kept is dropped. A RestedXP profile change (a hook on `settings.RefreshProfile`) is followed by a redraw when the new profile's draw did not end on the theme. RestedXP redraws through its `ReloadTheme`; when the player has turned RestedXP's live theme reload off, a switch shows after `/reload`, as RestedXP's own theme changes do, and at login the skin does the one draw RestedXP had already done without the theme (`RenderFrame` and `SetupArrow`). The v2 guide window and the v2 configurator resolve their theme from the saved name through `v2:GetTheme`, whose return value a hook cannot change, so the skin does not change it: their frames are restyled directly (below), and the v2 theme stays registered for a player who picks it in RestedXP's list.

**Chrome.** Windows RestedXP makes later are restyled through `hooksecurefunc` on the function that makes them, only while the switch and the module are on. Switching either on again (`OnSwitch`) restyles the windows RestedXP made in between. Secure buttons made in combat wait for `Combat.Queue`.

| RestedXP window | Reached through | What changes |
| --- | --- | --- |
| Guide window (v1, the default on Forever) | `RXPFrame`: `GuideName`, `BottomFrame`, `Footer`, `ScrollFrame.ScrollBar` | One window-grade glass (the chat's and tracker's chamfer) on a KstyleUI card frame that runs from the cap holder's top to RestedXP's window bottom (the footer), or to the active steps' bottom when RestedXP anchors them under the window, or to the quests' foot when the rail docks them; the header, the list and the footer draw no glass of their own, and their banner, backdrops, logo and class icon go. **The cap.** RestedXP's title text is hushed (alpha 0, kept through a hook on `SetAlpha`) and a KstyleUI holder standing on the active steps' top (on the header's when there are none) draws a Lumen section cap (`Lumen.SectionCap`) with the guide's name (the title's first line, tracked capitals in gilt) as its title and the first shown step's plate text (`Step 34`, as RestedXP wrote it) as its trail: one header language with the quests' `QUESTS` cap, one type ramp (cap 13, rows body, captions), and the name truncates only on a row too narrow for it. The rest of the title (RestedXP puts the guide's route on a second line) is a `caption` row in RestedXP's header band, which shrinks from 35 to 18 units since the cap left it; a hook on the title's `SetText` keeps both. The step list's view ends wherever RestedXP's frame height lands, mid-row more often than not, so a `gapXLarge` fade on a KstyleUI frame above the view (`surface` at the glass's alpha at the foot, to nothing) softens the cut line while the scroll bar's value is short of its range, and hides at the end, where the last row is whole; a secret scroll value leaves it as it was. The footer's line is a `caption` in `text`; the scroll bar is KstyleUI's and sits in its own gutter: a one-border `edgeFaint` line on the card's glass, half a `gapSmall` left of the bar, from the list's top to its bottom. RestedXP's text cannot move, so the glass reaches past both sides by one content inset (`Widgets.Inset` at the window cut) less RestedXP's own 4-unit margin, about 8 units, so the rows and the cog clear the corner cuts and the light line, and the cap's gem sits one content inset in, where the quests' gem sits. Step rows keep RestedXP's fill in the theme's colours. The scroll view starts below RestedXP's 9-unit header overlap plus one content inset, so the first row is never under the band; the view is placed again after RestedXP's `UpdateVisuals`, and in combat it waits for `Combat.Queue`. RestedXP caps the list's scroll for its own 12 units of inset after each `SetValue`, so a post-hook on the scroll bar's `SetValue` adds back the units the header reserve takes, once per range, and the last row still scrolls into view. Each row's text is in the `body` face at no less than the `body` size times the module's text size, and its number a `caption`; a larger font RestedXP asks for stays larger. A post-hook on each font string's `SetFont` keeps this when RestedXP sets a font again. RestedXP's saved `guideFontSize` is never written. |
| Active step frames | `RXPFrame.CurrentStepFrame.framePool`, made by `SetStep` | Rows inside the guide's card, not cards of their own: RestedXP's backdrop goes, the `Step N` plate draws nothing and its text is hushed (the card's cap carries the step), each element's check button becomes a 14-unit Lumen ring check (`Lumen.RingCheck`; RestedXP's 12-unit buttons sit 6 in) and its text is in the `body` face at no less than the `body` size times the module's text size, with RestedXP asked to measure the steps again when a size changed (`CurrentStepFrame.UpdateText`). |
| Guide menu and RestedXP's other menus | `ShowMenu`, drawn in `L_DropDownList1` to `8` (`DropDownList` where `EasyMenu` exists) | Glass and KstyleUI's font while RestedXP's menu shows. The lists belong to the menu library, which other addons share, so closing the menu gives back their own backdrops. |
| Navigation arrow | `arrowFrame` | Greyed and tinted with the accent after each redraw: RestedXP bakes the arrow's colour into its art |
| Active items, active targets | `activeItemFrame`, `targeting.activeTargetFrame`; buttons made by `UpdateItemFrame` and `targeting:UpdateTargetFrame` | Glass, a title tile in the accent, a rim behind each button and an accent highlight; item icons are cropped. RestedXP hangs the title plate from the frame's top edge (`TOPLEFT` at 5, 10, 19 tall), so the card's glass rises over the plate by the plate's anchor offset plus a `gapSmall`, read from the plate's anchor on every refresh, and the title reads as the card's cap instead of a tab set past its glass. RestedXP's hide-background settings hide the glass too. |
| Leveling report | `tracker.ui.CharacterFrame` | Glass, an accent heading, KstyleUI close and level buttons and scroll bar |
| Level splits | `tracker.levelSplits`, made by `tracker:CreateLevelSplits` | As the active items frame |
| v2 guide window (when the player turns v2 on) | `v2.state.guideWindow` | Glass on the header and step list, no banner art, the close cross, the scroll bar, an accent title kept through `UpdateSubTheme` |
| Guide configurator, guide importer and its two confirmations | `ui.v2.configurator`, made by `CreateGuideConfigurator`; `guideImporter.widgets`, made by `ui.v2:CreateGuideImporter` | Glass; the configurator's title in the kit's `title` role in `textEmphasis`, as the skinned Blizzard windows' titles (not RestedXP's gold or the accent), and its Back, Reset and Submit buttons KstyleUI buttons with `body` labels in `textEmphasis`, RestedXP's own flat button wash hushed, all applied again after the configurator's `UpdateTheme`, which re-fonts them from RestedXP's theme; a `surface` tile under its page (`scrollContainer.frame`); each option row the page renders (`RXPV2GuideConfiguratorOption` widgets, found through the container's `children`, inside their padding containers or not, as the container's `DoLayout` is hooked and after every `UpdateTheme`) on its own `surface` tile with RestedXP's wash and border hushed, its label in `body`, its "Recommended" line in `caption` in `Style.Accent` (RestedXP's is cyan), and its square check as a Lumen ring (`Lumen.Ring` on `checkbg`, following the widget's `SetChecked`, lighting under the row's hover) with RestedXP's cyan fill and tick hushed; the importer's accent title, KstyleUI buttons, close cross, edit box and scroll bar. |
| Feedback form, export box | `comms.OpenBugReport`, `comms.OpenBrandedExport` | Glass and an accent title while RestedXP shows them. Both are AceGUI frames that AceGUI hands to other addons after RestedXP, so closing one gives back its own art and title colour. |
| Clean-up button on the quest log | `RXPQuestLogCleanupButton`, made at `PLAYER_ENTERING_WORLD` | A KstyleUI button |

Map pins, route lines, timer bars and the tips' highlights take the accent through the theme.

These are not restyled:

- Item upgrades, the auction house tab and talent guides: RestedXP does not make them on Forever.
- RestedXP's settings: an AceConfig page in Blizzard's settings window, drawn by AceGUI widgets every AceConfig addon shares.
- The v2 step rows, cards and party steps: they keep RestedXP's drawing in the theme's colours.
- The guide importer's guide dropdown: a stock AceGUI dropdown shared with other addons.
- The minimap button: LibDBIcon's.

A missing or renamed part is logged once as `restedXP: <path> is missing in this RestedXP; skipped`, and the rest still applies. A call into RestedXP that fails is logged once and never raises an error.

**The story rail** (`restedXP.rail`, **Story rail**, on by default). The left rail's story slot holds the guide over the quests (`Setup.Story(preset, true)`: the guide the upper half, the tracker the lower half). Out of combat, after the skin applies, after every `SetStep`, on `PLAYER_ENTERING_WORLD`, on `EDIT_MODE_LAYOUTS_UPDATED`, after a head or scale change, `Rail.Place` moves RestedXP's unprotected top-level `RXPFrame` (its steps, header and footer hang from it in RestedXP's own anchors) and sizes it:

- its card's glass, which reaches past RestedXP's frames by one content inset less 4 units, sits on the rail's left edge at the rail's width, like every left-rail card;
- its footer sits on the foot of the guide's half, one rail gap (16) above the quests, and the route row, the active steps and the cap stack up from there, so more steps grow into the free space under the party card, never into the quests;
- its height leaves the step list under 30 units, and RestedXP's own `BottomFrame.UpdateFrame` folds a list that short (`GuideWindow.lua`), so the rail reads the path (the cap and the active steps) and then the quests, not the same objectives three times. Turn the rail off for the full list.

It anchors to `UIParent`, never to a KstyleUI frame, because RestedXP saves the window's points and size itself at logout, and it never writes RestedXP's settings or moves its text. The v2 guide window is not placed (logged once). A player who drags or resizes the guide turns the rail off for that profile, with a chat line on how to turn it back on; turning the rail off gives back the place and size RestedXP had before the first placement. Steps that outgrow the half are logged.

**One card with the quests** (`restedXP.dock`, on by default). After each placement, `Rail.Place` checks whether the tracker sits where Apply's Edit Mode layout puts it: the tracker skin applied with its panel on (`ns.Tracker.Fit()`), `ObjectiveTrackerFrame` shown, and its first anchor the `TOPLEFT` of `UIParent`'s `BOTTOMLEFT` within 2 units of `Setup.EditMode.TrackerPlace(story.tracker)` in the tracker's units. Then the guide's card anchors its foot to the tracker skin's fit frame, 8 units under it as the tracker's panel ended, and the tracker's panel hides (`ns.Tracker.Dock(true)`): one glass from the guide's cap to the quests' foot, with the quests' cap as the section break, as the mockup's one left panel. Docked, the guide's own foot (RestedXP's footer) moves down from the guide band's foot to one `gapSmall` above the tracker band's top, where the quests' cap starts (Apply anchors the tracker frame 34 units higher, for Blizzard's hidden container header), so the card holds no hollow band between the footer and QUESTS; undocked, the guide goes back to its band's foot. `Rail.DockTo(frame)` docks against a stand-in for the fit frame (its top the quests' cap, its bottom their foot) for a scene or a test that draws the tracker elsewhere; the game never calls it. A tracker the player moved in Edit Mode (`EDIT_MODE_LAYOUTS_UPDATED` re-checks), the tracker panel switched off, the dock switch off, the rail off, or RestedXP hiding its guide (`RXPFrame`'s `OnHide`; its `OnShow` places again) undocks: the card ends at the footer and the tracker's panel shows again. The two frames are never anchored to each other through Blizzard's tracker; only KstyleUI's own card follows KstyleUI's own fit frame.

**The guide's head.** The card's top is a KstyleUI holder standing on RestedXP's active step frame (on its header when the steps are hidden, or anchored under the window), as tall as the cap row (16) plus a `gapSmall` above and below; RestedXP's step frame keeps 10 units of air above its first line, so the cap needs none. The cap's title is the guide's name and its trail the current step, measured by `Lumen.SectionCap`'s fit: the name takes its natural width while the row has room, and is clamped to the room, before the step, only on a row too narrow for it. RestedXP's header band under the steps holds the route as a caption row and is 18 units tall. The list's view starts one content inset under the band's overlap and ends a gapSmall above the footer, which covers the list's last 6 units, so no row runs under the footer.

Tests: `Tools/regression/test-skins-restedxp-theme.lua`, `test-skins-restedxp-windows.lua` and `test-skins-restedxp-rail.lua`, through `Tools/regression/restedxp_fake.lua`, a stand-in RestedXP written from those names and anchored as RestedXP's `GuideWindow.lua` anchors its frames.

## Why

- **One module, one switch per window.** Players turn the module on once and then pick windows. Each window's switch lives in the module's own settings section, so a profile string carries every choice, and the registry adds the switches so a skin file cannot forget its own.
- **Skins wait for their window.** A skin applies on the window's first show, after its Blizzard addon has loaded. A player who never opens the talent window never loads `Blizzard_PlayerSpells` for KstyleUI, and never pays for its skin.
- **Applied once, kept until reload.** Restyling Blizzard frames in place cannot be undone cleanly, so a skin runs once per session, and turning a window or the module off asks for a reload instead of half-restoring Blizzard's art.
- **Combat waits.** Some windows hold protected children. A skin that would run in combat waits for `Combat.Queue`, so it never touches a protected frame in lockdown.
- **Quality you can read at a glance.** The rim replaces Blizzard's thin quality border with a chamfered ring in the item's quality colour, as `03_windows_rogue.jpg` shows. Common and poor items stay plain by default, so the colour marks the items that matter.
- **No Layout keys.** Every frame this module makes is chrome parented to a Blizzard window. Layout never moves Blizzard frames, and registering the chrome would pull it off its window, so the module registers no Layout elements. Blizzard's panel manager and Edit Mode keep placing the windows.
- **One look for every window.** Text, bars and accents go through `ns.Style`, so the font, size, edge, bar and accent settings change every skinned window at once, and part B and C skins get them for free.
- **Parallel parts never collide.** Each part adds its files between its own comment lines in `Skins.xml`, and `Module.lua` loads last to read every skin, so three branches can add skins at the same time and merge cleanly.
- **Part B follows the module's look.** The six part B skins style their text with `Style.Text`, their bars with the shared bar settings and their selection edges with `Style.Accent`, so the Text, Bars and Accent settings reach them with no settings of their own beyond the quality rims.
- **Quality comes from Blizzard's border.** Blizzard sets the item quality colour on each button's `IconBorder` through several paths (`SetItemButtonQuality`, the mixin method, direct calls). Following the border's colour catches all of them without hooking a global function every bag and bank button also calls.
- **Blizzard replaces some scripts.** `MainMenuFrameMixin:AddButton` calls `SetScript` for `OnEnter` and `OnLeave` on every pooled game menu button each time the menu opens, `ClassTrainerFrame_InitCategoryButton` does the same to each trainer category row, and `ClassTrainerFrame_SetTrainButtonEnabled` to the train button. `SetScript` drops hooked scripts, so the skins hook those two scripts again after each of these calls.
- **The core helpers paint the interface accent.** `KstyleUI.Skin` lights hover edges, check marks, tab underlines, the selected tab's wash (an accent fill at `Skin.TAB_WASH_ALPHA` over the tab's segment of the pill, so Inbox reads as the open tab at a glance) and scroll thumbs in the Appearance accent. Part B swaps their painters on its own frames for ones that use `Style.Accent`, so the module's Accent setting reaches every part B control.
- **Atlas icons keep their coordinates.** Texture coordinates on an atlas texture index the whole atlas sheet, so the item helper crops only file icons.
- **Profession skill bars are KstyleUI bars.** Blizzard draws them with a masked flipbook texture, not a status bar, so the shared bar texture, colour and fill direction can only reach a bar KstyleUI draws over them.
- **Part C windows keep Blizzard's placement.** Edit Mode places the loot window, `GroupLootContainer` stacks the loot rolls, and the popup code stacks `StaticPopup1` to `4`. Layout never moves Blizzard frames, so these skins add no Layout keys and only restyle what Blizzard places.
- **Popup text takes the skin's face at the game's size.** Popups size themselves from their text, and the game's accessibility text size setting works through user-scaled font objects. The sweep reads each string's size from its font object and sets the face at that size, so the popup still measures the text it shows; a text size changed after the skin applied shows at the new size after `/reload`, because a string with its own font no longer follows its font object.
- **One face in every window.** Judges in the first ranking round found Blizzard's default sans and its yellow labels in the talent, popup and mail windows, and body text at seven to nine pixels in the dense ones. The registry's sweep after `Apply` gives every Blizzard string the body face at no less than the body size and maps the yellow to the `text` token, so a skin only has to style what carries meaning; a skin opts out (`sweep = false`) or fences a subtree (`sweepSkip`) where Blizzard's own type must stay.
- **Some meaning stays Blizzard's.** Item names keep their quality colour, addon titles their load-state colour, and roll buttons their icons. The addon list's grey check for an addon on for some characters becomes a grey KstyleUI mark, so the state still reads.
- **Roll timers are KstyleUI bars.** Blizzard puts each roll's timer one level below the roll frame every time a roll shows, so any glass panel behind the roll would cover it, and a roll at frame level 1 leaves no level free below the timer. The skin hides Blizzard's timer and draws its own bar above the panel, fed by hooks on the timer's setters.
- **Parts add preview samples before the preview loads.** `Skins.xml` loads every part's files before `Preview.lua`, so a part adds its sample builder to `ns.previewParts` and `Preview.lua` builds them under part A's sample.
- **Part C controls share part B's accent painters.** `KstyleUI.Skin` paints hover edges, check marks and scroll thumbs in the interface accent. Part B already swaps those painters for ones that use `Style.Accent`, and part B loads first, so part C calls `ns.PartBKit.Accent` instead of keeping a second copy, and falls back to the core look if part B is missing.
- **The guild opens in the communities window.** On Forever `ToggleGuildFrame` opens `CommunitiesFrame` from `Blizzard_Communities`, and the TOC's `Camelot` override only hides personal achievements, so the guild skin targets that window and waits for its addon to load.
- **Social rows keep what carries meaning.** Friend rows keep Blizzard's online, offline and Battle.net tints and their game icons, and member rows keep class icons and name colours, so the skin changes the chrome, fonts and highlights and leaves the status cues alone.
- **RestedXP's glass grows outward.** The hook rules forbid moving RestedXP's text, buttons and scroll bar, and RestedXP keeps them 4 to 6 units from its frames' sides, under a 12-unit corner cut. The glass is KstyleUI's own frame, so it reaches past the sides instead (`Skin.Backdrop`'s `inset`), by the same content-inset rule the HUD panels pad with, and the scroll bar's gutter line is drawn on that frame. `Tools/render/shoot.sh restedxp` lays the windows out as RestedXP does, so the render shows the margins the game will.
- **RestedXP's theme comes through its own theme API.** RestedXP colours its windows from the active theme, so a theme reaches the parts the chrome leaves alone: step rows, map pins, route lines, timer bars and the v2 cards. The chrome adds what a theme cannot: the chamfered glass, KstyleUI's buttons, scroll bars and check boxes.
- **The player's RestedXP theme is theirs.** The skin remembers it and puts it back only while RestedXP still shows `KstyleUI`, so a theme the player picked since is never undone.
- **Shared frames are dressed only while RestedXP uses them.** The menu library's lists and AceGUI's pooled frames serve other addons too, so the skin hides their art with a remembered alpha and gives it back when RestedXP's menu or dialog closes, instead of restyling them for good.
- **Legacy page art is a choice.** Each Legacy page has a large painted backdrop. The skin hides it by default so the pages read as glass like every other window, and the `pageArt` switch brings it back at once, because the art is Forever's own and some players will want it. The cards and tree nodes keep Blizzard's art: their states are drawn by the shared talent and renown code and change too often to restyle safely.
