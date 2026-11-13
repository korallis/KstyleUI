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
	assert(K.HudStyle.Saved() == "frames", "a new profile's HUD style is Frames")
	assert(K.HudStyle.Current() == "frames", "the applied HUD style is Frames")
	assert(ns.Orbs.Get("health") == nil and ns.Orbs.Get("power") == nil, "Frames builds no orb")
	assert(player(ns).active == true, "the player frame runs under Frames")
	assert(K.Layout.Live("unitframes.player"), "the player frame's element is live under Frames")
	local row = K.Options.Row("HudStyle", "style")
	assert(row and row.type == "pictures", "Options shows the HUD styles as pictures")
	local values = {}
	for _, option in ipairs(row.options) do
		values[#values + 1] = option.value
	end
	assert(table.concat(values, ",") == "frames,orbs", "the choices are Frames and Orbs, got " .. table.concat(values, ","))
end

-- The migration: saved data from version 20 gets version 21 and every existing profile reads Frames, the default, with
-- nothing written into it; a saved Orbs stays, and a value no build knows is cleared, so the profile falls back to Frames.
do
	local env, K = new({
		version = 20,
		profiles = {
			Default = { UnitFrames = { enabled = true } },
			Raid = { UnitFrames = { enabled = true }, HudStyle = { style = "orbs" } },
			Odd = { HudStyle = { style = "bars" } },
		},
		characters = {},
	})
	noErrors(env, K, "migrated boot")
	assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.Store.DB_VERSION >= 21, "the saved data is upgraded to the current version, past the HUD style migration")
	assert(env.KstyleUIDB.profiles.Raid.HudStyle.style == "orbs", "a profile that chose Orbs keeps it")
	K.Store.SetProfile("Odd")
	assert(K.HudStyle.Saved() == "frames", "an unknown style reads Frames")
	K.Store.SetProfile("Raid")
	assert(K.HudStyle.Current() == "orbs", "a profile that chose Orbs opens on Orbs")
	K.Store.SetProfile("Default")
	env.KstyleUIDB.profiles.Default.HudStyle = nil
	CoreEnv.Logout(env)
	assert(env.KstyleUIDB.profiles.Default.HudStyle == nil or env.KstyleUIDB.profiles.Default.HudStyle.style == nil, "Frames is not written into a profile")
	assert(K.HudStyle.Saved() == "frames", "the active profile reads Frames")
end

-- The live switch out of combat: the orbs show beside action bar 1, the player frame and its element step out, and the
-- orbs fill from the player's secret health and power through the engine's setters only.
local env, K, ns = new()
local Orbs = ns.Orbs
local printed = #env._printed
K.Options.Write("HudStyle", "style", "orbs")
env.RunTimers()
noErrors(env, K, "switch to Orbs")
assert(K.HudStyle.Current() == "orbs", "the switch applies at once out of combat")
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

