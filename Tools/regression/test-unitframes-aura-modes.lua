-- test-unitframes-aura-modes.lua: Medallions rows, the target's rows on Debuffs and buffs and the target's Medallions fan keep their own player and target aura settings (Frames and the fan share the rest): untouched each layout draws its look and its Options row shows it, any choice (another layout's default included) survives a reload without touching another layout's own, older profiles draw what they drew before, and a frame copying the target's auras follows its size and row count, also when the target's filter changes.
local U = dofile("Tools/regression/unitframes_env.lua")
local KEYS = { "auraPosition", "auraGrowth", "auraSize", "auraSpacing", "auraColumns", "auraRows" }
local LABELS = { auraPosition = "Aura position", auraGrowth = "Aura growth", auraSize = "Aura icon size", auraSpacing = "Aura spacing", auraColumns = "Aura columns", auraRows = "Aura rows" }
local MODES = { { "frames", "frames", "rows", "mine" }, { "rows", "medallions", "rows", "mine" }, { "both", "medallions", "rows", "both" }, { "fan", "medallions", "fan", "mine" } }
local LOOK = {
	frames = { player = { "BELOW", "RIGHT_DOWN", 22, 2, 8, 1 }, target = { "SIDE", "RIGHT_DOWN", 27.6, 4, 4, 1 } },
	rows = { player = { "ABOVE", "RIGHT_UP", 28, 2, 6, 2 }, target = { "ABOVE", "LEFT_UP", 28, 2, 6, 2 } },
	both = { player = { "ABOVE", "RIGHT_UP", 28, 2, 6, 2 }, target = { "ABOVE", "LEFT_UP", 28, 2, 6, 1 } },
	fan = { player = { "BELOW", "RIGHT_DOWN", 22, 2, 8, 1 }, target = { "SIDE", "LEFT_DOWN", 22, 2, 6, 1 } },
}

local env, K, ns
local function Boot(saved)
	env, K, ns = U.New({ saved = saved })
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
local function Enter(mode)
	K.Options.Write("HudStyle", "style", mode[2])
	K.Options.Write("UnitFrames", "auraLayout", mode[3])
	K.Options.Write("UnitFrames", "target.auraFilter", mode[4])
	env.RunTimers()
end
local function Shown(kind, key)
	K.Options.Write("UnitFrames", "edit", kind)
	local settings, found = K.Store.Module("UnitFrames")
	for _, row in ipairs(K.Options.Get("UnitFrames")) do
		if row.scope and row.scope.value == kind and row.label == LABELS[key] and row.showWhen(settings) then
			assert(not found, kind .. " " .. key .. ": the page shows one row for it")
			found = row.key
		end
	end
	return assert(found, kind .. " " .. key .. ": the page shows a row for it")
end
local function Check(mode, want, why)
	Enter(mode)
	for kind, values in pairs(want[mode[1]]) do
		for i, key in ipairs(KEYS) do
			local value, row = ns.Settings.Value(kind, key), Shown(kind, key)
			assert(value == values[i], string.format("%s: %s %s %s draws %s, want %s", why, mode[1], kind, key, tostring(value), tostring(values[i])))
			assert(K.Options.Read("UnitFrames", row) == value, string.format("%s: %s %s's %s row (%s) shows %s, the frame draws %s", why, mode[1], kind, key, row, tostring(K.Options.Read("UnitFrames", row)), tostring(value)))
		end
	end
end

Boot()
K.Options.Write("UnitFrames", "player.auras", true)
K.Options.Write("UnitFrames", "player.medallionsAuras", true)
for _, mode in ipairs(MODES) do Check(mode, LOOK, "untouched") end

local function Stored(mode, kind, key)
	if mode == "both" and kind == "target" and key == "auraRows" then return "rowsBoth" end
	return (mode == "rows" or mode == "both") and "rows" or mode == "fan" and kind == "target" and key ~= "auraRows" and key ~= "auraPosition" and "slab" or "base"
end
local want = K.Options.Copy(LOOK)
for _, mode in ipairs(MODES) do
	Enter(mode)
	for kind, values in pairs(want[mode[1]]) do
		for i, key in ipairs(KEYS) do
			local chosen
			for _, other in ipairs(MODES) do
				local value = LOOK[other[1]][kind][i]
				if chosen == nil and value ~= values[i] then chosen = value end
			end
			chosen = chosen or values[i] + 1
			K.Options.Write("UnitFrames", Shown(kind, key), chosen)
			for _, other in ipairs(MODES) do
				if Stored(other[1], kind, key) == Stored(mode[1], kind, key) then want[other[1]][kind][i] = chosen end
			end
		end
	end
	env.FireEvent("PLAYER_LOGOUT")
	Boot(env.KstyleUIDB)
	for _, other in ipairs(MODES) do Check(other, want, "after choosing in " .. mode[1] .. " and a reload") end
end

local old = { version = 47, profiles = { Default = { HudStyle = { style = "medallions" }, UnitFrames = { enabled = true,
	player = { auras = true, medallionsAuras = true, auraGrowth = "LEFT_UP", auraRows = 1 }, target = { auraSize = 30, auraColumns = 6, auraRows = 3 } } } } }
Boot(old)
want = K.Options.Copy(LOOK)
for _, mode in pairs(want) do
	mode.player[2], mode.target[3], mode.target[5], mode.target[6] = "LEFT_UP", 30, 6, 3
end
for _, mode in ipairs(MODES) do Check(mode, want, "an older profile") end
Enter(MODES[2])
K.Options.Write("UnitFrames", "focus.auraCopy", "target")
K.Options.Write("UnitFrames", Shown("target", "auraSize"), 33)
assert(ns.Frames.Get("focus").s.auraSize == 33, "a frame that copies the target's auras follows its layout's own size; restyle it in Frames.lua OnSettingChanged")
for _, case in ipairs({ { "both", 1 }, { "mine", 3 } }) do
	K.Options.Write("UnitFrames", "target.auraFilter", case[1])
	K.Options.Write("UnitFrames", Shown("target", "auraRows"), case[2])
end
for _, case in ipairs({ { "both", 1 }, { "mine", 3 }, { "both", 1 } }) do
	K.Options.Write("UnitFrames", "target.auraFilter", case[1])
	local rows, held = ns.Settings.Value("focus", "auraRows"), ns.Frames.Get("focus").views[1].auras.container._groups.debuffs.max
	assert(rows == case[2] and held == rows * ns.Settings.Value("focus", "auraColumns"), string.format("the target on %s: the copying focus holds %d auras, want %d rows of %d; restyle it when the target's filter changes in Frames.lua OnSettingChanged", case[1], held, rows, ns.Settings.Value("focus", "auraColumns")))
end
print("ok: Frames, Medallions rows, rows on Debuffs and buffs and fan each keep their player and target aura settings; older profiles draw as before")
