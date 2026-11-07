# KstyleUI_Skins

Character sheet, spellbook and talents, quest log and objective tracker, world map, game menu, group finder, mail, merchant, trainer, professions, social windows, Legacy, loot, popups and ready check.

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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Skins.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Load order

`Skins.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Style.lua` | `ns.Style`: the shared look settings and the functions that apply them |
| `Parts.lua` | `ns.Parts`: quality rims and accent lines drawn on KstyleUI's own child frames |
| `Registry.lua` | `ns.Skins`: the skin registry |
| Part A, B and C sections | One file per skin. Each part adds its `Script` lines between its own two comment lines, so parallel branches never edit the same lines. |
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
| `Style.Track(object)` | `object:Restyle()` runs when a look setting, the theme or the profile changes. |
| `Style.Setting(group, key)` | A checked value, or the default. |

### Parts

`ns.Parts` holds the pieces skins share. Each one draws on KstyleUI's own child frames and hides Blizzard art only through `KstyleUI.Skin`, so parts B and C can use them too.

| Function | Behaviour |
| --- | --- |
| `Parts.Rim(frame, opts) -> rim` | A raised chamfered tile behind `frame`, on a child frame one level below it, `opts.outset` units outside `opts.target` (default `frame`). `rim:SetRimColor(r, g, b, a)` draws a 2-unit chamfered ring and an inner hairline in that colour; `nil` removes both. A second call returns the same rim. `Parts.RimOf(frame)` returns it. |
| `Parts.AccentLine(owner, opts) -> line` | A 2-unit accent divider along the owner's `BOTTOM` (default) or `TOP` edge, or across `opts.anchor`. It follows the accent setting. |
| `Parts.Hush(texture)`, `Parts.Divider(owner, texture)` | Hide one Blizzard texture for good, and replace a Blizzard divider texture with an accent line at the same place. |
| `Parts.SideTab(tab)` | Strips a side tab, a sidebar check button or an icon-only tab-system tab but its `Icon`, and rims the icon: accent while checked or selected, `text` at 50% under the mouse. It follows `SetChecked`, `SetTabSelected`, clicks and hover, and keeps a selection Blizzard made before the skin. |
| `Parts.Glyph(button, textureName, opts) -> texture` | Strips a small Blizzard button, such as a page arrow or a red size button, and draws a 10-unit line glyph (`glyphChevron`, `glyphClose`) on it: `text` at rest, `textHover` under the mouse, `textDisabled` when disabled. `opts.flip` points a chevron up; `opts.rotation` turns it, in radians. |
| `Parts.Dropdown(dropdown)` | Strips a `WowStyle1DropdownTemplate` button but its `Arrow` and puts a raised tile behind it. |
| `Parts.StripLeaves(frame)` | Strips each child of `frame` that has no children of its own, such as the scroll lines on a list. |
| `Parts.Wash(highlight)` | Replaces a row highlight frame's art with a flat accent wash at 12%, which Blizzard's own fade of the frame still shows and hides. |
| `Parts.EachRow(scrollBox, fn)` | Runs `fn(row, elementData)` for each row a `WowScrollBoxList` shows now and later, through `ScrollUtil.AddInitializedFrameCallback`; without it, after each `Update`. `fn` must be safe to run again on a recycled row. |
| `Parts.FillBar(bar)` | Restyles a `ColoredProgressBarTemplate` bar, such as a reputation bar: Blizzard's background and rounded mask go, a 10-unit fill in the bar texture sits on a dark chamfered track, Blizzard's standing colour goes through `Style.BarColor`, and the fill direction setting anchors the fill left or right. |

While the module runs, a change to any look setting restyles every text and bar the skins styled. The settings window's preview shows the settings whether or not the module runs.

## Skins

### Character sheet (`Character.lua`, key `character`)

Forever's character window (`CharacterFrame` in `Blizzard_UIPanels_Game/Camelot`, created before any addon loads) has side tabs instead of bottom tabs, a left pane with the paper doll and a right pane with the stats. The skin applies on the window's first show:

