# KstyleUI_Tooltips

Glass tooltips, quality and class colours, optional spell and item IDs, and cursor anchoring.

| Field | Value |
| --- | --- |
| Module name | `Tooltips`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Tooltips.toc` lists `Tooltips.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Tooltip content changes use `TooltipDataProcessor.AddTooltipPostCall`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Tooltips.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Tooltips.xml` loads them in this order. Tests: `Tools/regression/test-tooltips-logic.lua` (the pure rules), `test-tooltips.lua` (glass, fonts, scale, anchor and settings) and `test-tooltips-units.lua` (unit lines, the health bar, IDs, the icon and embedded items), all against stand-in Blizzard tooltips from `tooltips_env.lua`.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Logic.lua` | Pure rules: the fixed anchor's corner, font flags, which item qualities light the edge, the line colours that soften, the tooltip scale, the guild text and ID text |
| `Settings.lua` | The defaults, the settings page and `Settings.Get(key)`, which returns the default for a saved value that is not allowed and logs it once |
| `Style.lua` | The glass on each tooltip, its edge, title divider and icon, the embedded item border, the tooltip fonts and the tooltip scale |
| `Anchor.lua` | The `tooltips.anchor` Layout element and the hook on `GameTooltip_SetDefaultAnchor` |
| `Health.lua` | GameTooltip's health on a KstyleUI status bar |
| `Units.lua` | Unit name colours, the guild and target lines, the unit edge and the bar colour |
| `Content.lua` | The `TooltipDataProcessor` post-call that runs the rest for each tooltip type |
| `Preview.lua` | The settings window's live sample |
| `Module.lua` | `Modules.Register`, `Enable`, `Disable` and `Options.Register` |

## What it restyles

`GameTooltip`, `ShoppingTooltip1` and `2`, `ItemRefTooltip`, `ItemRefShoppingTooltip1` and `2`, and `EmbeddedItemTooltip`. A tooltip missing on the client is logged and skipped.

| Part | How |
| --- | --- |
| Border | `Skin.Strip` sets the alpha of every texture of the tooltip's `NineSlice` to 0 and hooks its `SetAlpha`. Only the `NineSlice` is stripped: the tooltip's own `Texture1` to `Texture30` hold inline icons. |
| Glass | A child frame of KstyleUI's own with a panel `Chrome` (6-unit chamfers, double bevel, shadow, grain) on all points of the tooltip. `SetUsingParentLevel(true)` draws it at the tooltip's level, behind the text, as Blizzard's `NineSlice` does. |
| Edge | The chrome's inner hairline. An item of uncommon quality or better lights it in `Theme.QualityColor`. `OnTooltipCleared` and `OnHide` return it to `edgeInner`. |
| Divider | A `divider` gradient one border thick, 1 unit under the title line, in the accent, on any tooltip with two lines or more. |
| Line colours | Lines in Blizzard's `NORMAL_FONT_COLOR` gold become `text`, lines in `HIGHLIGHT_FONT_COLOR` white become `textEmphasis`. Green, red, grey and quality colours stay. |
| Icon | On `GameTooltip` and `ItemRefTooltip`: a 34-unit raised tile left of the tooltip's top left corner with the item's or spell's icon, cropped and masked by `iconMask`, set through `KstyleUI.Icons.Apply` so a custom icon set applies. It hides when the tooltip clears and while a comparison tooltip shows beside it, so the two never overlap. |
| Embedded items | `GameTooltip.ItemTooltip` and `EmbeddedItemTooltip.ItemTooltip` (quest rewards) lose Blizzard's `IconBorder` by alpha. A raised tile two borders outside the icon takes the colour Blizzard gives `IconBorder` through a hook on its `SetVertexColor`, or `edgeInner` while it is hidden. |
| Compare label | The shopping tooltips' `CompareHeader` loses its art and sits on a raised tile with the label in the caption font. |
| Close button | `ItemRefTooltip.CloseButton` gets `Skin.CloseButton`. |
| Fonts | `GameTooltipHeaderText`, `GameTooltipText` and `GameTooltipTextSmall` take the title, line and small line fonts. `Disable` restores Blizzard's fonts and shadows. |
| Scale | Each tooltip's scale makes one tooltip unit one root unit, times the anchor element's scale. `Disable` restores each tooltip's own scale. |

## Content

One post-call for every tooltip type runs in this order, so the tooltip sizes itself once with all of it:

1. Soften Blizzard's gold and white lines.
2. The type's part:
   - **Item**: the quality edge, the item and icon ID lines, the icon.
   - **Spell** and **UnitAura**: the spell and icon ID lines, the icon.
   - **Unit**: the name in its class colour (players) or reaction colour (everyone else), `<Guild>` or `<Guild> Rank` on Blizzard's guild line (the line whose text is the guild name, bare or in brackets) in `friendly` green for your own guild and `textEmphasis` otherwise, a `Target` line with the target's name in its colour or `You` in the accent, the unit edge, and the health bar's colour.
   - **Object**: the health bar's colour.
3. The title divider, once the lines are final.

Every value from the game is checked with `issecretvalue` before it is compared. A secret GUID skips the unit's lines; a secret class falls back to the reaction colour; a secret target name adds no line; a secret item or spell ID adds no ID line and no icon. Each skip is logged once.

## Health bar

