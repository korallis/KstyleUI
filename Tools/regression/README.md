# Regression tests

`run-all.sh` runs every `test-*.lua` in this folder from the repository root and prints the last 5 lines of each failing test. On the Mac, run it with LuaJIT:

```bash
LUA=luajit bash Tools/regression/run-all.sh
```

To see a failing test's full output, run that test alone, for example `luajit Tools/regression/test-taint-scan.lua`.

## Files

Each `test-*.lua` file is one test. The other files are shared by the tests:

| File | What it does |
| --- | --- |
| `toc_files.lua` | Lists the files the game loads, in load order, from the TOCs and their XML includes. |
| `load_files.lua` | Runs addon files in a stub environment with the addon's `...` arguments. |
| `stubs/wow.lua` | A stub WoW API for offline tests. Extend it additively. |
| `widget_env.lua` | Loads the core with the widget kit, boots it, and drives frames like a player: hover, press, click, keys and tween frames. |
| `spike_env.lua` | Loads the spike addon into a stub environment that fakes the game APIs its spikes call. |
| `actionbars_env.lua` | Loads the core and `KstyleUI_ActionBars` into a fake game with action slots, bindings, a pet and forms. Secure frames record protected calls made in combat, and a fake restricted environment runs the bars' page snippet. |
| `lua_source.lua` | Tokenizes Lua 5.1 source and walks it with block and local scopes. The source scanners use it. |
| `taint_scan.lua` | Finds taint risks in addon source. |
| `taint_allow.lua` | Loads and merges the taint-scan allow-list from `taint_allow/`. |
| `secret_lint.lua` | Finds unsafe uses of secret values and any use of the combat log. |
| `color_lint.lua` | Finds colour literals, which belong only in `Core/Tokens.lua`. `test-tokens.lua` runs it. |
| `fixtures/` | Inputs for the tests. luacheck skips this folder. |

## Taint scan

`test-taint-scan.lua` scans every TOC-loaded Lua file outside `Libs/`. Each finding has a kind, a call, and a line.

| Kind | Example call | What it finds |
| --- | --- | --- |
| `frame-call` | `PlayerFrame:SetScript` | A call, with `:` or with `.` and the frame as first argument, of `SetScript`, `Hide`, `SetParent`, `ClearAllPoints`, `SetPoint`, `SetAllPoints`, `SetSize`, `SetWidth`, `SetHeight`, `SetScale`, `UnregisterAllEvents`, `UnregisterEvent`, `RegisterEvent`, `EnableMouse`, `SetAttribute`, or `SetFrameStrata` on a Blizzard frame. |
| `field-write` | `PlayerFrame.unit` | A field written on a Blizzard frame or table, including `function PlayerFrame:OnEvent()`. |
| `game-table-write` | `UISpecialFrames[?]` | A write into `UISpecialFrames`, `UIPanelWindows`, or `hash_SlashCmdList`, also through `tinsert`, `tremove`, or `wipe`. A `StaticPopupDialogs` key without the `KSTYLEUI_` prefix. A `SlashCmdList` key without the `KSTYLE` prefix. An assignment to a Blizzard name. |
| `protected-unguarded` | `SetBinding` | A protected call with no `InCombatLockdown` and no `Combat.Queue` in the 40 lines before it. |
| `setparent-unguarded` | `self.icon:SetParent` | `SetParent` on any frame with no `EditModeManagerFrame:IsShown` and no `Safe.<name>` in the 40 lines before it. |
| `aura-unguarded` | `C_UnitAuras.GetAuraDataByIndex` | `C_UnitAuras` in a file that never calls `C_Secrets.ShouldAurasBeSecret` or `issecretvalue`. |

The protected calls are `PickupAction`, `PlaceAction`, `SetBinding`, `SetOverrideBinding`, `SetOverrideBindingClick`, `ClearOverrideBindings`, `CreateMacro`, `EditMacro`, `C_Container.PickupContainerItem`, `C_Container.UseContainerItem`, `TargetUnit`, `CastSpellByName`, `CastSpellByID`, `UseAction`, `C_Macro.RunMacroText`, `RunMacroText`, `ShowUIPanel`, and `HideUIPanel`.

A Blizzard name is a name in `Tools/data/forever_globals.lua` that does not start with `KstyleUI`. `_G.PlayerFrame` and `_G["PlayerFrame"]` count as `PlayerFrame`, and `_G[name]` counts as the Blizzard frame `_G[?]`.

The scan follows locals within a file:

