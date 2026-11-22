-- test-unitframes-parity-r3b-review.lua: the PR #629 review's probe as checks: a saved class crop survives the upgrade and shows on the Frames portrait, the PvP timer starts on PVP_TIMER_UPDATE, Medallions keeps explicit threat places and Frames its own, enlarged icons keep their gap, reaction swatches reach power and skip custom bars, the non-tank glow needs a known role in a dungeon or raid, a reload target plays the lost sound, threat hides on restriction without repeat writes, swords follow a palette change, and the preview matches live.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b, tolerance)
	return math.abs(a - b) < (tolerance or 1e-6)
end

local unit = { name = "Wolf", level = 60, health = 40, healthMax = 100, power = 10, powerMax = 100, reaction = 2, canAttack = true, classification = "elite" }
local saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, targetSounds = true, player = { portraitStyle = "class", portraitZoom = 0.2 } } } }, characters = {} }
local env, K, ns = U.New({ saved = saved, setup = function(e)
	e._units.target = unit
	e._kind = "pvp"
	e.IsPVPTimerRunning = function() return e._timer == true end
	e.GetPVPTimer = function() return 61000 end
	e.UnitDetailedThreatSituation = function() return false, 2, e._threat or 64, 80, 100 end
	e.IsInInstance = function() return e._kind ~= "none", e._kind end
	e.IsTargetLoose = function() return false end
	e.PlaySound = function() e._soundCount = (e._soundCount or 0) + 1 end
	e.SOUNDKIT = { INTERFACE_SOUND_LOST_TARGET_UNIT = 684 }
	e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
end })
local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end
local function clean(e, k)
	assert(#e._errors == 0 and k.ErrorCount() == 0, tostring(e._errors[1]))
end
local p, t = ns.Frames.Get("player").views[1], ns.Frames.Get("target").views[1]

-- 1. A class portrait zoom saved before Class icon zoom survives the upgrade, and a new profile starts whole.
assert(ns.Settings.Value("player", "classZoom") == 0.2, "the upgrade copies the saved portrait zoom into class icon zoom")
local fresh = { version = U.DbVersion(), profiles = { Default = { UnitFrames = { enabled = true, player = { portraitStyle = "class", portraitZoom = 0.2 } } } }, characters = {} }
local ne, NK, nn = U.New({ saved = fresh, setup = function(e)
	e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
end })
assert(nn.Settings.Value("player", "classZoom") == 0, "a profile saved after the upgrade keeps the default whole class icon")
clean(ne, NK)

-- 1, Frames: the saved class crop shows on the portrait; an explicit 0 then shows all of it, and Portrait zoom no longer crops it.
do
	local frames = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, player = { portraitStyle = "class", portraitZoom = 0.2 } }, HudStyle = { style = "frames" } } }, characters = {} }
	local fe, FK, fns = U.New({ saved = frames, setup = function(e)
		e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
	end })
	local portrait = fns.Frames.Get("player").views[1].portrait
	local coords = W.LastCall(portrait, "SetTexCoord")
	assert(near(coords[1], 0.12) and near(coords[2], 0.28) and near(coords[3], 0.52) and near(coords[4], 0.68), "a saved class portrait keeps its crop: " .. table.concat(coords, ","))
	FK.Options.Write("UnitFrames", "player.classZoom", 0)
	fe.RunTimers()
	coords = W.LastCall(portrait, "SetTexCoord")
	assert(coords[1] == 0 and coords[2] == 1 and coords[3] == 0 and coords[4] == 1, "an explicit 0 shows the whole class icon")
	FK.Options.Write("UnitFrames", "player.portraitZoom", 0.3)
	fe.RunTimers()
	assert(W.LastCall(portrait, "SetTexCoord")[1] == 0, "Portrait zoom no longer crops the class icon")
	clean(fe, FK)
end

-- 8. A target held across the reload plays the lost sound when it is cleared.
U.SetUnit(env, "target", nil)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(env._soundCount == 1, "clearing the reload's target plays the lost sound once: " .. tostring(env._soundCount))
U.SetUnit(env, "target", unit)
env.FireEvent("PLAYER_TARGET_CHANGED")

-- 2. The PvP timer starts on the game's own PVP_TIMER_UPDATE, and its offsets move it.
env._units.player.pvp, env._units.player.faction = true, "Alliance"
write("player.pvpTimer", true)
env.FireEvent("PLAYER_FLAGS_CHANGED", "player")
assert(not (p.pvpTimer and p.pvpTimer:IsShown()), "no countdown, no timer")
env._timer = true
env.FireEvent("PVP_TIMER_UPDATE", "player")
assert(p.pvpTimer and p.pvpTimer:IsShown() and U.Shown(env, p.pvpTimer) == "1:01", "PVP_TIMER_UPDATE starts the timer")
local spot = W.LastCall(p.pvpTimer, "SetPoint")
write("player.pvpTimerX", 10)
write("player.pvpTimerY", -6)
local moved = W.LastCall(p.pvpTimer, "SetPoint")
assert(moved[4] > spot[4] and moved[5] < spot[5], "the timer's offsets move it right and down")
write("player.pvpTimerX", 0)
write("player.pvpTimerY", 0)
moved = W.LastCall(p.pvpTimer, "SetPoint")
assert(moved[4] == spot[4] and moved[5] == spot[5], "0 puts the timer back")

