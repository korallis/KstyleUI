# KstyleUI_CombatText

Animated damage and heal numbers on KstyleUI frames and plates, the KstyleUI font for the game's own world numbers, and Blizzard's own combat text hidden while the module runs.

| Field | Value |
| --- | --- |
| Module name | `CombatText`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Mirror |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_CombatText.toc` lists `CombatText.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- World numbers: set `DAMAGE_TEXT_FONT` to the KstyleUI font while the module is on. The change takes effect at the next login, not after a reload, and the options say so.
- Blizzard's combat text: while the module runs, turn the game's own combat text off through its CVars, out of combat, and put the player's values back when it stops. See [Blizzard's combat text](#blizzards-combat-text).
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
| `Display.lua` | Emitters, one per place that shows numbers, each with its pool, and `Spawn`, which styles, places and animates one number |
| `Anchors.lua` | Which places show numbers for a unit token: KstyleUI unit and group frames found by their `unit` attribute, your field, and nameplates |
| `World.lua` | `DAMAGE_TEXT_FONT` for the game's own damage numbers |
| `Blizzard.lua` | The CVars that hide Blizzard's own combat text while the module runs |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | Registration, `Enable` and `Disable`, the event handlers and the `/kstyle test` check |

Tests: `Tools/regression/test-combattext-numbers.lua` (events to numbers, secrets, throttling, pooling, styles, motion levels), `test-combattext-anchors.lua` (unit, group, boss and nameplate frames, rescans, scale and opacity, against stand-ins), `test-combattext-integration.lua` (the same against the real UnitFrames, GroupFrames and Nameplates modules, loaded in the game's order), `test-combattext-world.lua` (the world font), `test-combattext-blizzard.lua` (Blizzard's combat text) and `test-combattext-options.lua` (the settings page, saved-value checks, the preview and the smoke check). `Tools/regression/combattext_env.lua` loads the core and the module as the game does.

## Where numbers show

| Place | Element | What shows there |
| --- | --- | --- |
| Your field | `combattext.player`, a Layout element (160 by 180 units, above your character, resizable) | The damage and healing you take, while `playerPlacement` is `field`, or while it is `frame` and no KstyleUI player frame is running. Numbers start at the field's bottom edge and travel up through it, so the field's height sets how far they travel and its width how far apart they spread. |
| Unit frames | The secure buttons inside the `unitframes.player`, `.target`, `.targettarget`, `.focus`, `.focustarget`, `.pet` and `.boss` elements | Each unit's numbers on its own frame. Boss frames match `boss1` to `boss5` by their `unit` attribute. |
| Group frames | The secure buttons inside the `groupframes.party` and `groupframes.raid` elements | Each member's numbers on their frame, at `groupSize` and 60% of the travel distance |
| Nameplates | Blizzard's base plate from `C_NamePlate.GetNamePlateForUnit`, under KstyleUI's plate | Numbers for `nameplate1` to `nameplate40`, while KstyleUI's Nameplates module runs |

Numbers on frames start at the frame's centre or just above it (`framePoint`) and travel `distance` units. They live in the module's own layer on `KstyleUI_Root` and are only anchored to the frame, so KstyleUI never parents anything to a secure or Blizzard frame.

## Blizzard's combat text

The game draws its own combat text, so without this the player sees two sets of numbers. `Blizzard.lua` writes `0` into these CVars while the module runs:

| Setting | CVars | What the game draws | Saved by the game |
| --- | --- | --- | --- |
| `blizzardSelf` | `enableFloatingCombatText` | The scrolling text over your character (`Blizzard_CombatText`): damage and heals you take, misses, and also reputation, honour and combat state | Per character |
| `blizzardTargets` | `floatingCombatTextCombatDamage_v2`, `floatingCombatTextCombatHealing_v2`, `floatingCombatTextPetMeleeDamage_v2`, `floatingCombatTextPetSpellDamage_v2` | Your damage and healing numbers over targets, and your pet's damage | For every character |

Periodic damage (`floatingCombatTextCombatLogPeriodicSpells_v2`) is a filter under Damage in Blizzard's menu, so it is not touched. Pet damage has its own two CVars, which Forever's Settings panel does not show, and KstyleUI's numbers on frames and plates include the pet's hits.

| Case | What happens |
| --- | --- |
| The module turns on, or a setting changes to Hide | Each CVar is written `0` out of combat (`Combat.Queue`) and read back. A CVar already at `0` is not written. |
| Turned off, or a setting changes to Keep | The player's value comes back, but only to a CVar that still holds `0`. If the game refuses it, the module keeps the value and tries again at the next restore. |
| The player's value | `KstyleUIDB.account.combatTextCVars[<owner>][<cvar>]` keeps `{ original, written }`. The owner is the character key for a CVar the game saves per character, and `*` for one it saves for every character, so an alt never takes KstyleUI's `0` as its own. `C_CVar.GetCVarInfo` says which; the table above is the fallback. A value that differs from `written` when the module starts is the player's own. |
| A change in Blizzard's options (`SettingsPanel` shown) | A CVar turned back on sets its setting to Keep, which puts back every CVar under that setting. |
| Any other change (`/console`, another addon), or `VARIABLES_LOADED` after the module started | The new value becomes the player's, and the module writes `0` again on the next frame. |
| The client refuses a CVar (a secure CVar returns nothing) or has no `C_CVar.SetCVar` | The player's value stays, and the devlog says so once. |

The module's own writes set a flag around `SetCVar`, because `CVAR_UPDATE` fires inside the call. `SettingsPanel` passes every `CVAR_UPDATE` to its settings, so `Blizzard_CombatText` stops at once. Before removing KstyleUI, set both settings to Keep or turn the module off, or the text stays hidden.

Limit: values come back only when the module stops or a setting changes to Keep, because a module that is off at login runs no code. A character that logs in with the module off keeps what another character left: the target CVars while another profile hides them, and its own `enableFloatingCombatText` if the module was turned off on a different character. Esc > Options > Combat turns them back on, except the two pet CVars, which need `/console`.

## Settings

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `blizzardSelf` | `hide` | dropdown: hide, keep | Hide turns `enableFloatingCombatText` off. Keep leaves it as the player set it. |
| `blizzardTargets` | `keep` | dropdown: hide, keep | Keep leaves the four CVars for numbers over targets as the player set them: these are the only numbers that show just the player's own hits, drawn in KstyleUI's font while `worldFont` is on. Hide turns them off. |
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
| `units.player`, `.target`, `.targettarget`, `.focus`, `.focustarget`, `.pet`, `.boss`, `.party`, `.raid`, `.nameplate` | on, except `targettarget`, `focustarget`, `raid` and `nameplate` | toggles | Which places show numbers |
| `playerPlacement` | `field` | dropdown: field, frame | Where your own numbers show |
| `framePoint` | `CENTER` | dropdown: centre, above | Where numbers on frames start |
| `distance` | 40 | slider, 8 to 120 | How far numbers on frames travel |
| `groupSize` | 14 | slider, 8 to 40 | The text size on party and raid frames |

## Why

- **Amounts stay secret.** `UNIT_COMBAT`'s amount is secret under restrictions. It goes from the event straight into `AbbreviateNumbers` or `BreakUpLargeNumbers`, both of which accept secrets, and the result goes straight to `SetText`, or to `SetFormattedText("+%s", ...)` for heals. Lua never compares, adds or tests it. A formatter that fails falls back to `SetText(amount)`, which the engine formats.
- **Zero without comparing.** Blizzard's own feedback shows a word instead of 0 when a hit is fully absorbed, blocked or resisted. Code can test `amount == 0` only when `issecretvalue` says the amount is plain. When it is secret, a hit flagged `ABSORB`, `BLOCK` or `RESIST` shows the word, because a full avoid is the case where a number would read 0. A partial absorb then shows the word too, which is the safer error.
- **The school is guarded too.** The API docs mark only the amount secret. The event, flag, school and unit are still checked with `issecretvalue` before any comparison: a secret school takes the damage colour, a secret flag gives no emphasis, a secret event shows the amount in the miss colour, and a secret unit shows nothing. `/kstyle test` counts each kind of secret it met, so the first in-game session answers the spike's question.
- **The world font is set at load.** The game reads `DAMAGE_TEXT_FONT` once, when the world loads at login, and caches it, so a reload does not change it. The module sets the global while its files load, before `PLAYER_LOGIN`, but only when its switch is on in the saved profile, and `Enable` sets it again. This is the one thing the module does before `Enable`: it creates no frames and registers no events. `Disable` and switching the option off put back the font the game had, also from the next login. No Blizzard code reads the global from Lua, so setting it taints nothing. It is listed on the module's line in `.luacheckrc`.
- **Engine animation.** Each number moves with an AnimationGroup on its own frame: a translation, a second translation for the arc's fall, a scale for the pop and an alpha fade. The engine runs them, so a number costs no `OnUpdate` and no Lua per frame. All four animations sit in one order and run together; the fall and the fade wait with a start delay. Translation offsets are divided by the number's scale, because they apply in the frame's own units.
- **Motion levels.** At `reduced` numbers fade without moving or popping. At `off` a number shows for its duration, then goes.
- **Pooling and throttling.** The field's numbers come from a pool of 16 and frame numbers from a pool of 64 (see Two pools). The settings preview has its own pool of 12. Each place shows at most `maxPerFrame` numbers, and the oldest makes way for the newest; when a whole pool is on screen, its oldest number makes way. Lanes (centre, left, right) keep three numbers in quick succession apart. The per-event path allocates no tables and makes no frames once the pools warm up; a rescan allocates a list only the first time it meets a unit token; `test-combattext-numbers.lua` and `test-combattext-anchors.lua` check the frame count over 200 events.
- **Fonts on the number's own font string.** Numbers use their own font, size and outline, so they set them with `SetFont` instead of a `Widgets.Text` role, which would put the role's font back on every theme change. A font the game cannot load falls back to the `number` font and logs once.
- **Frames are found, not shared.** Modules never read each other, so CombatText finds the other modules' frames through Layout: for each element key it asks `Layout.Live` whether the owning module runs, then walks the element's frame up to four levels deep, at most 400 frames, for secure buttons with a `unit` attribute. Reading an attribute is allowed in combat. A unit frame with no attribute gets numbers on the element itself. The map from unit token to frames is rebuilt on `Enable`, after a setting or profile change, on `ModuleChanged` for UnitFrames, GroupFrames and Nameplates, and a frame after `GROUP_ROSTER_UPDATE`, when the group headers have moved their buttons. The combat path only looks the token up.
- **Rosters that move.** A group button whose `unit` attribute no longer matches the token gets no number and asks for a rescan on the next frame, even when the button is hidden. A hit on a party, raid or boss token with no frame, while that kind is switched on and its element is live, asks for a rescan at most every 2 seconds, which finds buttons a header made late. A hidden frame gets no number; a secret `IsVisible` counts as shown.
- **Scale follows the frame.** Numbers on unit and group frames take the frame's effective scale against the layer's, so a frame enlarged in Layout Mode gets larger numbers that travel further. Plate numbers keep their own size, because a plate's scale changes with distance.
- **Opacity follows the frame.** A number on a frame takes the frame's `GetEffectiveAlpha` on its font string, so Layout's opacity and mouseover rules and a group frame's range fade apply to it. The value can be secret after `SetAlphaFromBoolean`; it goes straight to `SetAlpha`, which accepts secrets. The font string's alpha multiplies with the frame's fade animation, so the fade still runs.
- **Whose hits.** `UNIT_COMBAT` reports every hit a unit takes, from any player, and the combat log is closed to addons, so KstyleUI cannot tell your hits from other players'. On an enemy that means everyone's damage. That is why `units.nameplate` is off and `blizzardTargets` is `keep` by default: the game's own numbers over targets show only your hits. Players who change either default keep their choice.
- **Plates.** Nameplate numbers need KstyleUI's Nameplates module: the spec puts numbers on KstyleUI's plates, and the game already draws its own numbers over units. `NAME_PLATE_UNIT_REMOVED` clears a plate's numbers, so they never follow the plate to its next unit. `/kstyle test` counts `UNIT_COMBAT` events from nameplate units, which answers whether Forever fires them.
- **Two pools.** Your field's numbers are the field's children, so its Layout shown rule and opacity apply. Numbers on frames come from a second pool of 64 in the module's layer.
- **Words come from the game.** `MISS`, `DODGE`, `PARRY` and the rest are the game's localised strings, with English fallbacks through `KstyleUI.L`.
- **No combat log.** The combat log is closed to addons on Forever, so incoming numbers come only from `UNIT_COMBAT`.
