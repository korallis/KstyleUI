# KstyleUI_Icons

Icon set A: white light art on black for every ability, tinted in game by class colour, spell school colour or white.

| Field | Value |
| --- | --- |
| Module name | `Icons`: its switch in `Core/Features.lua` |
| Approach | Data addon |
| Loads | On demand: when the player turns on custom icons |
| Files | `KstyleUI_Icons.toc` lists `Icons.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- The addon holds data only: a table from icon file ID to texture path that `KstyleUI.Icons` reads. It creates no frames and registers no events.
- Icons are 128x128 PNG and keep luminance only.
- Every icon has a row in `Media/PROVENANCE.md`: model, prompt, seed if available, date and the file ID it replaces.
- Strings go through `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Icons.xml`.

## Why

- The `Icons` switch belongs to the core's `Icons` service, which registers the `Icons` module at load, because this addon holds data only and may not be loaded. Loading the data on demand keeps about 900 texture paths out of memory for players who keep Blizzard's icons.
- Both icon addons set the same global, `KstyleUIIconData`. `.luacheckrc` lets only one folder claim a global name, so each data file writes it as `_G.KstyleUIIconData`, which luacheck allows, and neither folder lists it.
- Set A is white light art, so one image serves every tint. The additive copy brings back the bright highlights that `SetVertexColor` darkens, because a vertex colour only multiplies.

## Core/Icons.lua

The core's `Icons` service reads this addon's data. Tests: `Tools/regression/test-icons.lua`.

### Data format

Each icon data addon defines one global table when it loads. A Lua file listed by `Icons.xml` sets it:

```lua
_G.KstyleUIIconData = {
	set = "A",
	icons = {
		[135812] = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\135812.png",
	},
	schools = {
		[135812] = 4,
	},
}
```

| Field | Type | Rule |
| --- | --- | --- |
| `set` | `"A"` or `"B"` | `"A"` in `KstyleUI_Icons`, `"B"` in `KstyleUI_IconsColour`. The service ignores a table whose `set` is not the set it loaded. |
| `icons` | `{ [fileID] = path }` | Required. The key is the game's icon file ID, a number. The value is the path to the 128x128 PNG, `Interface\AddOns\<addon>\Icons\<fileID>.png`. An entry that is not a string is ignored. |
| `schools` | `{ [fileID] = schoolMask }` | Optional. The spell school bit mask of the abilities that use the icon: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane. `Apply` uses it when the caller passes no school. |

`Tools/icons/` writes the file from `Tools/data/abilities.json`. The file holds data only: no frames, no events and no other globals.

### Settings

The `Icons` settings page, registered with `Options.Register("Icons", schema)`:

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `enabled` | `false` | toggle | The `Icons` module switch: custom icons on or off |
| `set` | `"A"` | dropdown: light art, tinted (A) or full colour (B) | Which data addon loads |
| `tint` | `"class"` | dropdown, set A only: class colour, spell school colour or white | The colour that tints set A. Class colour is `Theme.Accent()`, so it follows a custom accent too. |
| `highlight` | `0.25` | slider from 0 to 0.6 in steps of 0.05, set A only | The alpha of the additive copy. 0 hides it. |

The `IconsColour` switch in `Features.modules` exists because every module folder has one. The service never reads it: the `set` setting picks set B.

### Behaviour

- The service is the `Icons` module. Its `Enable` runs at `PLAYER_LOGIN`, before any module addon's, when the switch is on. It loads the active set's addon with `C_AddOns.LoadAddOn`, reads `KstyleUIIconData`, keeps the table, and fires `IconsChanged`. Switching sets loads the other addon once; a set's table is kept, so switching back loads nothing.
- When `C_AddOns.LoadAddOn` is missing, the load fails, or the addon defines no table for the set, Blizzard's icons stay and the devlog says why. `/kstyle test` logs `icons` as `PASS` with the set and its size, or `FAIL` with the reason.
- `IconsChanged` fires when the module starts or stops, and when the set, tint or highlight setting changes. A module re-applies its icons in its `IconsChanged` handler.
- A tint or highlight change, and a `ThemeChanged` unless the tint is white, repaint every set A icon at once. A school tint falls back to the class colour for an icon with no school, so it follows the accent too. Each `Apply` copies the icon's texture coordinates to the highlight copy again.
- A secret file ID is never compared or used as a key: it reaches `SetTexture` untouched and keeps the game's icon.

| Function | Behaviour |
| --- | --- |
| `Resolve(fileID) -> path` or `nil` | The active set's texture for a file ID. `nil` while the module is off, when the set did not load, for a file ID the set lacks, and for a secret or anything that is not a number. |
| `Apply(texture, fileID, school) -> custom` | Sets `texture` to the custom icon, or to `fileID` when there is none, and returns whether it is custom. Set A is tinted with `SetVertexColor`: the class colour, the colour of `school` (else the data's school, else the class colour), or white. An additive copy of the art, white at the `highlight` alpha, sits one sublevel above the icon on the same parent, shares its masks and texture coordinates, and shows and hides with it. Set B and Blizzard's icons are not tinted. |
| `Shade(texture, r, g, b, desaturated)` | Multiplies the tint by `r, g, b` and sets the desaturation, for widgets that dim or grey an icon. `IconButton` calls it on every paint instead of `SetVertexColor`, so hover, press and the unusable state keep the tint. On a texture `Apply` never saw, it is `SetVertexColor(r, g, b)` and `SetDesaturated(desaturated)`. A `nil` `desaturated` leaves the desaturation alone. |
| `Reset(texture)` | Forgets the custom icon: the tint goes and the copy hides. `IconButton:SetIcon` calls it. Call `Apply` or `Reset` whenever you change an icon that `Apply` set. |
| `SchoolColor(mask) -> r, g, b` or `nil` | The token colour of a school mask. A mixed mask takes its first magic school in the order holy, fire, nature, frost, shadow, arcane; physical counts only alone. |
| `ActiveSet() -> "A"`, `"B"` or `nil` | The loaded set while the module runs. |
| `defaults`, `schema` | The tables registered with `Modules` and `Options`. |

Per-texture state lives in a weak-keyed table. The copy is made on the texture's parent and the service hooks the texture's `Show`, `Hide` and `SetShown` with `hooksecurefunc`, so use `Apply` on KstyleUI's own textures. The school colours are the `school*` tokens in `Core/Tokens.lua`.
