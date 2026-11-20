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

- World numbers: set `DAMAGE_TEXT_FONT` to the `world` combat-text role in the module's main chunk, before `PLAYER_LOGIN`, while the module is on. Changing or restoring it needs a full logout to the character screen and login, not `/reload`, and the options say so.
- Blizzard's combat text: while the module runs, turn the game's own combat text off through its CVars, out of combat, and put the player's values back when it stops. When it is off at login, the core puts them back. See [Blizzard's combat text](#blizzards-combat-text).
- Frame numbers come from `UNIT_COMBAT`. Amounts pass straight to `FontString:SetText` through `AbbreviateNumbers`, so Lua never compares or adds them. A unit type whose events do not fire gets no frame numbers.
- No `COMBAT_LOG_EVENT_UNFILTERED` and no `CombatLogGetCurrentEventInfo`: the combat log is closed to addons.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
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

Tests: `Tools/regression/test-combattext-numbers.lua` (events to numbers, secrets, throttling, pooling, styles, motion levels), `test-combattext-anchors.lua` (unit, group, boss and nameplate frames, rescans, scale and opacity, against stand-ins), `test-combattext-integration.lua` (the same against the real UnitFrames, GroupFrames and Nameplates modules, loaded in the game's order), `test-combattext-world.lua` (the world font), `test-combattext-blizzard.lua` (Blizzard's combat text, including the core's restore at login), `test-combattext-ownership.lua` (default ownership, explicit Keep, combat-deferred disable and the world role before login) and `test-combattext-options.lua` (the settings page, saved-value checks, the preview and the smoke check). `Tools/regression/combattext_env.lua` loads the core and the module as the game does.

## Where numbers show

| Place | Element | What shows there |
| --- | --- | --- |
| Your field | `combattext.player`, a Layout element (160 units wide, above your character, resizable; 149 tall by default since the Frames tray lifted the centre stack) | The damage and healing you take, while `playerPlacement` is `field`, or while it is `frame` and no KstyleUI player frame is running. Numbers start at the field's bottom edge and rise at most 48 units (KSTY-44's short rise), or less when the field is too short for that; its width sets how far apart they spread. |
| Unit frames | The secure buttons inside the `unitframes.player`, `.target`, `.targettarget`, `.focus`, `.focustarget`, `.pet` and `.boss` elements | Each unit's numbers on its own frame. Boss frames match `boss1` to `boss5` by their `unit` attribute. |
| Group frames | The secure buttons inside the `groupframes.party` and `groupframes.raid` elements | Each member's numbers on their frame, at `groupSize` and 60% of the travel distance |
| Nameplates | Blizzard's base plate from `C_NamePlate.GetNamePlateForUnit`, under KstyleUI's plate | Numbers for `nameplate1` to `nameplate40`, while KstyleUI's Nameplates module runs |

Numbers on frames start at the frame's centre or just above it (`framePoint`) and travel `distance` units. They live in the module's own layer on `KstyleUI_Root` and are only anchored to the frame, so KstyleUI never parents anything to a secure or Blizzard frame.

Under Medallions the player's default field starts 12 units above the cast stack, centred above it. Its 80-unit height clears the pet stack and keeps the full 40-unit rise. Target-frame numbers stay above a 60-unit clear area for target debuffs, including their critical size, pop and the arc's downward travel. This leaves amounts secret and uses only the public unit token to select the lane. Saved field moves still apply. `test-combattext-safe-lane.lua` checks the clearance; `combat_readability_hud` renders the real unit frames, auras and scrolling numbers together.

## Blizzard's combat text

The game draws its own combat text, so without this the player sees two sets of numbers. Both settings default to Hide while the module runs. A saved explicit Keep remains Keep; changing the default does not overwrite it. `Blizzard.lua` writes `0` into these CVars while the corresponding setting is Hide:

| Setting | CVars | What the game draws | Saved by the game |
| --- | --- | --- | --- |
| `blizzardSelf` | `enableFloatingCombatText` | The scrolling text over your character (`Blizzard_CombatText`): damage and heals you take, misses, and also reputation, honour and combat state | Per character |
| `blizzardTargets` | `floatingCombatTextCombatDamage_v2`, `floatingCombatTextCombatHealing_v2`, `floatingCombatTextPetMeleeDamage_v2`, `floatingCombatTextPetSpellDamage_v2` | Your damage and healing numbers over targets, and your pet's damage | For every character |

This suppresses Blizzard's separate world-number display; it does not make KstyleUI's frame numbers a player-only outgoing feed. `UNIT_COMBAT` has no attacker in its payload, so an enemy frame can show damage from other players too. Nameplate numbers remain off by default. Choose Keep for Blizzard's numbers over targets if you want its player-owned outgoing display, with the `world` font after a full relog when `worldFont` is on. With Hide selected those native world numbers are not visible, whatever their font.

Periodic damage (`floatingCombatTextCombatLogPeriodicSpells_v2`) is a filter under Damage in Blizzard's menu, so it is not touched. The legacy pet-damage toggles listed above are also probed and, when supported, follow `blizzardTargets`. Frame and plate events do not identify an attacker, whether player or pet.

Source evidence for build 70862: `Blizzard_SettingsDefinitions_Frame/Mainline/CombatOverrides.lua` declares the self, world damage and world healing controls; `Blizzard_APIDocumentationGenerated/CVarDocumentation.lua` defines the guarded get/info/set APIs. The existing pet CVar names above do not occur in that source tree. Their optional handling is unchanged and remains gated by the runtime CVar probe; this is not proof that the native renderer implements them.

| Case | What happens |
| --- | --- |
| The module turns on, or a setting changes to Hide | Each CVar is written `0` out of combat (`Combat.Queue`) and read back. A CVar already at `0` is not written. |
| Turned off, or a setting changes to Keep | The player's value comes back, but only to a CVar that still holds `0`. If the game refuses it, the module keeps the value and tries again at the next restore. |
| Off at login on this character | The core's [`CVars` service](../docs/core-services.md#cvars) puts the player's values back, with the same rules: only to a CVar that still holds `0`, out of combat, and a refused value is kept for the next login. It covers the numbers over targets that another character's profile hid, and this character's own `enableFloatingCombatText` after the module was turned off while playing another character. |
| The player's value | `KstyleUIDB.account.combatTextCVars[<owner>][<cvar>]` keeps `{ original, written }`. The owner is the character key for a CVar the game saves per character, and `*` for one it saves for every character, so an alt never takes KstyleUI's `0` as its own. `C_CVar.GetCVarInfo` says which; the table above is the fallback. A value that differs from `written` when the module starts is the player's own. |
| A change in Blizzard's options (`SettingsPanel` shown) | A CVar turned back on sets its setting to Keep, which puts back every CVar under that setting. |
| Any other change (`/console`, another addon), or `VARIABLES_LOADED` after the module started | The new value becomes the player's, and the module writes `0` again on the next frame. |
| The client refuses a CVar (a secure CVar returns nothing) or has no `C_CVar.SetCVar` | The player's value stays, and the devlog says so once. |

The module's own writes set a flag around `SetCVar`, because `CVAR_UPDATE` fires inside the call. `SettingsPanel` passes every `CVAR_UPDATE` to its settings, so `Blizzard_CombatText` stops at once. Before removing KstyleUI, set both settings to Keep or turn the module off, or the text stays hidden.

A module that is off at login runs no code, so the core restores its CVars at login, once the modules have started and the character's CVars have loaded. The numbers over targets are saved for every character: they come back on each character whose module is off, and the next character that runs the module hides them again at its own login.

Upgrade from v0.2.1: Store materializes the old Keep default while running, but removes default-valued fields from SavedVariables at logout. Setup does not write a separate target-text preference, so a normally saved profile with no `blizzardTargets` key adopts Hide on its next login. A raw saved `blizzardTargets = "keep"` is preserved; there is no provenance field that can distinguish a deliberately saved Keep from an externally materialized old default. Select Hide once for such a profile if native numbers are unwanted.

## Settings

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `blizzardSelf` | `hide` | dropdown: hide, keep | Hide turns `enableFloatingCombatText` off. Keep leaves it as the player set it. |
| `blizzardTargets` | `hide` | dropdown: hide, keep | Hide suppresses Blizzard's world damage and healing while our scrolling text runs. Explicit Keep leaves the values as the player set them, retaining Blizzard's player-owned outgoing display. |
| `worldFont` | `true` | toggle | Sets `DAMAGE_TEXT_FONT` to `worldFace` before login. A changed font needs logout to the character screen and login; `/reload` is not enough. |
| `worldFace` | Interface font: the `world` combat-text role (PT Serif Regular in Folio, Alegreya Sans Medium in Lumen) | font | The font for the game's own damage numbers, visible when their Blizzard setting is Keep |
| `style` | `rise` | dropdown: rise, arc, pop | How each number moves |
| `damage`, `heals`, `misses` | `true` | toggles | Which events show. A secret event shows its amount in the miss colour while damage or heals are on. |
| `format` | `short` | dropdown | `AbbreviateNumbers` (12.3K) or `BreakUpLargeNumbers` (12,345) |
| `duration` | 1.2 | slider, 0.6 to 3 s | How long a number stays |
| `maxPerFrame` | 4 | slider, 1 to 8 | The most numbers one place shows at once |
| `font`, `size`, `outline` | Interface font (the `number` role), 18, thin outline | font, slider 8 to 40, dropdown | The numbers' text. No outline gives the soft text shadow. |
| `colorMode` | `single` | dropdown | Damage takes `damageColor`, or its spell school's token colour |
| `damageColor`, `healColor`, `missColor` | `white`, `friendly`, `text` | colours | |
| `critScale` | 1.6 | slider, 1 to 2 | How much larger critical hits and heals are. Above 1 they also pop in. |
| `critColor`, `critTint` | `true`, `neutral` | toggle, colour | Critical damage takes its own colour. Critical heals keep the heal colour. |
| `units.player`, `.target`, `.targettarget`, `.focus`, `.focustarget`, `.pet`, `.boss`, `.party`, `.raid`, `.nameplate` | on, except `targettarget`, `focustarget`, `raid` and `nameplate` | toggles | Which places show numbers |
| `playerPlacement` | `field` | dropdown: field, frame | Where your own numbers show |
| `framePoint` | `CENTER` | dropdown: centre, above | Where numbers on frames start |
| `distance` | 40 | slider, 8 to 120 | How far numbers on frames travel |
| `groupSize` | 14 | slider, 8 to 40 | The text size on party and raid frames |

## Why

- **Three colours, two sizes (KSTY-44 row 8).** The design bible's damage numbers are white for a normal hit and gold for a critical one, and a critical hit is 1.6 times a normal one (section 3.10). So `colorMode` defaults to one colour, white, `critTint` stays the gold `neutral` token, `critScale` is 1.6, and a glancing blow keeps the normal size, so a number has two sizes. Heals stay `friendly` and words stay `text`. The bible's third colour, orange for periodic damage, cannot be drawn: `UNIT_COMBAT`'s flag is only `CRITICAL`, `CRUSHING`, `GLANCING`, `ABSORB`, `BLOCK`, `RESIST` or `BLOCK_REDUCED` (Blizzard's own `CombatFeedback_OnCombatEvent`, `Blizzard_FrameXML/Mainline/CombatFeedback.lua`), so a tick reads as a normal hit. The school colours stay a choice.

