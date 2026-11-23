-- test-layout-rest.lua: the clean screen at rest. Out of combat, with no target, no cast, no drag, Layout Mode shut and health and power settled, the chosen panels ease to the rest opacity a delay after the last change; a target, combat, a cast, a health or power change or a drag bring every panel straight back, no rest begins while Layout Mode is open, and a hover brings back the hovered panel alone. Alpha only, through Layout, only where the player kept full alpha, event-driven, and switched off it touches nothing.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-3
end

local PANEL = { "actionbars.bar1", "actionbars.bar2", "unitframes.player", "databars.strip", "cooldowns.essential" }
local OTHER = { "unitframes.target", "minimap.main", "chat.main" }

-- New() -> env, K, frames: the core with a frame registered under each key, the clean screen awake.
local function New()
	local env, K = W.New({
		setup = function(e)
			e.UnitPowerType = function() return 0, "MANA" end
		end,
	})
	local frames = {}
	for i, key in ipairs(PANEL) do
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(100, 40)
		K.Layout.Register(frame, key, { anchor = "BOTTOMLEFT", x = 10 + i * 110, y = 10 }, { label = key })
		frame.child = env.CreateFrame("Button", nil, frame)
		frames[key] = frame
	end
	for i, key in ipairs(OTHER) do
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(100, 40)
		K.Layout.Register(frame, key, { anchor = "BOTTOMLEFT", x = 10 + i * 110, y = 300 }, { label = key })
		frames[key] = frame
	end
	W.Settle(env)
	return env, K, frames
end

local function Rested(env)
	env.RunTimers()
	W.Settle(env)
end

local function Listeners(env, event)
	local n = 0
	for _, frame in ipairs(env._frames) do
		if frame:IsEventRegistered(event) then
			n = n + 1
		end
	end
	return n
end

local function All(frames, keys, alpha, what)
	for _, key in ipairs(keys) do
		assert(near(frames[key]:GetAlpha(), alpha), key .. " " .. what .. ": " .. tostring(frames[key]:GetAlpha()))
	end
end

-- Defaults, the rows and the panels ---------------------------------------------------------------------------

do
	local env, K = New()
	local Rest = K.Layout.Rest
	local s = K.Store.Module("Rest")
	assert(s.enabled == true and s.alpha == 0.35, "the clean screen is on by default and rests at 35%")
	for _, panel in ipairs(Rest.ORDER) do
		assert(s.panels[panel] == true, panel .. " rests by default")
		for _, key in ipairs(Rest.PANELS[panel]) do
			assert(K.Setup.Layouts.Element(key) or key == "cooldowns.custom", key .. " is an element key")
		end
	end
	for _, key in ipairs(Rest.KEYS) do
		for _, panel in ipairs(Rest.ORDER) do
			for _, other in ipairs(Rest.PANELS[panel]) do
				assert(other ~= key, key .. " keeps only the Medallions secondary dim")
			end
		end
	end
	local rows = {}
	for _, row in ipairs(K.Options.Get("Rest")) do
		if row.key then rows[row.key] = row end
	end
	assert(rows.enabled.type == "toggle" and rows.alpha.type == "slider" and rows.alpha.min == 0.1 and rows.alpha.max == 0.9, "a master switch and a rest-opacity slider")
	for _, panel in ipairs(Rest.ORDER) do
		local row = rows["panels." .. panel]
		assert(row and row.type == "toggle" and row.disableWhen({ enabled = false }) and not row.disableWhen({ enabled = true }), panel .. " has its row, greyed while the switch is off")
	end
	assert(Rest.WAKE <= 0.12 and Rest.DELAY == 3 and Rest.FALL == 0.6, "back in 0.12 s; rests 3 s after the last change, over 0.6 s")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Rest, then every wake source ----------------------------------------------------------------------------------

