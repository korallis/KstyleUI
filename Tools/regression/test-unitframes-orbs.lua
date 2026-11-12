-- test-unitframes-orbs.lua: the HUD style setting, its migration, the live and combat-queued switch, and the Orbs style's health and resource orbs, which read secrets only through the engine's setters.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local CoreEnv = W.CoreEnv

local EASE = 1

local function withEnum(env)
	env.Enum = env.Enum or {}
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = EASE }
end

local function new(saved)
	return U.New({ saved = saved, setup = withEnum })
end

local function noErrors(env, K, where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b)
	return math.abs(a - b) < 0.01
end

-- Every frame under a root, the root included.
local function each(frame, fn)
	fn(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		each(child, fn)
	end
end

local function player(ns)
	return ns.Frames.Get("player")
end

-- The default: Frames for a new profile, nothing of the Orbs style built, the player frame live.
do
	local env, K, ns = new()
	noErrors(env, K, "boot")
	assert(K.Appearance.Get("hudStyle") == "frames", "a new profile's HUD style is Frames")
	assert(K.Appearance.HudStyle() == "frames", "the applied HUD style is Frames")
	assert(ns.Orbs.Get("health") == nil and ns.Orbs.Get("power") == nil, "Frames builds no orb")
	assert(player(ns).active == true, "the player frame runs under Frames")
	assert(K.Layout.Live("unitframes.player"), "the player frame's element is live under Frames")
	local row = K.Options.Row("Appearance", "hudStyle")
	assert(row and row.type == "dropdown", "Options shows a HUD style dropdown")
	local values = {}
	for _, option in ipairs(row.options) do
		values[#values + 1] = option.value
	end
	assert(table.concat(values, ",") == "frames,orbs", "the choices are Frames and Orbs, got " .. table.concat(values, ","))
	assert(K.Options.Get("Appearance")[2] == row, "the HUD style is the first setting on the General page")
end

-- The migration: saved data from version 20 gets version 21, every existing profile reads Frames, and a profile that
-- already chose Orbs keeps it. An unknown value falls back to Frames without an error.
do
	local env, K = new({
		version = 20,
		profiles = {
			Default = { UnitFrames = { enabled = true } },
			Raid = { UnitFrames = { enabled = true }, Appearance = { hudStyle = "orbs" } },
			Odd = { Appearance = { hudStyle = "bars" } },
		},
		characters = {},
	})
	noErrors(env, K, "migrated boot")
	assert(env.KstyleUIDB.version == 21 and K.Store.DB_VERSION == 21, "the saved data is upgraded to version 21")
	assert(env.KstyleUIDB.profiles.Default.Appearance.hudStyle == "frames", "an existing profile is pinned to Frames")
	assert(env.KstyleUIDB.profiles.Raid.Appearance.hudStyle == "orbs", "a profile that chose Orbs keeps it")
	assert(env.KstyleUIDB.profiles.Odd.Appearance.hudStyle == "frames", "an unknown style becomes Frames")
	assert(K.Appearance.Get("hudStyle") == "frames", "the active profile reads Frames")
end

-- The live switch out of combat: the orbs show beside action bar 1, the player frame and its element step out, and the
-- orbs fill from the player's secret health and power through the engine's setters only.
local env, K, ns = new()
local Orbs = ns.Orbs
local printed = #env._printed
K.Options.Write("Appearance", "hudStyle", "orbs")
env.RunTimers()
noErrors(env, K, "switch to Orbs")
assert(K.Appearance.HudStyle() == "orbs", "the switch applies at once out of combat")
assert(#env._printed == printed, "an out-of-combat switch prints nothing")
local health, power = Orbs.Get("health"), Orbs.Get("power")
assert(health and power and health:IsShown() and power:IsShown(), "both orbs show under Orbs")
assert(player(ns).active == false and not player(ns).views[1].button:IsShown(), "the player frame hides under Orbs")
assert(not K.Layout.Live("unitframes.player"), "the player frame's element steps out of Layout under Orbs")
assert(ns.CastBars.ElementLive("player"), "the player's cast bar element stays")

for _, orb in ipairs({ health, power }) do
	local bar = orb.bar
	assert(bar:GetObjectType() == "StatusBar", orb.kind .. ": the liquid is a status bar")
	assert(W.LastCall(bar, "SetOrientation")[1] == "VERTICAL", orb.kind .. ": the liquid fills upwards")
	local fill = bar:GetStatusBarTexture()
	assert(fill._masks and fill._masks[1] == bar.mask, orb.kind .. ": the round mask cuts the liquid")
	assert(orb.surface._masks and orb.surface._masks[1] == bar.mask, orb.kind .. ": the mask cuts the surface line")
	local point = W.LastCall(orb.surface, "SetPoint")
	assert(point[2] == fill and point[3] == "TOP", orb.kind .. ": the surface line rides the fill's top edge")
	each(orb, function(frame)
		assert(frame:GetScript("OnUpdate") == nil, orb.kind .. ": no orb frame runs OnUpdate")
	end)
end

local unit = env._units.player
do
	local value, low, high = U.Bar(env, health.bar)
	assert(value == unit.health and low == 0 and high == unit.healthMax, "the health orb holds the player's health")
	value, low, high = U.Bar(env, health.loss)
	assert(value == unit.health and low == 0 and high == unit.healthMax, "the loss band starts at the player's health")
	value, low, high = U.Bar(env, power.bar)
	assert(value == unit.power and low == 0 and high == unit.powerMax, "the resource orb holds the player's power")
end
assert(U.Shown(env, health.value):find(tostring(unit.health), 1, true), "the health orb shows current and max, got " .. U.Shown(env, health.value))
assert(U.Shown(env, power.value):find("%", 1, true), "the resource orb shows a percentage, got " .. U.Shown(env, power.value))

-- Placement: the orbs flank action bar 1 at equal distance and sit above the screen's foot.
do
	local root = K.Scale.Root()
	local grid = K.Setup.Layouts.Grid("actionbars.bar1")
	local width, height = 12 * grid.size + 11 * grid.spacing, grid.size
	local left, bottom = K.Setup.Layouts.Rect({ width = width, height = height }, K.Setup.Layouts.Default("actionbars.bar1"), root:GetWidth(), root:GetHeight())
	local hx, px, y = Orbs.Centres()
	assert(hx < left and px > left + width, "the health orb is left of the bar and the resource orb right of it")
	assert(near(left - hx, px - (left + width)), "the orbs stand the same distance from the bar")
	assert(y - 100 >= 0 and y > bottom, "the orbs clear the foot of the screen")
end

-- A hit: the fill snaps, the pale band behind it eases to the new value, and nothing reads the secret health.
env._restricted = true
unit.health = 1200
env.FireEvent("UNIT_HEALTH", "player")
noErrors(env, K, "a hit while restricted")
assert(W.LastCall(health.bar, "SetValue").n == 1, "the fill snaps to the hit")
local eased = W.LastCall(health.loss, "SetValue")
assert(eased[2] == EASE, "the loss band eases with the engine's ExponentialEaseOut")
assert(env.Reveal(eased[1]) == 1200, "the loss band eases to the new health")
unit.power = 900
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
noErrors(env, K, "power while restricted")
assert(W.LastCall(power.bar, "SetValue")[2] == EASE, "the resource orb eases")
env._restricted = false

-- Motion Off: the band and the resource snap.
K.Options.Write("Appearance", "motion", "off")
env.FireEvent("UNIT_HEALTH", "player")
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
assert(W.LastCall(health.loss, "SetValue").n == 1 and W.LastCall(power.bar, "SetValue").n == 1, "Motion Off snaps the band and the resource")
K.Options.Write("Appearance", "motion", "full")

-- In combat the choice is saved at once but the switch waits for combat to end, with one line to say so.
env.SetCombat(true)
K.Options.Write("Appearance", "hudStyle", "frames")
K.Options.Write("Appearance", "hudStyle", "orbs")
K.Options.Write("Appearance", "hudStyle", "frames")
noErrors(env, K, "a choice in combat")
assert(K.Appearance.Get("hudStyle") == "frames", "the choice is saved in combat")
assert(K.Appearance.HudStyle() == "orbs" and health:IsShown(), "the orbs stay until combat ends")
assert(player(ns).active == false, "the player frame waits for combat to end")
assert(CoreEnv.Count(env._printed, "KstyleUI: " .. K.L["Your HUD style changes when combat ends."]) == 1, "one line says the switch waits")
env.SetCombat(false)
env.RunTimers()
noErrors(env, K, "combat ends")
assert(K.Appearance.HudStyle() == "frames", "the switch lands when combat ends")
assert(not health:IsShown() and not power:IsShown(), "the orbs hide under Frames")
assert(player(ns).active == true and player(ns).views[1].button:IsShown(), "the player frame comes back")
assert(K.Layout.Live("unitframes.player"), "the player frame's element is live again")

-- Back to Orbs and to Frames in one session leaves no orb events behind.
K.Options.Write("Appearance", "hudStyle", "orbs")
K.Options.Write("Appearance", "hudStyle", "frames")
env.FireEvent("UNIT_HEALTH", "player")
noErrors(env, K, "events after switching back")
assert(not health:IsShown(), "a health event under Frames does not show the orbs")

-- A profile switch carries its own style.
K.Store.CopyProfile("Default", "Orbs")
K.Store.SetProfile("Orbs")
K.Options.Write("Appearance", "hudStyle", "orbs")
K.Store.SetProfile("Default")
env.RunTimers()
assert(K.Appearance.HudStyle() == "frames" and not health:IsShown(), "switching to a Frames profile restores Frames")
K.Store.SetProfile("Orbs")
env.RunTimers()
assert(K.Appearance.HudStyle() == "orbs" and health:IsShown() and player(ns).active == false, "switching to an Orbs profile shows the orbs")
noErrors(env, K, "profile switches")

-- A switch that raises offers a reload instead of leaving half a HUD.
local prompts = 0
local prompt = K.Widgets.ReloadPrompt
K.Widgets.ReloadPrompt = function(text)
	prompts = prompts + 1
	assert(text == K.L["Your HUD style finishes changing when you reload."], "the prompt says why")
end
K.Callbacks.Register("HudStyleChanged", "test", function()
	error("a module could not switch")
end)
K.Options.Write("Appearance", "hudStyle", "frames")
assert(prompts == 1, "a failed switch offers a reload")
K.Callbacks.Unregister("HudStyleChanged", "test")
K.Widgets.ReloadPrompt = prompt

print("test-unitframes-orbs: ok")
