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
| `defaults`, `rows` | Optional. `rows` follow the `Options.Register` rules with keys relative to the skin; a bad row stops the module from loading with the row's key in the error. A row's `showWhen` and `disableWhen` get the skin's own settings table. Every row hides while the window's switch is off. Do not put `enabled` in `defaults`: the registry adds the switch. |

The registry adds the window's switch, `<key>.enabled`, default on, to the module's settings page, under the Windows header in the order `Skins.xml` loads the files.

### When a skin applies

1. `Enable` arms every skin whose switch is on.
2. A skin whose `addon` has not loaded waits for that addon's `ADDON_LOADED`. `C_AddOns.IsAddOnLoaded` answers the check; on a client without it, a window whose `frame` already exists counts as loaded.
3. Once the addon has loaded, the skin hooks the window's `OnShow` and applies on its first show, or at once if the window is open.
4. In combat the skin waits for `KstyleUI.Combat.Queue`.
5. Each step logs to the devlog: `<key>: waits for <addon> to load`, `<key>: applied`, `<key>: Apply failed`, or `<key>: <frame> is missing on this client`.

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
| `Style.Text(fontString, role, colorName)` | The role's font (`Tokens.Font`) with the chosen face, size and edge, and a token colour. A face the game cannot load falls back to the KstyleUI face and logs once. |
| `Style.StatusBar(bar)` | The bar texture, fill direction and colour on a status bar. It hooks the bar's `SetStatusBarColor`, so a colour Blizzard sets later is restyled too. A secret colour passes through untouched. |
| `Style.BarColor(r, g, b)`, `Style.BarTexture()`, `Style.ReverseFill()` | The pieces, for bars that are not status bars. |
| `Style.Accent() -> r, g, b`, `Style.TintAccent(region, alpha)` | The module's accent. |
| `Style.Track(object)` | `object:Restyle()` runs when a look setting, the theme or the profile changes. |
| `Style.Setting(group, key)` | A checked value, or the default. |

`Parts.Rim(frame, opts)` puts a raised chamfered tile behind a frame on a KstyleUI child frame, `opts.outset` units outside it, with `rim:SetRimColor(r, g, b, a)` drawing a 2-unit chamfered ring in that colour (or none for `nil`). `Parts.AccentLine(owner, opts)` draws a 2-unit accent divider along the owner's `BOTTOM` or `TOP` edge.

While the module runs, a change to any look setting restyles every text and bar the skins styled. The settings window's preview shows the settings whether or not the module runs.

## Why

- **One module, one switch per window.** Players turn the module on once and then pick windows. Each window's switch lives in the module's own settings section, so a profile string carries every choice, and the registry adds the switches so a skin file cannot forget its own.
- **Skins wait for their window.** A skin applies on the window's first show, after its Blizzard addon has loaded. A player who never opens the talent window never loads `Blizzard_PlayerSpells` for KstyleUI, and never pays for its skin.
- **Applied once, kept until reload.** Restyling Blizzard frames in place cannot be undone cleanly, so a skin runs once per session, and turning a window or the module off asks for a reload instead of half-restoring Blizzard's art.
- **Combat waits.** Some windows hold protected children. A skin that would run in combat waits for `Combat.Queue`, so it never touches a protected frame in lockdown.
- **No Layout keys.** Every frame this module makes is chrome parented to a Blizzard window. Layout never moves Blizzard frames, and registering the chrome would pull it off its window, so the module registers no Layout elements. Blizzard's panel manager and Edit Mode keep placing the windows.
- **One look for every window.** Text, bars and accents go through `ns.Style`, so the font, size, edge, bar and accent settings change every skinned window at once, and part B and C skins get them for free.
- **Parallel parts never collide.** Each part adds its files between its own comment lines in `Skins.xml`, and `Module.lua` loads last to read every skin, so three branches can add skins at the same time and merge cleanly.
