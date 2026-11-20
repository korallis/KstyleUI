-- test-frames-text-slots.lua: optional frame text slots round-trip, paint native values and queue secure placement on old profiles.
local U = dofile("Tools/regression/unitframes_env.lua")
local G = dofile("Tools/regression/group_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local function saved(module)
	return { version = 42, profiles = { Default = { [module] = { enabled = true } } }, characters = {}, layouts = {} }
end
local function write(env, K, module, key, value)
	K.Options.Write(module, key, value)
	env.RunTimers()
	local got = K.Options.Read(module, key)
	if type(value) == "table" then assert(got.r == value.r and got.g == value.g and got.b == value.b, key)
	else assert(got == value, key) end
end
local function slots(env, K, module, prefix, frame, source, event, combat)
	local function content(text)
		local value = text:GetText()
		return env.issecretvalue(value) and env.Reveal(value) or value
	end
	local function fire(event)
		env.FireEvent(event, frame.unit or "player")
		env.RunTickers()
	end
	K.Options.Get(module)
	for i = 1, 2 do
		local key = prefix .. "extra" .. i .. "."
		assert(K.Options.Read(module, key .. "textFormat") == "" and frame["extra" .. i] == nil,
			"v0.2.8 profiles keep blank slots and create no extra regions")
		write(env, K, module, key .. "textFormat", "[hp] [pp] [level]")
		local text = assert(frame["extra" .. i], "writing a format creates its region")
		assert(text:IsShown() and content(text):find(tostring(source.health), 1, true), "slot paints its unit")
		write(env, K, module, key .. "size", 15)
		local _, size = text:GetFont()
		assert(size == 15 * K.Theme.FontScale(), "slot size applies")
		local font = K.Tokens.FontPath("AlegreyaSansRegular")
		write(env, K, module, key .. "font", font)
		assert(text:GetFont() == font, "slot font applies")
		write(env, K, module, key .. "outline", "THICKOUTLINE")
		local _, _, flags = text:GetFont()
		assert(flags == "THICKOUTLINE", "slot outline applies")
		write(env, K, module, key .. "colorMode", "custom")
		write(env, K, module, key .. "color", { r = 0.2, g = 0.4, b = 0.6 })
		local r, g, b = text:GetTextColor()
		assert(r == 0.2 and g == 0.4 and b == 0.6, "slot colour applies")
		if combat then env.SetCombat(true) end
		write(env, K, module, key .. "position", "TOPLEFT")
		write(env, K, module, key .. "x", 7)
		write(env, K, module, key .. "y", -9)
		if combat then
			assert(text:GetPoint(1) == "CENTER", "secure placement stays queued in combat")
			env.SetCombat(false); env.RunTimers()
		end
		local point, _, relative, x, y = text:GetPoint(1)
		assert(point == "TOPLEFT" and relative == "TOPLEFT" and x > 0 and y < 0, "slot placement applies")
		source.health = source.health + 37
		fire(event)
		assert(content(text):find(tostring(source.health), 1, true), "health event refreshes extra text")
		source.power = 17 + i
		fire("UNIT_POWER_UPDATE")
		assert(content(text):find(" " .. source.power .. " ", 1, true), "power events refresh extra text")
		source.level = 41 + i
		fire("UNIT_LEVEL")
		assert(content(text):sub(-2) == tostring(source.level), "level events refresh extra text")
		write(env, K, module, key .. "textFormat", "[absorb]")
		source.absorb = 317 + i
		fire("UNIT_ABSORB_AMOUNT_CHANGED")
		assert(content(text) == tostring(source.absorb), "absorb events refresh extra text")
		write(env, K, module, key .. "textFormat", "")
		assert(not text:IsShown(), "blank format disables its slot")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
do
	local env, K, ns = U.New({ saved = saved("UnitFrames") })
	for _, kind in ipairs(U.KINDS) do
		local unit = kind == "boss" and "boss1" or kind
		if not env._units[unit] then
			U.SetUnit(env, unit, { name = "Test", level = 60, health = 3000, healthMax = 4000, power = 30, powerMax = 100 })
		end
		slots(env, K, "UnitFrames", kind .. ".", ns.Frames.Get(kind).views[1], env._units[unit], "UNIT_HEALTH", true)
	end
end
collectgarbage()
do
	local env, K, ns = G.New({ saved = saved("GroupFrames") })
	G.SetRoster(env, "party", { { name = "Tank", class = "WARRIOR", health = 3000, maxHealth = 4000 } })
	assert(K.Modules.Enable("GroupFrames")); env.RunTimers()
	local frame
	ns.Unit.ForEach(function(f) if f.unit == "party1" then frame = f end end)
	slots(env, K, "GroupFrames", "party.", assert(frame), env._roster.units.party1, "UNIT_HEALTH", true)
	G.SetRoster(env, "raid", { { name = "Healer", class = "PRIEST", health = 2000, maxHealth = 4000 } })
	env.RunTimers()
	ns.Unit.ForEach(function(f) if f.unit == "raid1" then frame = f end end)
	slots(env, K, "GroupFrames", "raid.", assert(frame), env._roster.units.raid1, "UNIT_HEALTH", true)
end
collectgarbage()
do
	local env, K, ns = N.New({ saved = saved("Nameplates") })
	N.Add(env, "nameplate1")
	slots(env, K, "Nameplates", "", ns.Plates.Get("nameplate1"), env._units.nameplate1, "UNIT_HEALTH")
end
print("frame text slots ok: old profiles, lazy regions, font/colour/format/placement, events and combat queue")
