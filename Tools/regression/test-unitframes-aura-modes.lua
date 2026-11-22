-- test-unitframes-aura-modes.lua: Medallions rows and the target's Medallions fan keep their own player and target aura settings (Frames and the fan share the rest): untouched each layout draws its look and its Options row shows it, any choice (another layout's default included) survives a reload without touching another layout's own, and older profiles draw what they drew before.
local U = dofile("Tools/regression/unitframes_env.lua")
local KEYS = { "auraPosition", "auraGrowth", "auraSize", "auraSpacing", "auraColumns", "auraRows" }
local LABELS = { auraPosition = "Aura position", auraGrowth = "Aura growth", auraSize = "Aura icon size", auraSpacing = "Aura spacing", auraColumns = "Aura columns", auraRows = "Aura rows" }
local MODES = { { "frames", "frames", "rows" }, { "rows", "medallions", "rows" }, { "fan", "medallions", "fan" } }
local LOOK = {
	frames = { player = { "BELOW", "RIGHT_DOWN", 22, 2, 8, 1 }, target = { "SIDE", "RIGHT_DOWN", 27.6, 4, 4, 1 } },
	rows = { player = { "ABOVE", "RIGHT_UP", 28, 2, 6, 2 }, target = { "ABOVE", "LEFT_UP", 28, 2, 6, 2 } },
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
local function Copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
	return out
end

Boot()
K.Options.Write("UnitFrames", "player.auras", true)
K.Options.Write("UnitFrames", "player.medallionsAuras", true)
for _, mode in ipairs(MODES) do Check(mode, LOOK, "untouched") end

local SLAB = { auraGrowth = true, auraSize = true, auraSpacing = true, auraColumns = true }
local function Stored(mode, kind, key)
	return mode == "rows" and "rows" or mode == "fan" and kind == "target" and SLAB[key] and "slab" or "base"
end
local want = Copy(LOOK)
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
	player = { auras = true, medallionsAuras = true, auraGrowth = "LEFT_UP" }, target = { auraSize = 30, auraColumns = 6, auraRows = 1 } } } } }
Boot(old)
want = Copy(LOOK)
for _, mode in pairs(want) do
	mode.player[2], mode.target[3], mode.target[5] = "LEFT_UP", 30, 6
end
for _, mode in ipairs(MODES) do Check(mode, want, "an older profile") end
K.Options.Write("UnitFrames", "focus.auraCopy", "target")
K.Options.Write("UnitFrames", Shown("target", "auraSize"), 33)
assert(ns.Frames.Get("focus").s.auraSize == 33, "a frame that copies the target's auras follows its layout's own size; restyle it in Frames.lua OnSettingChanged")
print("ok: Frames, Medallions rows and fan each keep their player and target aura settings; older profiles draw as before")