Blizzard's `GameTooltip.StatusBar` keeps working: its own post-call starts and stops its watch on the unit, and its `OnUpdate` sets its value. The module hides its art by alpha, hooks its `SetValue` with `hooksecurefunc`, and passes each value straight to a KstyleUI `StatusBar` on the glass, so a secret health percentage reaches the engine untouched and Lua never reads it. The KstyleUI bar shows and hides with Blizzard's through `HookScript`.

The bar is horizontal under the tooltip or vertical beside its right edge, with the texture, colour source, fill direction and thickness from the settings, a `track` background and a raised tile border.

## Anchor

`Anchor.lua` builds an empty 180 by 24 frame on `KstyleUI_Root` and registers it with Layout as `tooltips.anchor`, scalable, at the DPS position from `Setup.Layouts`: above the threat meter at the right. Its mover plate shows in Layout Mode; it draws nothing otherwise.

- **Tooltip anchor** (the default): the hook on `GameTooltip_SetDefaultAnchor` moves `GameTooltip` to the anchor's corner nearest the screen corner, so a tooltip at the bottom right grows up and to the left. Only tooltips Blizzard puts at its default place move; a tooltip a button anchors to itself stays there.
- **Mouse cursor**: the hook calls `SetOwner(parent, "ANCHOR_CURSOR_RIGHT", cursorX, cursorY)`.
- The anchor element's scale, from Layout Mode or the element's Size setting, is every tooltip's scale.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `anchor` | `"fixed"` | dropdown: `fixed` (the tooltip anchor) or `cursor` |
| `cursorX`, `cursorY` | 0 | sliders, -64 to 64, shown for the cursor |
| `followFont` | `true` | toggle: use Appearance's font for every line |
| `title`, `body`, `small` | `{ font, size, outline }`: KstyleUI's font at 16, 13 and 11 units, outline `NONE` | per text kind: a font row (shown while `followFont` is off), a size slider from 8 to 32 and an outline dropdown (`NONE`, `OUTLINE`, `THICKOUTLINE`) |
| `qualityEdge` | `true` | toggle |
| `divider` | `true` | toggle |
| `softColors` | `true` | toggle |
| `accentSource` | `"class"` | dropdown: `class` follows KstyleUI's accent, `custom` uses `accentColor` |
| `accentColor` | the `accentDefault` token | colour, shown for `custom` |

| `classNames` | `true` | toggle |
| `guildLine`, `guildRank` | `true`, `false` | toggles; the rank row shows while the guild line is on |
| `targetLine` | `true` | toggle |
| `unitEdge` | `false` | toggle |
| `healthBar` | `true` | toggle |
| `bar` | `{ texture, color, custom, orientation, reverse, size }`: the `Glass` texture, `class`, the `friendly` token, `HORIZONTAL`, `false`, 6 | a texture row, a colour source dropdown (`class`, `reaction`, `custom`), a colour (shown for `custom`), an orientation dropdown, a reverse toggle and a thickness slider from 2 to 16 |
| `itemID`, `spellID`, `iconID` | `false` | toggles |
| `icon`, `iconSize` | `true`, 34 | a toggle and a slider from 20 to 64 |

Sizes are in tooltip units, which are root units at an anchor scale of 1, times Appearance's text size.

## Why

- Tooltips are Blizzard frames that Blizzard's own code fills, shows, sizes and moves many times a second, so the module restyles them in place instead of replacing them. Everything it draws sits on its own child frames, and per-tooltip state lives in `Safe.Side`, because a field written onto a tooltip taints the secure code that later fills it with secret unit data, and a tainted comparison of a secret value raises an error in Blizzard's own tooltip code.
- Blizzard's border is hidden by alpha, not `Hide`, because `SharedTooltip_SetBackdropStyle` shows the `NineSlice` again on every tooltip, and an alpha hook keeps it hidden without fighting that call.
- Line colours, the divider and the quality edge come from `TooltipDataProcessor` post-calls, the one path Blizzard gives addons into tooltip content. They run after Blizzard adds the data's lines and before it shows the tooltip, so the tooltip sizes itself once with the changes. They run again when Blizzard rebuilds a tooltip for new data, so nothing is added twice.
- The module changes Blizzard's tooltip font objects instead of each line, because the game creates tooltip lines on demand and every line follows its font object. Other Blizzard text that uses `GameTooltipText` changes size with it.
- `GameTooltip:SetScale`, `SetPoint`, `ClearAllPoints` and `SetOwner` are the calls Blizzard's own code makes on the tooltip. GameTooltip is not a protected frame, so they are allowed in combat and never block an action. The taint scan does not see them because they run on a parameter or a list entry; this paragraph is their review.
- Tooltip sizes are in root units so a tooltip keeps its proportions on every screen and follows Appearance's interface size like every other KstyleUI element. Folding the scale into the anchor element gives the player one size control, in Layout Mode and on the settings page, instead of two that multiply.
- The health bar mirrors Blizzard's bar instead of reading health itself, because tooltip health is secret in combat. Blizzard's secure code reads it and calls `SetValue`; a `hooksecurefunc` post-hook hands the same value to KstyleUI's bar, a widget setter that accepts secrets. Blizzard's bar keeps its own guid in attributes for the same reason, and the module never touches them.
- The target and guild lines read names only after `issecretvalue` says they are plain, and never pass a secret to `AddLine`, because Blizzard's own comments note that secret line data on a tainted path can leave a tooltip with no lines.
- Disable puts back the fonts and the scale and hides the KstyleUI health bar, but keeps the glass, because Blizzard's border and bar art are held at alpha 0 by hooks that cannot be removed. The module is a reskin, so the core asks for a reload.
