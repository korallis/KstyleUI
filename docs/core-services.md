# Core services reference

The core addon's service files in `Core/` carry no comments beyond their first line, so their contracts live here. The roadmap's [Core public API](superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page adds the details and the extra functions the services expose. Tests: `Tools/regression/test-lifecycle.lua`, `test-combat.lua`, `test-store.lua`, `test-features.lua`, `test-options-registry.lua`, `test-devtest.lua` and `test-cvars.lua`.

## Load and login order

1. The core's files run in the order `Core/Core.xml` lists them. `Codec.lua` loads before `Store.lua`, and `Slash.lua` loads after `Options.lua`.
2. `ADDON_LOADED` for `KstyleUI`: `Store` loads `KstyleUIDB`, repairs it, runs migrations and picks the character's profile.
3. Module addons load next. Each calls `KstyleUI.Modules.Register(def)` and, after it, `KstyleUI.Options.Register(name, schema)`. Neither call starts anything.
4. `PLAYER_LOGIN`: `Modules` runs `Enable` for each registered module whose switch is on, even in combat.
5. Once `PLAYER_LOGIN` and `VARIABLES_LOADED` have both fired, [`CVars`](#cvars) puts back the CVars that modules which are off on this character had hidden.
6. `PLAYER_LOGOUT`: `Store` saves each profile with only the values that differ from the defaults. The live tables keep their defaults, so other logout handlers still read them.

## Shared helpers (`Init.lua`)

| Name | Behaviour |
| --- | --- |
| `KstyleUI.Call(fn, ...) -> ok, ...` | Runs `fn`. An error goes to `geterrorhandler()`, is counted and is logged to the devlog. Use it where one failure must not stop the next caller. In the game `xpcall` passes the arguments, so `Call` allocates nothing. Plain Lua 5.1 in CI falls back to a closure. |
| `KstyleUI.ErrorCount() -> number` | Errors that `Call` caught since login. `/kstyle test` fails when it is above 0. |
| `KstyleUI.Print(message)` | Prints `KstyleUI: <message>` to chat. |

## Callbacks

| Function | Behaviour |
| --- | --- |
| `Register(event, owner, fn)` | `fn(owner, ...)` runs on each `Fire`. One function per owner and event: registering again replaces it. `owner` is required. |
| `Unregister(event, owner)` | Removes one owner from one event. |
| `UnregisterAll(owner)` | Removes the owner from every event. |
| `Fire(event, ...)` | Runs subscribers in registration order. A failing subscriber is reported through `Call`, and the rest still run. A subscriber added during a `Fire` first runs on the next `Fire`. |

The events are `ThemeChanged`, `ClassChanged`, `ScaleChanged`, `ProfileChanged(new, old)`, `SettingChanged(module, key, value)`, `ReloadNeeded(module)`, `LayoutChanged(key)`, which [Layout](../Core/Layout/README.md) fires when an element's settings change, and `ModuleChanged(name, running)`, which `Modules` fires after a module starts or stops. Any other name raises an error. To add an event, add its name to the `EVENTS` table in `Core/Callbacks.lua`.

When a module is disabled, `Modules` removes every callback whose owner is the module's name.

## Events

Each owner gets one event frame, created on its first `Register`.

| Function | Behaviour |
| --- | --- |
| `Register(owner, event, fn)` | `fn(event, ...)` runs on the event through `KstyleUI.Call`, so an error is reported and counted, and other frames still get the event. |
| `RegisterUnit(owner, event, fn, unit1, unit2)` | The same, filtered to one or two units with `RegisterUnitEvent`. |
| `Unregister(owner, event)` | Stops one event. |
| `UnregisterAll(owner)` | Stops every event of the owner. |

When `owner` is a module name from `Features.modules`, `Register` raises an error unless the module is running. Register module events in `Enable`. `Modules` calls `UnregisterAll` after `Disable`. Any other owner, such as a core service, can register at any time.

## Modules

`def = { name, defaults, Enable, Disable, reskin }`.

- `name` must be a key of `Features.modules`.
- `defaults` holds the module's settings. `defaults.enabled` may be left out. If it is present, it must equal the module's switch in `Features.modules`.
- `Enable(def)` and `Disable(def)` are called with the definition as `self`.
- `reskin = true` marks a module that changes Blizzard frames in place. Turning it off prints a `/reload` request and fires `ReloadNeeded`.

| Function | Behaviour |
| --- | --- |
| `Register(def)` | Validates `def`, registers its defaults with `Store`, and starts the module at once if the player has logged in and its switch is on. |
| `IsEnabled(name) -> boolean` | True when the module is registered and its switch is on in the active profile. Raises an error for a name that is not in `Features.modules`. |
| `IsRunning(name) -> boolean` | True between a successful `Enable` and the next `Disable`. |
| `HasFailed(name) -> boolean` | True when the last `Enable` raised an error. `Disable` ran to clean up. |
| `Enable(name)`, `Disable(name)` | Set the switch in the active profile, then start or stop the module. In combat the change waits for `Combat.Queue`. Before `PLAYER_LOGIN` only the switch changes. |
| `List() -> { name, ... }` | Registered modules in registration order. |
| `NeedsReload() -> boolean` | True after a `reskin` module was turned off. |

A profile change starts and stops modules to match the new profile's switches.

After `Enable` succeeds, `Modules` fires `ModuleChanged(name, true)`. After `Disable`, or after a failed `Enable` and its cleanup, it fires `ModuleChanged(name, false)`. `IsRunning` already gives the new state when the callback runs.

## Combat

`Combat.Queue(fn)` runs `fn` at once out of combat. In combat it holds `fn` and runs the queue in order on `PLAYER_REGEN_ENABLED`. A failing entry is reported and the rest still run. The core listens for `PLAYER_REGEN_ENABLED` only while the queue holds work. `Combat.Pending()` returns the number of held entries.

## CVars

A module that writes a game CVar puts the player's own value back when it stops. A module that is off at login runs no code, so without this service a character that logs in with the module off keeps what KstyleUI wrote on an earlier login, or on another character. `Core/CVars.lua` closes that gap once per login. It has no functions to call.

It reads the memories the modules keep in `KstyleUIDB.account`. Each record is `{ original, written }`: the player's value and the value the module wrote.

| Memory | Module | Records this character owns |
| --- | --- | --- |
| `combatTextCVars[<owner>][<cvar>]` | `CombatText` | `*`, for CVars the game saves for every character, and the character key, for CVars it saves per character |
| `chatTimestamps[<character key>]` | `Chat` | The character key's record, for `showTimestamps` |

The service starts when both `PLAYER_LOGIN` and `VARIABLES_LOADED` have fired, in either order. `PLAYER_LOGIN` is when `Modules` starts the modules. `VARIABLES_LOADED` is when the character's saved CVars have loaded, which can be after `PLAYER_LOGIN`; before it, a CVar can read the game's default, which would look like the player's change. Blizzard's own settings wait for the same event before they read CVars. The service then waits one frame and runs through `Combat.Queue`, so in combat it waits for combat to end. For each record this character owns whose module is not running (`Modules.IsRunning`) at that moment:

| Case | What happens |
| --- | --- |
| The CVar still holds `written`, and `original` differs from it | `original` is written and read back, the record is cleared, and the devlog names the CVar. |
| The CVar holds any other value, or the record is damaged | The player changed it since, so the value stays and the record is cleared. |
| The game refuses the value | KstyleUI's value stays, the record stays for the next login, and the devlog says so once. |
| The client has no `C_CVar.GetCVar` or `C_CVar.SetCVar` | Nothing changes, every record stays, and the devlog says so once. |

Records of other characters wait for those characters' logins. A shared (`*`) record comes back on any character whose module is off; the next character that runs the module hides the CVar again at its own login and takes the restored value as the player's. A running module keeps its records, because it restores them itself when it stops. To cover another module's CVar memory, add it to `MEMORIES` in `Core/CVars.lua`.

## Safe

| Function | Behaviour |
| --- | --- |
| `HideBlizzard(frame)` | Reparents `frame` to a hidden frame after `C_Timer.After(0)`. In combat it waits for `Combat.Queue`. While Edit Mode is open it waits for the `EditMode.Exit` callback on `EventRegistry`. A `nil` frame is logged and skipped, so pass `_G.SomeFrame` without a check. Hiding a frame twice does nothing. |
| `RestoreBlizzard(frame)` | Returns a hidden frame to its first parent, with the same deferral and guards. |
| `IsHidden(frame) -> boolean` | True after `HideBlizzard` has reparented the frame. |
| `Side(frame) -> table` | Per-frame state in a weak-keyed table. Never write fields onto a Blizzard frame. Use this table instead. |

## Store

### Saved data

`KstyleUIDB` follows the spec: `version`, `profiles`, `characters` (`"<realm>-<name>" = profileName`), `layouts`, `account` and `devlog`. Load repairs fields of the wrong type and drops profiles that are not tables.

### Defaults

- Every setting needs a default. `Import` rejects a key that a loaded module did not declare.
- A setting keeps its default's type. On load, a stored value of another type is replaced with the default.
- A default table that is a list, or is empty, is one value: it is saved whole and replaced whole. Any other default table merges key by key.
- Defaults hold only booleans, finite numbers, strings and tables. Colour defaults come from `KstyleUI.Tokens`, never from literals.
- A core service registers its own section with `Store.RegisterDefaults(section, defaults)`.

### Functions

| Function | Behaviour |
| --- | --- |
| `Profile() -> table` | The active profile: one table per section. |
| `Module(name) -> table` | One section of the active profile, with its defaults filled in. Raises an error for an unknown section. Fetch it again on `ProfileChanged`, because a profile switch, copy or reset replaces the table. |
| `Account() -> table` | Account-wide settings, filled from `Features.account`. |
| `Layout() -> table` | The active profile's layout table, `[elementKey] = position`. |
| `RegisterDefaults(section, defaults)`, `Defaults(section)` | Register and read a section's defaults. |
| `ProfileName()`, `ListProfiles()` | The active profile's name, and every profile name in sorted order. |
| `SetProfile(name)` | Assigns the character to the profile, creating it if needed, and fires `ProfileChanged`. |
| `CreateProfile(name)`, `CopyProfile(source, target)`, `RenameProfile(old, new)`, `DeleteProfile(name)`, `ResetProfile(name)` | Return `true`, or `false` and a reason. The active profile cannot be deleted. Characters on a deleted profile fall back to `Default`. A change to the active profile fires `ProfileChanged`. |
| `CharacterKey() -> key` | The logged-in character's `"<realm>-<name>"`, or `nil` before the game knows it. |
| `Characters() -> { [key] = profileName }` | A copy of every character's profile assignment. Empty before the saved data loads. |
| `AssignCharacter(key, name) -> ok, reason` | Moves a known character to an existing profile. For the logged-in character it is `SetProfile` and fires `ProfileChanged`; for any other character it only saves the assignment, which applies at that character's next login. An unknown character, a missing profile or a bad name returns `false` and a reason. |
| `Export(name) -> string, path` | A `KSUI1:` string for the profile, or the active one. `path` is `"C_EncodingUtil"` or `"Lua"`. |
| `Decode(text) -> payload` or `nil, reason` | Validates a string and applies nothing. |
| `Import(text, name) -> true, profileName` or `false, reason` | Validates the string, saves it as a new profile under a free name, and switches to it. |
| `DB_VERSION`, `migrations[v]` | `migrations[v](db)` upgrades saved data from version `v - 1` to `v`. Load runs each missing step in order, and `Import` runs the same steps on older profiles. |
| Version 2 | `migrations[2]` replaces each profile's `Appearance.reducedMotion` switch with `Appearance.motion`: `true` becomes `"off"`, and `false` drops the key, leaving the default `"full"`. |

Profile names are 1 to 48 characters, trimmed, with no control characters and no `|`.

### Profile strings

A profile string is `KSUI1:` followed by base64 (RFC 4648, standard alphabet).

- With `C_EncodingUtil`, the base64 holds `CompressString(SerializeCBOR(payload), Zlib)`.
- Without it, or when it fails, the base64 holds `KSL1:<length>:<adler32>:<body>`. `<body>` is `Codec.Serialize(payload)`: `s<len>:<bytes>`, `n<number>;`, `T`, `F`, and `{ key value ... }` with sorted keys.

The payload is `{ kind = "KstyleUI profile", version, name, settings, layout }`. `Decode` rejects, with a reason, any string that:

- is empty, is longer than 131,072 characters, or does not start with `KSUI1:`.
- has bad base64, a wrong length or checksum, a broken zlib stream, or trailing data.
- inflates past 2 MB, nests deeper than 12 levels, or holds more than 20,000 values.
- holds a string over 1,024 bytes, a control character, a key over 64 characters, a key that is not text or a whole number, or a number that is not finite.
- has another `kind`, an extra top-level field, a version newer than `DB_VERSION`, or a bad name.
- has an unknown section, an unknown setting, a value of the wrong type, a slider value out of range, or a dropdown value that is not an option. A dropdown whose `options` is a function is checked against the list the function returns. If the function fails, the value is rejected.

When `C_EncodingUtil.DecodeBase64` fails, `Decode` decodes the base64 with `Codec.DecodeBase64` instead.

## Options

`Options.Register(module, schema)` needs the module's defaults first. `schema` is a list of rows. Besides the rows, the schema may hold one named field, `preview`: a `function(parent) -> frame` that builds the module's live preview inside `parent`, the settings window's preview pane. The window calls it once, the first time the module's page opens, shows the frame while the page is open, and calls `frame:Refresh()`, when the frame has one, after any of the module's settings changes.

| Field | Rows | Rule |
| --- | --- | --- |
| `type` | all | `header`, `toggle`, `slider`, `dropdown`, `color`, `font`, `texture` or `text` |
| `label` | all | Required text |
| `key` | all but `header` | A setting name, with dots for nested settings such as `player.healthText.size`. It must have a default, and it appears once per schema. |
| `help` | all but `header` | One sentence under 100 characters |
| `showWhen`, `disableWhen` | all | Optional `function(settings) -> boolean`. `settings` is `Store.Module(module)`. |
| `scope` | all | Optional `{ key = setting, value = value }` for a row that a picker dropdown shows, such as `{ key = "edit", value = "target" }`. `key` is a top-level setting with a default, and `value` has the default's type and is not a table. Search runs the row's `showWhen` as if `key` held `value`, so it finds the row whatever the picker holds. The page ignores `scope`. |
| `min`, `max`, `step` | `slider` | Numbers with `min < max`, `step > 0`, and the default in range |
| `options` | `dropdown` | `{ { value, label }, ... }` holding the default, or a function that returns such a list |
| `hasAlpha` | `color` | Optional boolean |
| `maxLetters` | `text` | Optional whole number above 0 |

The default's type must match the row: `toggle` takes a boolean, `slider` a number, `dropdown` a string or a number, `color` a table with `r`, `g` and `b`, and `font`, `texture` and `text` a string. Any other field raises an error. To add a field, add it to the field tables in `Core/Options.lua`.

| Function | Behaviour |
| --- | --- |
| `Get(module)`, `Row(module, key)`, `List()` | Read the schemas. |
| `Preview(module) -> function` | The schema's `preview` builder, or `nil`. |
| `Read(module, key)`, `Write(module, key, value)` | Read and write a setting by dotted key. `Write` checks the type and fires `SettingChanged`. Writing a module's `enabled` key calls `Modules.Enable` or `Modules.Disable`. |
| `SetWindow(show)` | `KstyleUI_Options` calls it when it loads. `show(page)` opens the settings window. |
| `Open(page)` | Loads `KstyleUI_Options` on demand, then calls `show(page)`. Returns `false` and prints the reason when it cannot. |

### Other ways in

`Core/OptionsEntry.lua` gives the settings window two more doors besides `/kstyle`. Test: `test-options-entry.lua`.

- At `PLAYER_LOGIN` it registers a canvas category named `KstyleUI` in Blizzard's Settings panel with `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory`. The canvas is one empty frame until the player first selects the category; then it builds the logo, a line of text and an **Open KstyleUI settings** button from the widget kit. The button calls `Options.Open()`. A client without the Settings API, or one that refuses the category, gets a devlog line and no category.
- The core TOC names `KstyleUI_OnAddonCompartmentClick` as its `AddonCompartmentFunc`, so the minimap's addon compartment lists KstyleUI. A click calls `Options.Open()`.

The canvas never calls `SettingsPanel` methods, so it cannot taint Blizzard's settings. The settings window opens in the `HIGH` strata as a top-level frame, so it shows over the Settings panel.

## Icons

The core has no icon service. KstyleUI's repainted icons ship as a loose-file texture pack the client loads from `_forever_/Interface/Icons`, so every texture that shows a game icon just calls `SetTexture(fileID)` and the client swaps the file; see [`docs/icons.md`](icons.md). Saved data from before this change carried `Icons` and `IconsColour` sections, which `Store.migrations[3]` drops.

## Setup

`Core/Setup/` holds the first-run setup: it opens once per account, picks a DPS, Tank or Healer layout and the modules, then applies both and offers the secure reload button. `/kstyle setup` reopens it. Its steps, `Apply` and functions are in [`Core/Setup/README.md`](../Core/Setup/README.md). The account switch `Features.account.setupSeen` records that it ran.

## DevTest

- `DevTest.Log(module, message)` appends `{ time, module, message }` to `KstyleUIDB.devlog`. The devlog keeps the newest 500 entries. A message is cut to 1,000 characters, and a secret value is stored as `<secret>`. Entries logged before `ADDON_LOADED` are kept and written once the saved data loads.
- `DevTest.AddCheck(name, fn)` adds a smoke check. `fn` returns `ok, detail`.
- `DevTest.Run()` logs one `PASS`, `WARN` or `FAIL` line per check and returns `passed, failed, warnings`. It checks the store, each module that is switched on, the caught errors and the blocked actions of KstyleUI addons, the APIs the core uses, an export round trip, and each added check.

## The /kstyle command

| Command | Action |
| --- | --- |
| `/kstyle` | `Options.Open()` |
| `/kstyle layout` | `KstyleUI.Layout.Toggle()` |
| `/kstyle setup` | `KstyleUI.Setup.Open()` |
| `/kstyle test` | `DevTest.Run()` |
| `/kstyle profile` | Lists the profiles and marks the active one with `*` |
| `/kstyle profile use, new, copy, rename or delete <name>` | `SetProfile`, `CreateProfile`, `CopyProfile(<name>, active)`, `RenameProfile(active, <name>)` or `DeleteProfile` |
| `/kstyle profile reset` | `ResetProfile()` |

Layout Mode and the first-run setup provide `KstyleUI.Layout.Toggle` and `KstyleUI.Setup.Open`. Until they exist, the command prints that the feature is not available yet. [`Core/Layout/README.md`](../Core/Layout/README.md) documents Layout.