-- The look (KSTY-60 item 5): the glass behind the liquid takes a dark tint of the orb's own colour, the liquid a
-- curved lit surface tinted from it with its white line and shadow over it, and the mana orb the mock-up's blue.
do
	local function rgb(region, method)
		local call = W.LastCall(region, method)
		return call[1], call[2], call[3]
	end
	for _, orb in ipairs({ health, power }) do
		local lr, lg, lb = rgb(orb.bar, "SetStatusBarColor")
		local br, bg, bb = rgb(orb.back, "SetVertexColor")
		assert(br < 0.25 and bg < 0.25 and bb < 0.25, orb.kind .. ": the empty glass stays dark")
		assert((lr > lb) == (br > bb) and (lr > lg) == (br > bg), orb.kind .. ": the empty glass is tinted with the liquid's own hue, not black")
		local sr, sg, sb = rgb(orb.surface, "SetVertexColor")
		assert(sr >= lr and sg >= lg and sb >= lb and sr + sg + sb > lr + lg + lb, orb.kind .. ": the surface is a lighter tint of the liquid")
		assert(orb.surface:GetTexture() == K.Tokens.Texture("orbSurface") and orb.surfaceLight:GetTexture() == K.Tokens.Texture("orbSurfaceLight"), orb.kind .. ": the surface ellipse and its light")
		local size, hole = W.LastCall(orb.surface, "SetSize"), W.LastCall(orb.bar, "SetSize")
		assert(math.abs(size[2] - hole[2] * 0.25) < 1 and size[1] == hole[1], orb.kind .. ": the surface's texture spans the opening and a quarter of it tall, its ellipse 11% of the opening, not a line")
		local point = W.LastCall(orb.surfaceLight, "SetPoint")
		assert(point[2] == orb.bar:GetStatusBarTexture() and point[3] == "TOP" and orb.surfaceLight._masks[1] == orb.bar.mask, orb.kind .. ": the surface's light rides the fill's top inside the mask")
	end
	local r, g, b = rgb(power.bar, "SetStatusBarColor")
	assert(b > r and b > g and g > r * 1.5, "the mana orb is the mock-up's blue, not the bar's violet")
	local band, recentBand = W.LastCall(health.loss, "SetStatusBarColor"), W.LastCall(health.recent, "SetStatusBarColor")
	assert(band[4] == 1 and band[1] > 0.35 and band[2] > 0.25 and band[3] > 0.2, "the loss band is a pale glaze, opaque")
	for i = 1, 4 do
		assert(band[i] == recentBand[i], "the two loss bands share one opaque colour, so they overlap without a seam")
	end
	local capPoint = W.LastCall(health.lossCap, "SetPoint")
	assert(health.lossCap:GetTexture() == K.Tokens.Texture("orbSurface") and capPoint[1] == "CENTER" and capPoint[2] == health.loss:GetStatusBarTexture() and capPoint[3] == "TOP", "a pale cap rides the loss band's top")
	assert(W.LastCall(health.lossCap, "SetSize")[2] < W.LastCall(health.surface, "SetSize")[2], "the cap is flatter than the surface, so a band at the health hides under it")
end

-- A hit: the fill snaps, the pale band behind it holds at the health before the hit, then eases to the new value,
-- and nothing reads the secret health.
local function finish(group)
	group:Stop()
	group:GetScript("OnFinished")(group)
end
env._restricted = true
local beforeHit = unit.health
unit.health = 1200
env.FireEvent("UNIT_HEALTH", "player")
noErrors(env, K, "a hit while restricted")
assert(W.LastCall(health.bar, "SetValue").n == 1, "the fill snaps to the hit")
local held = W.LastCall(health.loss, "SetValue")
assert(env.Reveal(held[1]) == beforeHit and held.n == 1, "the loss band holds the health before the hit, so the lost part shows pale")
assert(health.hold:IsPlaying(), "the hold plays")
unit.health = 1100
env.FireEvent("UNIT_HEALTH", "player")
assert(env.Reveal(W.LastCall(health.loss, "SetValue")[1]) == beforeHit, "a second hit inside the hold keeps the band at the health before the burst")
assert(env.Reveal(W.LastCall(health.recent, "SetValue")[1]) == 1200, "the second band holds the health just before the last hit")
finish(health.hold)
local eased = W.LastCall(health.loss, "SetValue")
assert(eased[2] == EASE, "the loss band eases with the engine's ExponentialEaseOut")
assert(env.Reveal(eased[1]) == 1100, "after the hold the loss band eases to the new health")
assert(env.Reveal(W.LastCall(health.recent, "SetValue")[1]) == 1100, "and the second band with it")
unit.health = 1500
env.FireEvent("UNIT_HEALTH", "player")
finish(health.hold)
unit.health = 1300
env.FireEvent("UNIT_HEALTH", "player")
assert(env.Reveal(W.LastCall(health.recent, "SetValue")[1]) == 1500, "a hit after a heal shows on the second band")
finish(health.hold)
unit.healthMax = unit.healthMax + 100
env.FireEvent("UNIT_MAXHEALTH", "player")
assert(not health.hold:IsPlaying() and env.Reveal(W.LastCall(health.loss, "SetValue")[1]) == unit.health, "a new maximum snaps the band to the health")
unit.health = 1200
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
K.Options.Write("HudStyle", "style", "frames")
K.Options.Write("HudStyle", "style", "orbs")
K.Options.Write("HudStyle", "style", "frames")
noErrors(env, K, "a choice in combat")
assert(K.HudStyle.Saved() == "frames", "the choice is saved in combat")
assert(K.HudStyle.Current() == "orbs" and health:IsShown(), "the orbs stay until combat ends")
assert(player(ns).active == false, "the player frame waits for combat to end")
assert(CoreEnv.Count(env._printed, "KstyleUI: " .. K.L["Your HUD style changes when combat ends."]) == 1, "one line says the switch waits")
env.SetCombat(false)
env.RunTimers()
noErrors(env, K, "combat ends")
assert(K.HudStyle.Current() == "frames", "the switch lands when combat ends")
assert(not health:IsShown() and not power:IsShown(), "the orbs hide under Frames")
assert(player(ns).active == true and player(ns).views[1].button:IsShown(), "the player frame comes back")
assert(K.Layout.Live("unitframes.player"), "the player frame's element is live again")

