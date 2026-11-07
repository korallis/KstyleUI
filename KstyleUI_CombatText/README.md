# KstyleUI_CombatText

Animated damage and heal numbers on KstyleUI frames and plates, and the KstyleUI font for the game's own world numbers.

| Field | Value |
| --- | --- |
| Module name | `CombatText`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_CombatText.toc` lists `CombatText.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- World numbers: set `DAMAGE_TEXT_FONT` to the KstyleUI font while the module is on. The change takes effect at the next login, not after a reload, and the options say so.
- Frame numbers come from `UNIT_COMBAT`. Amounts pass straight to `FontString:SetText` through `AbbreviateNumbers`, so Lua never compares or adds them. A unit type whose events do not fire gets no frame numbers.
- No `COMBAT_LOG_EVENT_UNFILTERED` and no `CombatLogGetCurrentEventInfo`: the combat log is closed to addons.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `CombatText.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`CombatText.xml` loads them in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Settings.lua` | The defaults, the settings page rows and `Settings.Snapshot(values, cfg)`, which checks every saved value and writes the plain copy the combat path reads |
| `Format.lua` | `Classify(event, flag, amount)`, which sorts an event into damage, a heal, a word or nothing, plus each number's text, colour and size |
| `Pool.lua` | `Pool.New(parent, capacity)`: numbers to reuse, each a 1-unit frame with a font string and one AnimationGroup |
| `Display.lua` | Emitters, one per place that shows numbers, and `Spawn`, which styles, places and animates one number |
| `World.lua` | `DAMAGE_TEXT_FONT` for the game's own damage numbers |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | Registration, `Enable` and `Disable`, the `UNIT_COMBAT` handler and the `/kstyle test` check |

Tests: `Tools/regression/test-combattext-numbers.lua` (events to numbers, secrets, throttling, pooling, styles, motion levels), `test-combattext-world.lua` (the world font) and `test-combattext-options.lua` (the settings page, saved-value checks, the preview and the smoke check). `Tools/regression/combattext_env.lua` loads the core and the module as the game does.

## Where numbers show

| Place | Element | What shows there |
| --- | --- | --- |
| Your field | `combattext.player`, a Layout element (160 by 180 units, above your character, resizable) | The damage and healing you take. Numbers start at the field's bottom edge and travel up through it, so the field's height sets how far they travel and its width how far apart they spread. |

## Settings

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `worldFont` | `true` | toggle | Sets `DAMAGE_TEXT_FONT` to `worldFace`. The game reads it at the next login. |
| `worldFace` | Source Sans 3 Semibold | font | The font for the game's own damage numbers |
| `style` | `rise` | dropdown: rise, arc, pop | How each number moves |
| `damage`, `heals`, `misses` | `true` | toggles | Which events show. A secret event shows its amount in the miss colour while damage or heals are on. |
| `format` | `short` | dropdown | `AbbreviateNumbers` (12.3K) or `BreakUpLargeNumbers` (12,345) |
| `duration` | 1.2 | slider, 0.6 to 3 s | How long a number stays |
| `maxPerFrame` | 4 | slider, 1 to 8 | The most numbers one place shows at once |
| `font`, `size`, `outline` | Source Sans 3 Semibold, 18, thin outline | font, slider 8 to 40, dropdown | The numbers' text. No outline gives the soft text shadow. |
| `colorMode` | `school` | dropdown | Damage takes its spell school's token colour, or `damageColor` |
| `damageColor`, `healColor`, `missColor` | `hostile`, `friendly`, `text` | colours | |
| `critScale` | 1.4 | slider, 1 to 2 | How much larger critical hits and heals are. Above 1 they also pop in. |
| `critColor`, `critTint` | `true`, `neutral` | toggle, colour | Critical damage takes its own colour. Critical heals keep the heal colour. |

## Why

- **Amounts stay secret.** `UNIT_COMBAT`'s amount is secret under restrictions. It goes from the event straight into `AbbreviateNumbers` or `BreakUpLargeNumbers`, both of which accept secrets, and the result goes straight to `SetText`, or to `SetFormattedText("+%s", ...)` for heals. Lua never compares, adds or tests it. A formatter that fails falls back to `SetText(amount)`, which the engine formats.
- **Zero without comparing.** Blizzard's own feedback shows a word instead of 0 when a hit is fully absorbed, blocked or resisted. Code can test `amount == 0` only when `issecretvalue` says the amount is plain. When it is secret, a hit flagged `ABSORB`, `BLOCK` or `RESIST` shows the word, because a full avoid is the case where a number would read 0. A partial absorb then shows the word too, which is the safer error.
- **The school is guarded too.** The API docs mark only the amount secret. The event, flag, school and unit are still checked with `issecretvalue` before any comparison: a secret school takes the damage colour, a secret flag gives no emphasis, a secret event shows the amount in the miss colour, and a secret unit shows nothing. `/kstyle test` counts each kind of secret it met, so the first in-game session answers the spike's question.
- **The world font is set at load.** The game reads `DAMAGE_TEXT_FONT` once, when the world loads at login, and caches it, so a reload does not change it. The module sets the global while its files load, before `PLAYER_LOGIN`, but only when its switch is on in the saved profile, and `Enable` sets it again. This is the one thing the module does before `Enable`: it creates no frames and registers no events. `Disable` and switching the option off put back the font the game had, also from the next login. No Blizzard code reads the global from Lua, so setting it taints nothing. It is listed on the module's line in `.luacheckrc`.
- **Engine animation.** Each number moves with an AnimationGroup on its own frame: a translation, a second translation for the arc's fall, a scale for the pop and an alpha fade. The engine runs them, so a number costs no `OnUpdate` and no Lua per frame. All four animations sit in one order and run together; the fall and the fade wait with a start delay. Translation offsets are divided by the number's scale, because they apply in the frame's own units.
- **Motion levels.** At `reduced` numbers fade without moving or popping. At `off` a number shows for its duration, then goes.
- **Pooling and throttling.** The field's numbers come from a pool of 16 whose frames are the field's children, so Layout's shown rules and opacity for the field apply to its numbers too. The settings preview has its own pool of 8. Each place shows at most `maxPerFrame` numbers, and the oldest makes way for the newest; when a whole pool is on screen, its oldest number makes way. Lanes (centre, left, right) keep three numbers in quick succession apart. The combat path allocates no tables and makes no frames after the pool warms up; `test-combattext-numbers.lua` checks the frame count over 200 events.
- **Fonts on the number's own font string.** Numbers use their own font, size and outline, so they set them with `SetFont` instead of a `Widgets.Text` role, which would put the role's font back on every theme change. A font the game cannot load falls back to the `number` font and logs once.
- **Words come from the game.** `MISS`, `DODGE`, `PARRY` and the rest are the game's localised strings, with English fallbacks through `KstyleUI.L`.
- **No combat log.** The combat log is closed to addons on Forever, so incoming numbers come only from `UNIT_COMBAT`.
