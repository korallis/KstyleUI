# Popup surfaces

LEE-118 distinguishes a floating popup from an embedded tile. `Widgets.Chrome(owner, { popup = true, ... })` opts an existing surface into opaque non-Glass material paint. `Widgets.Panel`, `Skin.Backdrop`, `Skin.Window` and the Skins window helpers forward that option.

For Flat, Slate, ForgedTicks and ForgedBrackets, the popup's surface fill is alpha 1 regardless of Panel opacity. Grain and forged-border strength use the material's authored strength. This prevents controls behind an open menu from reading through it. The flag does not change geometry: a tile menu retains its small tile-border dimensions, without card-sized forged frames or brackets; Flat and Slate use their material's rim tint, while the forged choices keep the original tile rim tint. Card-shaped dialogs and tooltips retain their existing card finish. Explicit custom colours and custom silhouettes retain their authored treatment. The flag is a construction option, not a setter for an already-created backdrop.

Glass keeps the original fill, alpha and borders. Existing show/hide fades still animate the whole popup; the settled popup is opaque under non-Glass materials. The General section containing Panel opacity and Panel shadows is now **Panel appearance**, including all shipped locales. That requested heading change is the only intentional Glass Options-text difference.

## Surfaces covered

| Surface | Owner |
| --- | --- |
| Dropdown and font/texture picker menus, including Options and the Bags character picker | `Core/Widgets/Dropdown.lua`; media pickers share the same menu |
| Widget tooltips and popup/confirmation dialogs | `Core/Widgets/Tooltip.lua`, `Dialog.lua` |
| GameTooltip, shopping and item-reference tooltip families, and their preview | `KstyleUI_Tooltips/Style.lua`, `Preview.lua` |
| Copy-chat dialog and minimap addon drawer | `KstyleUI_Chat/Copy.lua`, `KstyleUI_Minimap/Drawer.lua` |
| Floating meter detail panel | `KstyleUI_Meters/BarList.lua` |
| StaticPopup1–4, game menu and ready-check dialog | `KstyleUI_Skins/PartC/Popups.lua`, `PartB/GameMenu.lua`, `PartC/ReadyCheck.lua` |
| Friends broadcast/unavailable dialogs, raid-info window and ignore-list popup | `KstyleUI_Skins/PartC/Friends.lua` |
| Minimized profession search-results popup | `KstyleUI_Skins/PartB/Professions.lua` |
| RestedXP dressed menus/dialogs, step tooltips and importer confirmations | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` |

## Deliberately unchanged

- **Embedded surface tiles** keep their original glass rather than acquiring a popup material: DataBars micro/bag backings and bar plates; GroupFrames party/raid tiles; Cooldowns bars/chips/reskins; the Setup preview tile; and the in-window rows, tracks and panes in Skins Parts, Tracker, PartB Kit/Merchant/Professions, PartC Kit/Friends/Loot, WorldMap and RestedXP. They are content within a surface, not floating lists covering unrelated controls.
- **Button/socket controls** keep `buttonFill`: dropdown buttons, dialog buttons and edit boxes, tooltip icon/compare-header tiles, drawer buttons and item borders. Their opaque popup parent now prevents underlying UI from showing through the whole control stack. Status-bar chrome and tooltip health bars retain their bar treatment.
- **Custom silhouettes and explicit opt-outs** retain their existing surface: nameplate level badges and UnitFrames portrait/badge chrome. This preserves their geometry and the separate non-card study's scope.
- **Ordinary windows and HUD cards** still follow the chosen material and their configured opacity. They are not forced opaque by this change: Options, Bags, the chat/loot backings, normal Blizzard windows and persistent RestedXP guide/report/configurator/importer panels. Only the transient popup surfaces listed above opt in.
- **Native client menus and the colour picker** were excluded from LEE-118. The separate LEE-119 [native context-menu skin](native-context-menus.md) now covers KstyleUI's tracking, addon-compartment and quest-row descriptions outside combat, with its own switch. Glass, secure unit menus, other native dropdown lists and ColorPickerFrame retain client-owned art.
- **The secure spell flyout** has no shared panel surface; it remains separate socket icon buttons. Adding a backing or ornaments is not part of this opacity fix.

## Checks

The regression tests open the actual shared menu, test every material at several opacity values, switch profiles and materials, and preserve the embedded-tile invariant. Render comparisons include an open Card material menu over the Panel opacity control and the affected popup galleries. Native popup ordering, fades and combat behavior still need the owner's in-game check after staging is updated.