-- Choosing Orbs in combat leaves the secure player frame up until combat ends.
env.SetCombat(true)
K.Options.Write("HudStyle", "style", "orbs")
noErrors(env, K, "Orbs chosen in combat")
assert(K.HudStyle.Current() == "frames" and not health:IsShown(), "the orbs wait for combat to end")
assert(player(ns).active == true and player(ns).views[1].button:IsShown(), "the secure player frame stays shown in combat")
env.SetCombat(false)
env.RunTimers()
assert(K.HudStyle.Current() == "orbs" and health:IsShown() and player(ns).active == false, "Orbs lands when combat ends")
K.Options.Write("HudStyle", "style", "frames")

-- A bar moved to an edge keeps both orbs on screen.
do
	local saved = K.Store.Layout()
	local before = saved["actionbars.bar1"]
	saved["actionbars.bar1"] = { anchor = "BOTTOMLEFT", x = 0, y = 0 }
	local hx, px, y = Orbs.Centres()
	local width, height = K.Layout.RootSize()
	assert(hx >= 102 and px <= width - 102 and y >= 102 and y <= height - 102, "the orbs clamp inside the screen")
	saved["actionbars.bar1"] = before
end

-- Back to Orbs and to Frames in one session leaves no orb events behind.
K.Options.Write("HudStyle", "style", "orbs")
K.Options.Write("HudStyle", "style", "frames")
env.FireEvent("UNIT_HEALTH", "player")
noErrors(env, K, "events after switching back")
assert(not health:IsShown(), "a health event under Frames does not show the orbs")

-- A profile switch carries its own style.
K.Store.CopyProfile("Default", "Orbs")
K.Store.SetProfile("Orbs")
K.Options.Write("HudStyle", "style", "orbs")
K.Store.SetProfile("Default")
env.RunTimers()
assert(K.HudStyle.Current() == "frames" and not health:IsShown(), "switching to a Frames profile restores Frames")
K.Store.SetProfile("Orbs")
env.RunTimers()
assert(K.HudStyle.Current() == "orbs" and health:IsShown() and player(ns).active == false, "switching to an Orbs profile shows the orbs")
noErrors(env, K, "profile switches")

-- An imported profile string carrying a style no build knows is refused, like any other choice row's unknown value.
do
	local ok = K.Store.Import(CoreEnv.CraftLua({ kind = "KstyleUI profile", version = K.Store.DB_VERSION, name = "Odd", settings = { HudStyle = { style = "bars" } }, layout = {} }))
	assert(not ok, "an unknown HUD style in a profile string is refused")
	local good = K.Store.Import(CoreEnv.CraftLua({ kind = "KstyleUI profile", version = K.Store.DB_VERSION, name = "Good", settings = { HudStyle = { style = "orbs" } }, layout = {} }))
	assert(good, "a known HUD style imports")
	K.Store.SetProfile("Orbs")
	env.RunTimers()
end

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
K.Options.Write("HudStyle", "style", "frames")
assert(prompts == 1, "a failed switch offers a reload")
K.Callbacks.Unregister("HudStyleChanged", "test")
K.Widgets.ReloadPrompt = prompt

print("test-unitframes-orbs: ok")
