-- test-cooldowns-viewer-off.lua: with Blizzard's Cooldown Manager switched off (cooldownViewerEnabled 0), KstyleUI draws no cooldown, buff or bar icon and leaves Blizzard's hidden viewers alone, at login, on CVAR_UPDATE and on VARIABLES_LOADED.
local C = dofile("Tools/regression/cooldowns_env.lua")

local CVAR = "cooldownViewerEnabled"
local GROUPS = { "essential", "utility", "buffs", "bars", "custom" }
local FORBIDDEN = { Show = true, SetShown = true, SetParent = true }

local on

-- Blizzard's CooldownViewerMixin:UpdateShownState hides each viewer while the CVar is off.
local function Blizzard(env)
	for _, viewer in pairs(env._viewers) do
		viewer:SetShown(on)
	end
end

local function New(path, enabled)
	on = enabled
	local env, K, ns = C.New({ setup = function(game)
		C.Game(game)
		game.C_CVar = { GetCVarBool = function(name) if name == CVAR then return on end end }
		Blizzard(game)
	end })
	K.Options.Write("Cooldowns", "attached", false)
	K.Options.Write("Cooldowns", "path", path)
	return env, K, ns
end

local function Drawn(ns)
	local out = {}
	for _, group in ipairs(GROUPS) do
		local row = ns.Mirror.Row(group)
		if row and row.holder:IsShown() and (row.count or 0) > 0 then
			out[#out + 1] = group
		end
	end
	return table.concat(out, ",")
end

local function Marks(env)
	local marks = {}
	for name, viewer in pairs(env._viewers) do
		marks[name] = #viewer._calls
	end
	return marks
end

local function Touched(env, marks, alpha)
	for name, viewer in pairs(env._viewers) do
		assert(not viewer:IsShown(), name .. " must stay hidden while the Cooldown Manager is off")
		for i = marks[name] + 1, #viewer._calls do
			local method = viewer._calls[i].method
			assert(not FORBIDDEN[method] and (alpha or method ~= "SetAlpha"), name .. " got " .. method .. " while the Cooldown Manager is off")
		end
	end
end

local function Flip(env, value)
	on = value
	Blizzard(env)
	local marks = Marks(env)
	env.FireEvent("CVAR_UPDATE", CVAR, value and "1" or "0")
	env.RunTimers()
	return marks
end

for _, path in ipairs({ "auto", "mirror", "reskin" }) do
	-- At login with the CVar off: nothing drawn, Blizzard's viewers untouched.
	do
		local env, K, ns = New(path, false)
		local marks = Marks(env)
		C.Enable(env, K)
		env.RunTimers()
		assert(Drawn(ns) == "", path .. ": the Cooldown Manager is off, yet KstyleUI draws " .. Drawn(ns))
		Touched(env, marks)
		assert(#env._errors == 0, path .. ": starting with the Cooldown Manager off raised an error")
	end

	-- Live: on draws as before, off clears it without a reload, on again brings it back.
	do
		local env, K, ns = New(path, true)
		C.Enable(env, K)
		env.RunTimers()
		local before = Drawn(ns)
		assert(path == "reskin" or before:find("essential", 1, true), path .. ": the mirror must draw the essential row while the Cooldown Manager is on")
		local marks = Flip(env, false)
		assert(Drawn(ns) == "", path .. ": switching the Cooldown Manager off must clear KstyleUI's rows live, yet it draws " .. Drawn(ns))
		Touched(env, marks, true)
		Flip(env, true)
		assert(Drawn(ns) == before, path .. ": switching the Cooldown Manager back on must draw " .. before .. ", got " .. Drawn(ns))
		K.Modules.Disable("Cooldowns")
		assert(Drawn(ns) == "", path .. ": with KstyleUI's Cooldowns module off nothing is drawn")
		assert(#env._errors == 0, path .. ": switching the Cooldown Manager live raised an error")
	end
end

-- The character's CVars load after login: VARIABLES_LOADED with the CVar off clears the rows the default value drew.
do
	local env, K, ns = New("auto", true)
	C.Enable(env, K)
	env.RunTimers()
	assert(Drawn(ns) ~= "", "the mirror draws while the Cooldown Manager reads on")
	on = false
	Blizzard(env)
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
	assert(Drawn(ns) == "", "VARIABLES_LOADED with the Cooldown Manager off must clear KstyleUI's rows, yet it draws " .. Drawn(ns))
end

-- A live switch-off hides the cleared rows' Layout movers, as at a cold login, and switching back on restores them.
do
	local env, K = New("auto", true)
	C.Enable(env, K)
	env.RunTimers()
	Flip(env, false)
	assert(K.Layout.Enter())
	for _, group in ipairs({ "essential", "utility" }) do
		local plate = K.Layout.Mode.Plate("cooldowns." .. group)
		assert(not (plate and plate:IsVisible()), group .. ": the Cooldown Manager is off, yet Layout Mode still offers its mover")
	end
	Flip(env, true)
	for _, group in ipairs({ "essential", "utility" }) do
		local plate = K.Layout.Mode.Plate("cooldowns." .. group)
		assert(plate and plate:IsVisible(), group .. ": the Cooldown Manager is back on, so Layout Mode must offer its mover again")
	end
	K.Layout.Exit()
end

-- A deliberate live switch-off is not the login case: no hint, and the one-time account flag stays for the next login.
for _, path in ipairs({ "auto", "reskin" }) do
	local env, K = New(path, true)
	C.Enable(env, K)
	env.RunTimers()
	Flip(env, false)
	assert(K.Store.Account().cooldownViewerHinted == nil, path .. ": switching the Cooldown Manager off live used up the one-time login hint")
	for _, line in ipairs(env._printed) do
		assert(not line:find("Turn on the Cooldown Manager", 1, true), path .. ": switching the Cooldown Manager off live printed " .. line)
	end
end

print("cooldowns viewer off ok")