-- 11a. Other faction only hides the player's badge, so the preview shows no timer either.
write("player.pvpEnemyOnly", true)
write("edit", "player")
local pane = ns.Preview.Build(env.UIParent)
pane:Refresh()
local sampleTimer = pane.views.player.pvpTimer
assert(not p.pvpTimer:IsShown() and not (sampleTimer and sampleTimer:IsShown()),"live and preview both hide the timer with Other faction only")
write("player.pvpEnemyOnly", false)

-- 6. The non-tank glow needs a known damage or healer role in a dungeon or raid.
env._units.player.role, env._units.player.threat = "DAMAGER", 3
write("player.threatNonTank", true)
assert(not p.glowFrame:IsShown(), "a battleground gives no non-tank glow")
env._kind = "party"
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(p.glowFrame:IsShown(), "a damage dealer with threat in a dungeon glows")
local roles = env.UnitGroupRolesAssigned
env.UnitGroupRolesAssigned = function() return env.Secret("TANK") end
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(not p.glowFrame:IsShown(), "a restricted role gives no non-tank glow")
env.UnitGroupRolesAssigned = roles
U.SetUnit(env, "target", unit)
env.FireEvent("PLAYER_TARGET_CHANGED")
write("target.elite", true)
write("target.eliteInstances", false)
assert(not t.extraIcon:IsShown(), "Elite icon in instances off hides the badge in a dungeon")
env._kind = "pvp"
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(t.extraIcon:IsShown(), "a battleground keeps the elite badge")
write("target.elite", false)
env._kind = "none"
env.FireEvent("PLAYER_ENTERING_WORLD")
write("player.threatNonTank", false)
env._units.player.threat = nil

-- 4. An enlarged icon pushes its neighbours out by the usual gap.
local function extent(icon)
	local x, w = W.LastCall(icon, "SetPoint")[4], W.LastCall(icon, "SetSize")[1]
	return x - w / 2, x + w / 2
end
local function gap(a, b)
	local l1, r1 = extent(a)
	local l2, r2 = extent(b)
	return math.max(l1, l2) - math.min(r1, r2)
end
for _, wh in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local e, k, n = U.New({ width = wh[1], height = wh[2], size = "auto", fit = true })
	e._units.player.leader, e._units.player.role = true, "TANK"
	k.Options.Write("UnitFrames", "player.leaderSize", 32)
	e.RunTimers()
	e.FireEvent("GROUP_ROSTER_UPDATE")
	local view = n.Frames.Get("player").views[1]
	local icons = view.icons
	assert(icons.leader:IsShown() and icons.role:IsShown(), "both icons show")
	local wide, usual = gap(icons.leader, icons.role), gap(icons.role, icons.pvp)
	assert(usual > 0 and wide >= usual / 2 - 1e-6 and wide <= usual + k.Widgets.Border(view.parent) / 2 + 1e-6, wh[1] .. "x" .. wh[2] .. ": the crown stays clear of the role icon by the usual gap, give or take half a pixel: " .. wide .. " against " .. usual)
	clean(e, k)
end

-- 5 and 9c. Reaction swatches reach reaction power, skip custom health, and the tapped state is read once.
write("target.power", true)
write("target.powerColor", "reaction")
write("target.healthColor", "reaction")
write("reactionColors", true)
write("hostileColor", { r = 0.9, g = 0.1, b = 0.2 })
write("neutralColor", { r = 0.2, g = 0.3, b = 0.4 })
write("tappedColor", { r = 0.7, g = 0.5, b = 0.3 })
assert(near(t.healthR, 0.9) and near(t.powerR, 0.9), "hostile bars take the hostile swatch")
unit.reaction = 4
env.FireEvent("UNIT_FACTION", "target")
assert(near(t.healthR, 0.2) and near(t.powerR, 0.2), "UNIT_FACTION turns both bars neutral: power " .. tostring(t.powerR))
unit.tapDenied = true
env.FireEvent("UNIT_FLAGS", "target")
assert(near(t.healthR, 0.7) and near(t.powerR, 0.7), "a tapped unit's reaction bars take the tapped swatch: power " .. tostring(t.powerR))
write("target.healthColor", "custom")
local grey = K.Tokens.Color("textDisabled")
assert(near(t.healthR, grey) and near(t.powerR, 0.7), "a custom health bar keeps the original tapped grey: " .. tostring(t.healthR))
local tapAPI, checks = env.UnitIsTapDenied, 0
env.UnitIsTapDenied = function(...) checks = checks + 1; return tapAPI(...) end
write("reactionColors", false)
checks = 0
env.FireEvent("UNIT_FLAGS", "target")
assert(checks == 1, "one UNIT_FLAGS reads the tapped state once: " .. checks)
env.UnitIsTapDenied = tapAPI
unit.tapDenied, unit.reaction = false, 2
write("target.healthColor", "reaction")
write("target.powerColor", "power")
write("target.power", false)

