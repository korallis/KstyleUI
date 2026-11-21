-- test-store-reads.lua: every Settings read on a fresh and an upgraded profile is the saved value over the registered default, survives logout and reload unchanged, and bad defaults still name their path.
local Suite = dofile("Tools/regression/suite_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local DeepCopy, DeepEqual, Raises = CoreEnv.DeepCopy, CoreEnv.DeepEqual, CoreEnv.Raises

-- The read a setting must give: a saved value of the default's type, else the default; a list default is replaced whole,
-- a map keeps the saved keys and merges its own key by key.
local function Over(saved, default)
	if type(default) ~= "table" then
		if type(saved) == type(default) then return saved end
		return default
	end
	if type(saved) ~= "table" then return DeepCopy(default) end
	if next(default) == nil or default[1] ~= nil then return saved end
	local out = DeepCopy(saved)
	for key, value in pairs(default) do out[key] = Over(saved[key], value) end
	return out
end

local function Reads(K)
	local reads = {}
	for section in pairs(K.Store.Profile()) do reads[section] = DeepCopy(K.Store.Module(section)) end
	return reads
end

-- Boot the whole suite on saved data; before PLAYER_LOGIN each registered section must read raw over its defaults.
local function Boot(saved, raw, label)
	local env = Suite.New(saved, 1920, 1080, nil, function(_, K)
		raw = raw or K.Store.Profile()
		local checked = 0
		for section, values in pairs(Reads(K)) do
			local defaults = K.Store.Defaults(section)
			if defaults then
				local same, where = DeepEqual(values, Over(raw[section], defaults), section)
				assert(same, label .. ": " .. tostring(where))
				checked = checked + 1
			end
		end
		assert(checked > 20, label .. ": only " .. checked .. " sections were read")
	end)
	env.FireEvent("PLAYER_ENTERING_WORLD", false, true)
	env.RunTimers()
	return env, env.KstyleUI
end

local function RoundTrip(env, K, label)
	local reads = Reads(K)
	env.FireEvent("PLAYER_LOGOUT")
	local saved = DeepCopy(env.KstyleUIDB)
	local again, AK = Boot(DeepCopy(saved), nil, label .. " reload")
	local same, where = DeepEqual(Reads(AK), reads, "reads")
	assert(same, label .. ": a read changed across logout and reload: " .. tostring(where))
	again.FireEvent("PLAYER_LOGOUT")
	again.KstyleUIDB.devlog, saved.devlog = nil, nil
	same, where = DeepEqual(again.KstyleUIDB, saved, "KstyleUIDB")
	assert(same, label .. ": the saved data changed across a reload: " .. tostring(where))
end

-- A fresh install reads every default.
local env, K = Boot(nil, {}, "fresh")
RoundTrip(env, K, "fresh")

-- Old saved data: migrations run first, then wrong types fall back to the default and unknown keys are kept.
local FONT = "Interface/AddOns/KstyleUI/Media/Fonts/Custom.ttf"
local OLD = { version = 1, characters = {}, layouts = { Default = {} }, profiles = {
	Default = {
		Appearance = { font = "Folio", fontScale = 1.2, snapEdges = "yes" },
		UnitFrames = { enabled = true, resource = 7, player = { face = FONT }, junk = { 1, 2 } },
		Meters = { followRole = true, threat = "x" },
		Chat = { tabPadding = "wide", inputOnTop = 1, framing = "card" },
		ActionBars = 5,
		Nameplates = { debuffs = { unknown = true } },
		QoL = { statsList = { { id = "durability" } } },
	},
	Second = { Chat = { framing = "card" } },
} }
local migrated = DeepCopy(OLD)
for version = OLD.version + 1, K.Store.DB_VERSION do
	local step = K.Store.migrations[version]
	if step then step(migrated) end
end
env, K = Boot(DeepCopy(OLD), migrated.profiles.Default, "upgraded")
assert(K.Store.Module("UnitFrames").player.face == FONT and K.Fonts.IsLoaded(FONT), "a saved font path deep in a section is read and requested")
RoundTrip(env, K, "upgraded")

-- A section replaced in the profile reads as the new table, even one an __eq metamethod calls equal to the old.
K.Store.RegisterDefaults("ReadProbe", { text = "first" })
local eq = { __eq = function() return true end }
setmetatable(K.Store.Module("ReadProbe"), eq)
K.Store.Profile().ReadProbe = setmetatable({ text = "second" }, eq)
assert(K.Store.Module("ReadProbe").text == "second", "Store.Module must read the profile's current section by identity, never ==")

-- A deleted profile's sections are freed once nothing else holds them.
local held = setmetatable({}, { __mode = "v" })
assert(K.Store.SetProfile("Temporary"))
held[1] = K.Store.Module("ReadProbe")
assert(K.Store.SetProfile("Default") and K.Store.DeleteProfile("Temporary"))
collectgarbage()
collectgarbage()
assert(held[1] == nil, "Store.Module must keep no reference to a section the active profile no longer holds")

-- Bad defaults are refused with the path of the bad value.
Raises(function() K.Store.RegisterDefaults("BadKey", { a = { [true] = 1 } }) end, "BadKey defaults.a has a boolean key")
Raises(function() K.Store.RegisterDefaults("BadNumber", { a = { b = 0 / 0 } }) end, "BadNumber defaults.a.b is not a finite number")
Raises(function() K.Store.RegisterDefaults("BadInf", { list = { 1, -math.huge } }) end, "BadInf defaults.list.2 is not a finite number")
Raises(function() K.Store.RegisterDefaults("BadType", { f = print }) end, "BadType defaults.f is a function; settings hold only")
assert(K.Store.Defaults("BadKey") == nil, "a refused section is not registered")

print("store reads ok")