do
	local env, K, frames = New()
	local Rest = K.Layout.Rest
	assert(not Rest.Quiet(), "nothing rests before the delay")
	All(frames, PANEL, 1, "is lit before the delay")
	Rested(env)
	assert(Rest.Quiet(), "the panels rest after the delay")
	All(frames, PANEL, 0.35, "rests")
	All(frames, OTHER, 1, "is not a resting panel")
	assert(env.LiveTickers() == 0, "no ticker polls while resting")

	local function Woke(what)
		assert(not Rest.Quiet(), what .. " wakes the panels")
		W.Tick(env, Rest.WAKE + 0.02)
		for _, key in ipairs(PANEL) do
			local lit = K.Layout.Calm.Level(key)
			assert(near(frames[key]:GetAlpha(), lit), key .. " is back at once after " .. what .. ": " .. tostring(frames[key]:GetAlpha()))
		end
	end

	env.SetTarget(true)
	Woke("a target")
	Rested(env)
	assert(not Rest.Quiet(), "a target keeps them up")
	env.SetTarget(false)
	Rested(env)
	assert(Rest.Quiet(), "clearing the target lets them rest again")

	env.SetCombat(true)
	Woke("combat")
	assert(Listeners(env, "UNIT_HEALTH") == 0 and Listeners(env, "UNIT_POWER_UPDATE") == 0, "in combat the clean screen listens to nothing but its end")
	env.SetCombat(false)
	assert(Listeners(env, "UNIT_HEALTH") == 1, "out of combat it listens to the player's health again")
	Rested(env)
	assert(Rest.Quiet(), "they rest a delay after combat")

	env.UnitCastingInfo = function(unit) return unit == "player" and "Hearthstone" or nil end
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	Woke("a cast")
	Rested(env)
	assert(not Rest.Quiet(), "a cast keeps them up")
	env.UnitCastingInfo = function() return nil end
	env.FireEvent("UNIT_SPELLCAST_STOP", "player")
	Rested(env)
	assert(Rest.Quiet(), "the cast's end lets them rest")

	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	Woke("an instant cast")
	Rested(env)
	assert(Rest.Quiet(), "they rest a delay after an instant cast")

	env.UnitPower, env.UnitPowerMax = function() return 50 end, function() return 100 end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
	assert(Rest.Quiet(), "a secondary power's slow decay does not wake them")
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	Woke("the main power short of full")
	Rested(env)
	assert(not Rest.Quiet(), "the main power short of full keeps them up")
	env.UnitPower = function() return 100 end
	env.FireEvent("UNIT_MAXPOWER", "player", "MANA")
	Rested(env)
	assert(Rest.Quiet(), "a full main power lets them rest")
	env.FireEvent("UNIT_HEALTH", "player")
	Woke("a change of health")
	Rested(env)
	assert(Rest.Quiet(), "settled health and power let them rest")

	env.GetCursorInfo = function() return "spell" end
	env.FireEvent("ACTIONBAR_SHOWGRID")
	Woke("a drag")
	env.GetCursorInfo = function() return nil end
	env.FireEvent("ACTIONBAR_HIDEGRID")
	Rested(env)
	assert(Rest.Quiet(), "dropping it lets them rest")

	env.SetTarget(true)
	Woke("a target")
	assert(K.Layout.Enter())
	env.SetTarget(false)
	Rested(env)
	assert(not Rest.Quiet(), "no rest begins while Layout Mode is open")
	K.Layout.Exit(true)
	env.FireEvent("UNIT_HEALTH", "player")
	Rested(env)
	assert(Rest.Quiet(), "after Layout Mode the next change lets them rest")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Hover, followers, kept opacities and the settings -----------------------------------------------------------

do
	local env, K, frames = New()
	local Rest = K.Layout.Rest
	local slab = env.CreateFrame("Frame", nil, K.Scale.Root())
	Rest.Follow("actionbars.bar1", slab)
	assert(K.Layout.Set("actionbars.bar2", "alphaIdle", 0.5))
	Rested(env)
	assert(near(slab:GetAlpha(), 0.35), "a follower rests with its element")
	assert(near(frames["actionbars.bar2"]:GetAlpha(), 0.5), "an element the player set to its own opacity keeps it")

	W.Enter(frames["actionbars.bar1"].child)
	W.Tick(env, Rest.WAKE + 0.02)
	assert(near(frames["actionbars.bar1"]:GetAlpha(), 1) and near(slab:GetAlpha(), 1), "a hover brings back the hovered panel and its follower at once")
	All(frames, { "unitframes.player", "databars.strip", "cooldowns.essential" }, 0.35, "stays at rest while another panel is hovered")
	W.Leave(frames["actionbars.bar1"].child)
	W.Enter(frames["actionbars.bar2"].child)
	env.RunTimers()
	W.Settle(env)
	assert(near(frames["actionbars.bar1"]:GetAlpha(), 1), "moving to another bar of the same panel keeps it up")
	W.Leave(frames["actionbars.bar2"].child)
	env.RunTimers()
	W.Settle(env)
	assert(Rest.Quiet() and near(frames["actionbars.bar1"]:GetAlpha(), 0.35), "leaving the panel lets it rest again")

	K.Options.Write("Rest", "alpha", 0.5)
	W.Settle(env)
	All(frames, { "actionbars.bar1", "unitframes.player" }, 0.5, "follows the rest opacity at once")
	K.Options.Write("Rest", "panels.strip", false)
	W.Settle(env)
	assert(near(frames["databars.strip"]:GetAlpha(), 1) and near(frames["unitframes.player"]:GetAlpha(), 0.5), "a panel switched off comes back; the others rest")

	K.Options.Write("Rest", "enabled", false)
	W.Settle(env)
	All(frames, { "actionbars.bar1", "unitframes.player", "databars.strip", "cooldowns.essential" }, 1, "is back when the switch is off")
	assert(near(slab:GetAlpha(), 1), "the follower is back too")
	assert(Listeners(env, "UNIT_HEALTH") == 0 and Listeners(env, "PLAYER_TARGET_CHANGED") == 0, "off, the clean screen listens to nothing")
	env.FireEvent("UNIT_HEALTH", "player")
	Rested(env)
	assert(not Rest.Quiet(), "off, it never rests")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Switched off before it first rests, it touches nothing ------------------------------------------------------

do
	local env, K, frames = New()
	K.Options.Write("Rest", "enabled", false)
	Rested(env)
	for _, key in ipairs(PANEL) do
		assert(frames[key]:GetAlpha() == 1 and not K.Layout.Element(key).alphaSet, key .. " is never written")
		assert(frames[key].child:GetScript("OnEnter") == nil, key .. " is never hooked")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("ok layout rest")