- **Amounts stay secret.** `UNIT_COMBAT`'s amount is secret under restrictions. It goes from the event straight into `AbbreviateNumbers` or `BreakUpLargeNumbers`, both of which accept secrets, and the result goes straight to `SetText`, or to `SetFormattedText("+%s", ...)` for heals. Lua never compares, adds or tests it. A formatter that fails falls back to `SetText(amount)`, which the engine formats.
- **Zero without comparing.** Blizzard's own feedback shows a word instead of 0 when a hit is fully absorbed, blocked or resisted. Code can test `amount == 0` only when `issecretvalue` says the amount is plain. When it is secret, a hit flagged `ABSORB`, `BLOCK` or `RESIST` shows the word, because a full avoid is the case where a number would read 0. A partial absorb then shows the word too, which is the safer error.
- **The school is guarded too.** The API docs mark only the amount secret. The event, flag, school and unit are still checked with `issecretvalue` before any comparison: a secret school takes the damage colour, a secret flag gives no emphasis, a secret event shows the amount in the miss colour, and a secret unit shows nothing. `/kstyle test` counts each kind of secret it met, so the first in-game session answers the spike's question.
- **The world font is set at load.** The module sets `DAMAGE_TEXT_FONT` in its main chunk before `PLAYER_LOGIN`, but only when its switch is on in the saved profile, and `Enable` sets it again. The fallback is the `world` combat-text role, including its saved Appearance override, not the interface `number` role. This is the one thing the module does before `Enable`: it creates no frames and registers no events. `Disable` and switching the option off put back the font the game had. The native renderer caches its font: changing or restoring the global needs a full logout to the character screen and login, not `/reload`. The Lua harness verifies assignment timing and restoration, not that native cache. The global is declared by `Blizzard_Fonts_Shared/Shared/GameFonts.xml` and is already listed on the module's line in `.luacheckrc`.
- **Engine animation.** Each number moves with an AnimationGroup on its own frame: a translation, a second translation for the arc's fall, a scale for the pop and an alpha fade. The engine runs them, so a number costs no `OnUpdate` and no Lua per frame. All four animations sit in one order and run together; the fall and the fade wait with a start delay. Translation offsets are divided by the number's scale, because they apply in the frame's own units.
- **Medallions (KSTY-110, section 3).** Under the Medallions HUD style `Settings.Snapshot` gives every setting the player left at its default the style's value (`Settings.MEDALLIONS`): Barlow Semi Condensed Bold (`BarlowBold`) when the font follows the kit, 20 units with crits 1.4 times (28), damage `#ffd23f`, crits `#fff1a8`, heals `#62d58d`, 0.9 s with the fade over the last 0.3 s, a rise of at most 40 units in the player's field, and at most 6 numbers in one place. A setting the player changed keeps the player's value, and Frames and Orbs keep the defaults above. The switch reaches the module as `ThemeChanged`, which `Core/Widgets/Base.lua` fires when the style enters or leaves Medallions. The `world` role, and so `worldFace` when it follows the kit, is Barlow Semi Condensed Bold too (`Theme.StyleFace`).
- **Motion levels.** At `reduced` numbers fade without moving or popping. At `off` a number shows for its duration, then goes.
- **Pooling and throttling.** The field's numbers come from a pool of 16 and frame numbers from a pool of 64 (see Two pools). The settings preview has its own pool of 12. Each place shows at most `maxPerFrame` numbers, and the oldest makes way for the newest; when a whole pool is on screen, its oldest number makes way. Lanes (centre, left, right) keep three numbers in quick succession apart. The per-event path allocates no tables and makes no frames once the pools warm up; a rescan allocates a list only the first time it meets a unit token; `test-combattext-numbers.lua` and `test-combattext-anchors.lua` check the frame count over 200 events.
- **Fonts on the number's own font string.** Numbers use their own font, size and outline, so they set them with `SetFont` instead of a `Widgets.Text` role, which would put the role's font back on every theme change. A font the game cannot load falls back to the `number` font and logs once.
- **Frames are found, not shared.** Modules never read each other, so CombatText finds the other modules' frames through Layout: for each element key it asks `Layout.Live` whether the owning module runs, then walks the element's frame up to four levels deep, at most 400 frames, for secure buttons with a `unit` attribute. Reading an attribute is allowed in combat. A unit frame with no attribute gets numbers on the element itself. The map from unit token to frames is rebuilt on `Enable`, after a setting or profile change, on `ModuleChanged` for UnitFrames, GroupFrames and Nameplates, and a frame after `GROUP_ROSTER_UPDATE`, when the group headers have moved their buttons. The combat path only looks the token up.
- **Rosters that move.** A group button whose `unit` attribute no longer matches the token gets no number and asks for a rescan on the next frame, even when the button is hidden. A hit on a party, raid or boss token with no frame, while that kind is switched on and its element is live, asks for a rescan at most every 2 seconds, which finds buttons a header made late. A hidden frame gets no number; a secret `IsVisible` counts as shown.
- **Scale follows the frame.** Numbers on unit and group frames take the frame's effective scale against the layer's, so a frame enlarged in Layout Mode gets larger numbers that travel further. Plate numbers keep their own size, because a plate's scale changes with distance.
- **Opacity follows the frame.** A number on a frame takes the frame's `GetEffectiveAlpha` on its font string, so Layout's opacity and mouseover rules and a group frame's range fade apply to it. The value can be secret after `SetAlphaFromBoolean`; it goes straight to `SetAlpha`, which accepts secrets. The font string's alpha multiplies with the frame's fade animation, so the fade still runs.
- **Whose hits.** `UNIT_COMBAT` reports hits a unit takes without identifying the attacker, and the combat log is closed to addons, so KstyleUI cannot tell your hits from other players'. On an enemy that can mean everyone's damage. `units.nameplate` stays off by default. `blizzardTargets` now defaults to Hide to avoid the separate native world display while our scrolling text runs; Keep is the explicit opt-in for Blizzard's player-owned outgoing numbers. Saved choices remain unchanged.
- **Plates.** Nameplate numbers need KstyleUI's Nameplates module: the spec puts numbers on KstyleUI's plates, and the game already draws its own numbers over units. `NAME_PLATE_UNIT_REMOVED` clears a plate's numbers, so they never follow the plate to its next unit. `/kstyle test` counts `UNIT_COMBAT` events from nameplate units, which answers whether Forever fires them.
- **Two pools.** Your field's numbers are the field's children, so its Layout shown rule and opacity apply. Numbers on frames come from a second pool of 64 in the module's layer.
- **Words come from the game.** `MISS`, `DODGE`, `PARRY` and the rest are the game's localised strings, with English fallbacks through `KstyleUI.L`.
- **No combat log.** The combat log is closed to addons on Forever, so incoming numbers come only from `UNIT_COMBAT`.