-- 9a and 9b. An unchanged threat is not written again; a restriction hides the old percentage.
write("target.threatPercent", true)
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
local function writes()
	return #W.Calls(t.threatText, "SetFormattedText"), #W.Calls(t.threatText, "SetTextColor")
end
local f, c = writes()
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
local f2, c2 = writes()
assert(f2 == f and c2 == c, "an unchanged threat writes nothing: " .. (f2 - f) .. " text, " .. (c2 - c) .. " colour")
env._threat = 70
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(U.Shown(env, t.threatText) == "70%", "a changed threat is written")
env._threat = env.Secret(64)
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
env.RunTimers()
assert(not t.threatText:IsShown(), "a restriction change rereads threat and hides the secret percentage")
env._threat = nil
write("target.threatPercent", false)

-- 10. The class-coloured swords follow a palette change.
unit.class, unit.combat, unit.isPlayer = "MAGE", true, true
write("target.combat", true)
write("target.combatClassColor", true)
K.Theme.SetPalette({ MAGE = { r = 0.77, g = 0.12, b = 0.33 } }, 0)
env.RunTimers()
assert(near(W.LastCall(t.icons.combat, "SetVertexColor")[1], (K.Theme.ClassColorForWidget("MAGE"))), "the swords take the new class colour")
write("target.combatClassColor", false)
local tint = W.LastCall(t.icons.combat, "SetVertexColor")
assert(tint[1] == 1 and tint[2] == 1 and tint[3] == 1 and W.LastCall(t.icons.combat, "SetDesaturated")[1] == false, "off still restores the original art")
write("target.combat", false)
unit.combat, unit.isPlayer = nil, nil

-- 11b and 11c. The HUD preview ignores the reaction swatches like live; Threat glow only as a non-tank shows on the player sample.
write("target.healthColor", "hud")
write("edit", "target")
pane:Refresh()
local plain = pane.views.target.healthR
write("reactionColors", true)
pane:Refresh()
assert(near(pane.views.target.healthR, plain), "the HUD preview keeps its colour with the swatches on")
write("reactionColors", false)
write("edit", "player")
pane:Refresh()
assert(not pane.views.player.glowFrame:IsShown(), "the player sample has no glow by default")
write("player.threatNonTank", true)
pane:Refresh()
assert(pane.views.player.glowFrame:IsShown(), "the player sample shows the non-tank glow")
write("player.threatNonTank", false)
pane:Refresh()
assert(not pane.views.player.glowFrame:IsShown(), "off clears it")
clean(env, K)

-- 3. Medallions keeps an explicit threat place equal to the frame's generic default, through its own row.
local m, M, mn = U.New({ saved = { version = U.DbVersion(), characters = {}, profiles = { Default = { UnitFrames = { enabled = true } } } } })
local module = M.Store.Module("UnitFrames")
for kind, place in pairs({ target = "RIGHT", focus = "OUTRIGHT" }) do
	assert(mn.Settings.Value(kind, "threatPercentPosition") == "OUTLEFT", kind .. " slabs start left of the bar")
	M.Options.Write("UnitFrames", "edit", kind)
	M.Options.Write("UnitFrames", kind .. ".threatPercent", true)
	local frames, slabs = M.Options.Row("UnitFrames", kind .. ".threatPercentPosition"), M.Options.Row("UnitFrames", kind .. ".slabThreatPercentPosition")
	assert(slabs.showWhen(module) and not frames.showWhen(module), kind .. ": Medallions shows its own place row")
	M.Options.Write("UnitFrames", kind .. ".slabThreatPercentPosition", place)
	m.RunTimers()
	assert(mn.Settings.Value(kind, "threatPercentPosition") == place, kind .. " keeps the chosen " .. place)
	M.Options.Write("HudStyle", "style", "frames")
	m.RunTimers()
	assert(frames.showWhen(module) and not slabs.showWhen(module), kind .. ": Frames shows the generic row again")
	assert(mn.Settings.Value(kind, "threatPercentPosition") == (kind == "target" and "RIGHT" or "OUTRIGHT"), kind .. ": Frames keeps its own place")
	M.Options.Write("HudStyle", "style", "medallions")
	m.RunTimers()
	M.Options.Write("UnitFrames", kind .. ".threatPercent", false)
end
clean(m, M)

print("test-unitframes-parity-r3b-review: ok")