- **Window.** `Skin.Window` puts the glass panel behind it and restyles the close button and title. The left and right pane art and the divider between them go. The side mode tabs (character, reputation, skills, PvP, currency, statistics) become `Parts.SideTab`s. The pane toggle button becomes a chevron that points the way the pane will move.
- **Paper doll.** Every equipment slot loses Blizzard's slot frame and quality border, keeps its icon (cropped 7% each side) and overlays, and gets a `Parts.Rim` whose ring shows the item's quality colour (`Theme.QualityColor`). A hook on `PaperDollItemSlotButton_Update` repaints a slot whenever Blizzard updates it. The model's backdrop and the top strip go, and the level line is a caption.
- **Stats.** The stats list's frame art goes. Category rows read as captions over an accent line, labels in the body font, values in the number font. Rows the list shows later are skinned as they appear.
- **Reputation and currency.** Each list's scroll bar, filter dropdown and scroll lines are restyled. Header rows lose their art and keep their expand icon. Entry rows get a flat accent highlight, and reputation bars become `Parts.FillBar`s. The detail pane's divider, checkboxes, buttons and standing bar are restyled. Blizzard's own colours for names, counts and check labels stay, because they carry meaning (inactive currencies, factions at war).

| Setting | Default | Row |
| --- | --- | --- |
| `character.qualityBorders` | `true` | toggle: colour each slot's rim by its item's quality |
| `character.qualityFrom` | 2 (uncommon) | dropdown: the lowest quality that colours a rim, from poor (0) to epic (4) |

A missing part (a slot, the reputation or currency tab, the paper doll hook) is logged as `character: <name> is missing on this client` and skipped.

### Spellbook and talents (`Spellbook.lua`, keys `spellbook` and `talents`)

On Forever the spellbook and the talents live in one window, `PlayerSpellsFrame`, from the load-on-demand `Blizzard_PlayerSpells` (its `Camelot/` files). Forever hides the window's tab strip and opens each part from its own micro button. Both skins wait for the addon to load, so KstyleUI never loads it, and apply on the window's first show. Each has its own switch; both restyle the shared window once.