### EllesmereUI parity audit (2026-11-20)

This is a control-by-control behavioural inventory of public EllesmereUI source at `9409539`, including nested cogs and per-spell overrides, checked on 2026-11-20 against its [CurseForge description](https://www.curseforge.com/wow/addons/ellesmereui), [Wago listing](https://addons.wago.io/addons/ellesmereui), [standalone CDM listing](https://addons.wago.io/addons/eui-cdm), [public gallery](https://www.curseforge.com/wow/addons/ellesmereui/gallery), and release notes [9.1.7](https://www.curseforge.com/wow/addons/ellesmereui/files/8838556), [9.1.8](https://www.curseforge.com/wow/addons/ellesmereui/files/8848122/dependencies), [9.2.1](https://www.curseforge.com/wow/addons/ellesmereui/files/8927870), and [9.2.5](https://www.curseforge.com/wow/addons/ellesmereui/files/8961439/additional-files). Wago's public HTML requires JavaScript and does not enumerate menu rows; the pinned source supplies the detailed inventory. Labels repeated by one shared control builder are one row; their applicability to each group is stated below. Public screenshots confirm the broad icon/bar/number layouts, not hidden menu controls. No source implementation or spell/asset data was copied.

**Missing, fits** means a follow-up batch under the task's roughly 600-line limit, not a client restriction. Custom group/assignment, condition, history and threshold editors together require well over 600 implementation lines; this batch ships the visible switches with existing primitives. **Missing, breaks consistency** identifies independent chrome/style choices we deliberately do not expose. No audited cosmetic control is labelled **Not possible on Forever**: API presence or secrecy is checked at use, and a lack of current implementation is not evidence of impossibility.

| Publicly documented option | KstyleUI status | Control or remaining work | Public source |
| --- | --- | --- | --- |
| Self Combat Text | Present | Modules > Combat Text; Elements > Combat text placement | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L311) |
| Combat Text Size | Present | Combat Text > Size, Font and Outline | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L315) |
| Scroll Distance | Missing, fits | Follow-up batch: expose a separate player-field travel distance; the existing Frame distance applies only to frame emitters | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L323) |
| Scroll Duration | Present | Combat Text > Duration and Critical size | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L326) |
| Crit Scale | Present | Combat Text > Duration and Critical size | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L329) |
| Stagger Hits | Present | Combat Text > Calmer combat numbers / Keep combat text clear (lane staggering and public-hit merging) | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L332) |
| Combat Text Font | Present | Combat Text > Size, Font and Outline | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L352) |
| Animation | Present | Combat Text > Animation (Rise, Arc, Pop) | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Scroll Direction | Present | Combat Text > Scroll direction and Text shadow (new, Current style preserves legacy shadow) | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Font | Present | Combat Text > Size, Font and Outline | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Outline | Present | Combat Text > Size, Font and Outline | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Text Shadow | Present | Combat Text > Scroll direction and Text shadow (new, Current style preserves legacy shadow) | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Abbreviate Numbers | Present | Combat Text > Number format, Damage, Heals, Misses and absorbs, and their colours | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Show Damage Taken | Present | Combat Text > Number format, Damage, Heals, Misses and absorbs, and their colours | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Show Healing Received | Present | Combat Text > Number format, Damage, Heals, Misses and absorbs, and their colours | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Show Avoidance | Present | Combat Text > Number format, Damage, Heals, Misses and absorbs, and their colours | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Show Combat Enter/Leave | Present | Combat Text > Show combat enter and leave / Combat message colour (new, off preserves defaults) | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Show Power Gains | Missing, fits | Follow-up batch: add public COMBAT_TEXT_UPDATE energize events with an optional category colour, never infer gains by subtracting secret power | [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua#L276) |
| Damage/heal/avoidance colours | Present | Damage, Heal and Miss colour rows | [product](https://www.curseforge.com/wow/addons/ellesmereui), [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua) |
| Combat-enter/leave colour | Present | Combat message colour (new) | [product](https://www.curseforge.com/wow/addons/ellesmereui), [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua) |
| Power-gain colour | Missing, fits | Follow-up batch with power gain event category | [product](https://www.curseforge.com/wow/addons/ellesmereui), [source](https://github.com/EllesmereGaming/EllesmereUI/blob/9409539/EllesmereUIOptions/EUI_QoL_Options.lua) |

Forever proof is the local `C:/Users/leeba/.cache/wow-ui-source` tree at `9dc84f0d3bbae1768ac3405b3716000bd93eda06`, under `Interface/AddOns/`:

| New behaviour | Proving source and guard |
| --- | --- |
| Native aura duration swipe | `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`: `SetDurationCooldown` and `ClearDurationCooldown`, duration objects and secret aspects; both methods are checked. Panel's existing out-of-combat/secrecy gate defers rebinding; there is no duration read or per-frame update. |
| Swipe, reverse fill, countdown hiding and opacity | Generated `FrameAPICooldownDocumentation.lua`: `SetDrawSwipe`, `SetReverse`, `SetHideCountdownNumbers`, `SetSwipeColor`; native reskin calls check method presence; addon-created CooldownFrameTemplate widgets use their known methods. |
| Stack visibility, cropping, text offsets and fill opacity | Generated `SimpleRegionAPIDocumentation.lua` (`SetAlpha`), `SimpleTextureBaseAPIDocumentation.lua` (`SetTexCoord`), `SimpleScriptRegionResizingAPIDocumentation.lua` (`SetPoint`), `SimpleStatusBarAPIDocumentation.lua` (`SetStatusBarColor`); native aura count binding owns text/shown state, while the addon writes alpha and never reads it back. The existing shared placement and bar setters apply offsets/opacity. |
| Enter/leave combat | Generated `UnitDocumentation.lua`: `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`; the shared Events service owns guarded registration, unregisters on Disable, and callbacks use the game-localised `ENTERING_COMBAT` / `LEAVING_COMBAT` strings (`Blizzard_CombatText/Shared/CombatText.lua:100,102,285-287`). |
| Text shadow and scroll direction | Generated `SimpleFontStringAPIDocumentation.lua` (`SetShadowOffset`), `SimpleAnimTranslationAPIDocumentation.lua` (`SetOffset`); existing pooled animations are reused, with no frame tick. |
| Full damage/healing numbers | Generated `LocalizationDocumentation.lua` (`BreakUpLargeNumbers`, secret arguments allowed when tainted); availability is checked and call errors fall back to the existing abbreviation. Secret return strings go directly to text setters; nothing parses them. |

All new defaults preserve today's pixels/behaviour: aura swipe off, crop 0.07, zero offsets, stacks/charges on and CDM swipes enabled (the reskin keeps Blizzard's native swipe and Edit Mode timer choices), buff-bar fill opacity 0.15, upward combat text, shadow Current style, combat messages off, meter pin/hover on, short meter numbers. Options remain lazily built. Legacy-profile, write/apply, protected-edit, secret-value and reload-budget coverage is in `test-auras-parity`, `test-cooldowns-parity`, `test-combattext-parity`, `test-meters-parity` and `test-perf-path-budgets`.