- A local given a Blizzard path, such as `local f = PlayerFrame` or `local hb = PlayerFrame.healthbar`, counts as that path until it is reassigned or its block ends.
- A reassignment inside a nested block or function may not run, so it never clears that path.
- A local or parameter with a Blizzard name, such as `button` or `text`, hides the global.
- A key computed at run time shows as `[?]` in the call.

The scan does not follow values through function calls, parameters, or table fields. `self:Hide()` inside a hook on a Blizzard frame is not found.

## Taint allow-list

When the scan reports a finding, fix the code. If the call is safe, list it in the allow-list with the reason. The test fails on any finding the list does not cover.

The allow-list is one file per addon folder in `Tools/regression/taint_allow/`. A file lists only its own folder's files, so agents that build different modules never edit the same file:

- `Core.lua` covers `Core/`.
- `KstyleUI_UnitFrames.lua` covers `KstyleUI_UnitFrames/`.

Each file returns a table keyed by the file path from the repository root:

```lua
return {
	["KstyleUI_Tooltips/Tooltips.lua"] = {
		why = "GameTooltip is hidden on mouse-out, as Blizzard's own buttons do. It is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 2,
		},
	},
}
```

- `why` is required. It says why each listed call is safe.
- `calls` maps each call, written exactly as the scan prints it, to the number of places in the file that make it.
- One place can give two findings with the same call: `PlayerFrame:SetParent` with no Edit Mode check is a `frame-call` and a `setparent-unguarded` finding. It still counts as one place.

The file runs with no globals and holds data only. The test fails when:

- A finding's call has no entry.
- A call is found in more or fewer places than its count.
- An entry matches no finding, or its path is not a TOC-loaded Lua file.
- An area file is not named after a folder, lists a path outside its folder, or has an entry without a `why`.

Each failure message names the file and line, and the area file to change.

## Secret lint

`test-secrets.lua` runs `secret_lint.lua` over every TOC-loaded Lua file outside `Libs/` and fails on any finding. It has no allow-list. When a use is safe, guard it with `issecretvalue`.

A secret source is `UnitHealth`, `UnitHealthMax`, `UnitHealthMissing`, `UnitHealthPercent`, `UnitInRange`, `UnitPower`, `UnitPowerMax`, `UnitCastingInfo`, `UnitChannelInfo`, `UnitGetIncomingHeals`, or any `C_UnitAuras` function. A secret value is a local given a secret source's result, directly, through `select` or `pcall`, or from another secret value. Each field of a secret value, such as `aura.duration`, is a secret value too.

| Kind | What it finds |
| --- | --- |
| `compare` | A secret value or a secret call next to `<`, `>`, `<=`, `>=`, `==`, or `~=`. |
| `arith` | A secret value or a secret call next to `+`, `-`, `*`, `/`, `%`, or `^`. |
| `length` | `#` before a secret value. |
| `key` | A secret value used as a table key or index: `t[hp]`, `{ [hp] = true }`. |
| `bool` | A secret value after `if`, `elseif`, `while`, `until`, or `not`, or before `and`, `or`, `then`, or `do`. |
| `combatlog` | Any name or string that holds `COMBAT_LOG_EVENT`, and `CombatLogGetCurrentEventInfo`. |

Passing a secret on is allowed: to a widget setter, to `AbbreviateNumbers`, into a table, or with `..`.

A use is guarded, and allowed, when a check `issecretvalue(x)` on the same path proves the value is not secret. `issecretvalue(aura)` does not guard `aura.duration`. The check guards a use in these cases:

- It comes earlier in the same expression, joined the right way: `not issecretvalue(hp) and hp < 10`, or `issecretvalue(hp) or hp < 10`.
- The use is in the branch of an `if` whose condition holds `not issecretvalue(hp)` and no `or`.
- The use is in a later `elseif` or `else` branch, and an earlier condition holds `issecretvalue(hp)` and no `and`.
- An earlier `if issecretvalue(hp) then ... end` in the same block has no `and` and no other branch, and its body returns or gives `hp` a value that is not secret.

A guard ends when the local is given a secret value after the check.

```lua
local hp = UnitHealth(unit)
if issecretvalue(hp) then
	bar:SetValue(hp)
	return
end
if hp < 10 then
	-- hp is a plain number here
end
```

The lint follows locals within a file. It does not follow values through function parameters or table fields such as `self.hp` and `t[1]`. A `while` condition does not guard the loop body, and a check on one local does not guard another local that holds the same value.