- **Window.** The glass panel, close button and title. The red maximise and minimise buttons become chevrons.
- **Spellbook.** The book's page art (top bar, page backgrounds, corner, bookmark) goes. Forever's category tabs are icon-only square tabs (`AddIconTab`): each keeps its icon on a `Parts.SideTab` rim, accent while selected, and a category added later (a pet's) is skinned through a hook on the tab system's `AddTab`. The search box gets the raised tile. Each spell item loses its backplate, border, shadow and sheen; its icon loses Blizzard's rounded mask, is cropped 7%, and sits on a `Parts.Rim`. Names are heading text, sub-names body text. Section headers become display text over an accent line. The paging arrows become chevrons and the page number a caption. A hook on `PagedSpellsFrame.DisplayViewsForCurrentPage` skins every page as it shows; in combat it waits for `Combat.Queue`, because spell buttons can be protected.
- **Talents.** The frame's own background, border and dividers go; the class background art and the tree's animations stay. The tab strip, search box, Apply and inspect-copy buttons, and the unspent-points counter are restyled. The talent nodes keep Blizzard's art: their states (available, maxed, locked, choice) are drawn by the shared talent UI and change too often to restyle safely.

### World map and quest log (`WorldMap.lua`, keys `worldMap` and `questLog`)

`WorldMapFrame` comes from `Blizzard_WorldMap`. Its window chrome is a separate `BorderFrame` in the `HIGH` strata, drawn over the map canvas, so a fill there would cover the map.

- **World map.** The glass panel goes on `WorldMapFrame` itself, one level below the map canvas. `BorderFrame` only loses its art (nine-slice, background, portrait, title bar, inset line): its close button is restyled, its title takes the heading font, and the red maximise and minimise buttons become chevrons. The navigation bar loses its tiled background and sits on a raised tile; its breadcrumb buttons and the tracking-options button keep Blizzard's art, because their art is their only label.
- **Quest log.** `QuestMapFrame` (from `Blizzard_UIPanels_Game`, attached to the map when it loads) sits on a raised tile. The quest list's background, edge and frame go, its scroll bar and search box are restyled, and a hook on `QuestLogQuests_Update` sets the skin font on every header and quest title the list shows. The details view keeps its parchment, because Blizzard colours quest descriptions and objectives dark for it; its frame goes, and its back, abandon, share and track buttons and scroll bar are restyled. Quest and objective colours stay Blizzard's.

### Objective tracker (`Tracker.lua`, key `tracker`)

`ObjectiveTrackerFrame` comes from `Blizzard_ObjectiveTracker`. Edit Mode keeps placing and sizing it, as `v3/` shows it under the minimap's auras.

- Blizzard's nine-slice backdrop goes, and a glass panel sits 8 units outside what the tracker shows (setting `tracker.panel`). Edit Mode's opacity slider drives Blizzard's backdrop, which the skin hides, so the panel has its own switch.
- The panel follows the content, not the tracker frame: Edit Mode sizes `ObjectiveTrackerFrame` to its height setting, or down to the bottom of the screen in the default position, whatever is tracked. The panel surrounds a KstyleUI frame (`Skin.Backdrop`'s `target`) whose top is the tracker's top. Its bottom is Blizzard's `NineSlice` bottom, which Blizzard anchors 10 units below the last module with content on every layout, so the panel grows and shrinks with each quest and each collapsed module. When the tracker is collapsed, or nothing is tracked (Blizzard then hides the tracker, except in Edit Mode), the bottom is the tracker's header instead.
- A hook on the tracker's `UpdateHeaderPosition` re-checks collapse and content after every layout. Blizzard's last step of `ObjectiveTrackerFrameMixin.Update` calls it through `self`, so the hook runs on dirty updates too. A hook on `Update` itself would miss those: `DirtiableMixin` runs the `Update` the container captured at load.
- The tracker's header and every module header lose their art and read as captions over an accent line. Modules the tracker adds later are skinned through a hook on its `AddModule`.
- Quest progress bars and timer bars lose their border art, sit on a dark tile, and take the shared bar texture, colour and fill (`Style.StatusBar`), through hooks on each module's `GetProgressBar` and `GetTimerBar`. Their labels take the caption font; a timer keeps Blizzard's colour, which turns red as time runs out.
- With `tracker.font` on, Blizzard's two tracker font objects take the skin face and edge through `Style.ApplyFont`, at Blizzard's size times the shared text size. Quest titles (each block's `HeaderText`) and objective lines (each line's `Dash` and `Text`) inherit `ObjectiveTrackerLineFont` in XML and never set a font of their own, so every pooled line, new or reused, shows the skin face. `ObjectiveTrackerHeaderFont` is painted too, though the module and tracker headers it feeds are captions through `Style.Text`. A face the game cannot load falls back as `Style.ApplyFont` describes, so the tracker matches the rest of the interface. A hook on their `SetFontObject` keeps the skin font when Edit Mode changes the tracker's text size, and reads the new size from the font family's name (`ObjectiveTrackerFont16`). Turning the font off needs a reload.
- Not restyled: the auto-accept quest pop-ups, the scenario stage block, the reward toast and the quest item buttons' hotkey and count. They keep Blizzard's fonts.

| Setting | Default | Row |
| --- | --- | --- |
| `tracker.panel` | `true` | toggle: the glass panel behind the tracker |
| `tracker.font` | `true` | toggle: the skin font for tracker text |

## Part B windows

`PartB/` holds the skins for the game menu, Forever's group finder, mail, the merchant, the trainer and the professions window. `PartB/Kit.lua` loads first and sets `ns.PartBKit`, the helpers the six skins share. Every helper takes a Blizzard frame, logs and skips a missing or forbidden one, waits for `Combat.Queue` when the frame is protected in combat, and returns what it made on a second call.

| Skin | Key | Blizzard addon | Window | What changes |
| --- | --- | --- | --- | --- |
| `GameMenu.lua` | `gameMenu` | `Blizzard_GameMenu` | `GameMenuFrame` | The dialog border and header art go; a glass panel, the heading font and a raised tile for each pooled button come. A hook on `InitButtons` skins buttons the menu adds later. |
| `GroupFinder.lua` | `groupFinder` | `Blizzard_GroupFinder_VanillaStyle` | `LFGParentFrame` | The listing, browse and who-list pages become glass windows. Side tabs, dropdowns, check boxes, scroll bars, the comment box and the result and who rows are restyled. |
| `Mail.lua` | `mail` | `Blizzard_MailFrame` | `MailFrame` | The inbox, the send form and `OpenMailFrame`. Every inbox item and attachment gets a quality rim; the cash-on-delivery tint and the coin icons stay. |
| `Merchant.lua` | `merchant` | `Blizzard_UIPanels_Game` | `MerchantFrame` | Item rows become raised tiles with quality-rimmed icons; repair and junk buttons keep their icons; the page buttons get chevrons. |
| `Trainer.lua` | `trainer` | `Blizzard_TrainerUI` | `ClassTrainerFrame` | The skill bar takes the shared bar look; category and skill rows become tiles that light while selected. |
| `Professions.lua` | `professions` | `Blizzard_Professions` | `ProfessionsFrame` | Side tabs, the recipe list, the schematic, tool slots and the craft-count spinner. The skill bars on the crafting and overview pages are drawn by KstyleUI status bars. |

The mail, merchant and professions skins add a `qualityRims` switch, on by default, under their window's switch.

| Helper | Behaviour |
| --- | --- |
| `Item(button, opts)` | Hides the slot art, keeps and crops the icon (`opts.icon`, `button.icon` or `button.Icon`; an atlas icon is not cropped), and puts `Parts.Rim` behind it. The rim follows the colour Blizzard gives `IconBorder` through hooks on its `SetVertexColor`, `Show`, `Hide` and `SetShown`; white and grey give no ring. `opts.window` names the skin whose `qualityRims` switch applies. `opts.normal` is for buttons whose icon is the normal texture. |
| `Dropdown(dropdown)`, `SideTab(frame)` | `Parts.Dropdown` and `Parts.SideTab`, so part B's dropdowns and side tabs match part A's. |
| `Arrow(button, direction)` | `Parts.Glyph` with a chevron turned `left` or `right`, for page and spinner buttons. |
| `Hush(frame, ...)` | `Parts.Hush` on each named texture. |
| `Select(frame, marker)` | A raised tile behind a list row whose edge takes the module's accent under the mouse and while `marker`, Blizzard's selection texture, shows. |
| `Square(button)` | An icon button on a raised tile that keeps its `Icon`. |
| `Inset(frame)`, `MoneyBox(box)`, `InputScroll(scroll)`, `NumberBox(box)` | Inset art, money and spinner boxes, and scrolling text boxes. |
| `RankBar(frame)` | Hides a `ProfessionsRankBarTemplate`'s art and draws a `Widgets.StatusBar` over it that mirrors Blizzard's `Update(professionInfo)`. A secret value passes straight to the bar. |
| `Bar(statusBar)` | Keeps a Blizzard status bar's fill and applies `Style.StatusBar`. |
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
| `Loot.lua` | `loot` | `Blizzard_UIPanels_Game` | `LootFrame` | The flat panel, item card art, quality stripe and list shadows go; a glass panel, the close glyph and a slim scroll bar come. Each row becomes a raised tile; its icon is cropped and rimmed by quality, its quality label takes the quality colour, and Blizzard's highlight becomes an accent wash. |
| `LootRolls.lua` | `lootRolls` | `Blizzard_UIPanels_Game` | `GroupLootFrame1` to `4` | Each roll frame loses its toast art and sits on a glass panel. The item icon is rimmed by the roll's quality (`GetLootRollItemInfo`, repainted through a hook on `GroupLootFrame_SetupItemDisplay`), and a KstyleUI timer bar in the shared bar look mirrors Blizzard's hidden timer. The need, greed, transmog and pass buttons keep their icons. |
| `Popups.lua` | `popups` | `Blizzard_StaticPopup_Game` | `StaticPopup1` to `4` | The dialog art goes and a glass panel comes. Buttons, the close button, the edit box, the money boxes (their coin icons stay) and the dropdown are restyled. An item popup's icon is rimmed in the colour Blizzard gives the item's name, through a hook on its `SetTextColor`; white and grey give no ring. The alert icon, separator and progress bar stay. |
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
| `Kit.Bar(statusBar) -> chrome` | Keeps a Blizzard status bar's fill, hides its other art, applies `Style.StatusBar`, and draws a dark track on the bar itself, in its `BACKGROUND` and `BORDER` layers under the fill, so art at the bar's own frame level cannot cover it. |
| `Kit.MirrorBar(statusBar, parent, width, height) -> bar` | Hides a Blizzard status bar and draws a `Widgets.StatusBar` one level above `parent` that follows its range, value and colour through hooks on `SetMinMaxValues`, `SetValue` and `SetStatusBarColor`, in the shared bar texture, colour and fill direction. |
| `Kit.EditBox(box, keepKeys)` | Strips an edit box's art and `NineSlice` but the named textures, such as a coin icon, then part B's `EditBox`, whose focus edge takes the module's accent. |
| `Kit.TriState(check)` | After `Skin.CheckBox`, draws the check mark grey while Blizzard desaturates the box's `CheckedTexture`, as the addon list does for an addon on for some characters. |
| `Kit.Texts(frame, role, colorName)`, `Kit.Crop(icon)`, `Kit.Below(panel, frame, levels)` | Styles every font string on a frame; crops an icon; puts a panel a number of levels below a frame. |
| `Kit.Preview(builder)` | Adds a sample to the settings preview. `Preview.lua` calls `builder(frame, anchor)` under the samples before it and keeps the frame it returns; the preview's `Refresh` calls the sample's `Refresh`. |

Tests: `Tools/regression/test-skins-partc-loot.lua`, `test-skins-partc-dialogs.lua`, `test-skins-partc-social.lua` and `test-skins-partc-legacy.lua`.

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
- **The core helpers paint the interface accent.** `KstyleUI.Skin` lights hover edges, check marks, tab underlines and scroll thumbs in the Appearance accent. Part B swaps their painters on its own frames for ones that use `Style.Accent`, so the module's Accent setting reaches every part B control.
- **Atlas icons keep their coordinates.** Texture coordinates on an atlas texture index the whole atlas sheet, so the item helper crops only file icons.
- **Profession skill bars are KstyleUI bars.** Blizzard draws them with a masked flipbook texture, not a status bar, so the shared bar texture, colour and fill direction can only reach a bar KstyleUI draws over them.
- **Part C windows keep Blizzard's placement.** Edit Mode places the loot window, `GroupLootContainer` stacks the loot rolls, and the popup code stacks `StaticPopup1` to `4`. Layout never moves Blizzard frames, so these skins add no Layout keys and only restyle what Blizzard places.
- **Popup text keeps the game's scaled fonts.** Popups size themselves from their text through the text size setting in the game's accessibility options. Changing the popup fonts would break that sizing, so the popup skin restyles the panel and controls and leaves the text to the game.
- **Some meaning stays Blizzard's.** Item names keep their quality colour, addon titles their load-state colour, and roll buttons their icons. The addon list's grey check for an addon on for some characters becomes a grey KstyleUI mark, so the state still reads.
- **Roll timers are KstyleUI bars.** Blizzard puts each roll's timer one level below the roll frame every time a roll shows, so any glass panel behind the roll would cover it, and a roll at frame level 1 leaves no level free below the timer. The skin hides Blizzard's timer and draws its own bar above the panel, fed by hooks on the timer's setters.
- **Parts add preview samples before the preview loads.** `Skins.xml` loads every part's files before `Preview.lua`, so a part adds its sample builder to `ns.previewParts` and `Preview.lua` builds them under part A's sample.
- **Part C controls share part B's accent painters.** `KstyleUI.Skin` paints hover edges, check marks and scroll thumbs in the interface accent. Part B already swaps those painters for ones that use `Style.Accent`, and part B loads first, so part C calls `ns.PartBKit.Accent` instead of keeping a second copy, and falls back to the core look if part B is missing.
- **The guild opens in the communities window.** On Forever `ToggleGuildFrame` opens `CommunitiesFrame` from `Blizzard_Communities`, and the TOC's `Camelot` override only hides personal achievements, so the guild skin targets that window and waits for its addon to load.
- **Social rows keep what carries meaning.** Friend rows keep Blizzard's online, offline and Battle.net tints and their game icons, and member rows keep class icons and name colours, so the skin changes the chrome, fonts and highlights and leaves the status cues alone.
- **Legacy page art is a choice.** Each Legacy page has a large painted backdrop. The skin hides it by default so the pages read as glass like every other window, and the `pageArt` switch brings it back at once, because the art is Forever's own and some players will want it. The cards and tree nodes keep Blizzard's art: their states are drawn by the shared talent and renown code and change too often to restyle safely.
