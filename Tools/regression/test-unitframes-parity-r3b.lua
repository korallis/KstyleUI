-- test-unitframes-parity-r3b.lua: parity round 3b options keep v0.2.8 looks and regions, then turn on, follow their events and turn off again: aura tooltips, boss two decimals (the Frames column widening), power percent sign, Frames' class icon zoom, icon sizes, elite in instances, combat icon class colour, PvP flag timer, non-tank threat glow, threat percent (inside the Frames column's bar), reaction colours and the target-lost sound.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function count(object, method)
	return #W.Calls(object, method)
end

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, target = { healthColor = "reaction" } } } }, characters = {}, layouts = {} },
	setup = function(e)
		e._sounds = {}
		e.SOUNDKIT = { INTERFACE_SOUND_LOST_TARGET_UNIT = 684 }
		e.PlaySound = function(id, _, noDupes) e._sounds[#e._sounds + 1] = { id, noDupes } end
		e.IsTargetLoose = function() return e._loose == true end
		e.IsInInstance = function() return e._inside == true, e._inside and "party" or "none" end
		e.IsPVPTimerRunning = function() return e._pvpMs ~= nil end
		e.GetPVPTimer = function() return e._pvpMs or -1 end
		e.UnitDetailedThreatSituation = function(_, mob)
			local u = e._units[mob]
			if u and u.detail then return unpack(u.detail) end
		end
		e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
	end,
})
local Settings = ns.Settings

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function clean()
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A v0.2.8-shaped profile keeps today's look and makes no new region.
local DEFAULTS = { auraTooltips = true, classZoom = 0, combatClassColor = false, leaderSize = 0, pvpSize = 0, eliteSize = 0, eliteInstances = true, combatSize = 0,
	leaderX = 0, leaderY = 0, pvpX = 0, pvpY = 0, combatX = 0, combatY = 0, eliteX = 0, eliteY = 0,
	powerPercentSign = true, threatNonTank = false, threatPercent = false, threatPercentColor = true, pvpTimer = false, pvpTimerSize = 10 }
for _, kind in ipairs(U.KINDS) do
	for key, value in pairs(DEFAULTS) do
		assert(Settings.defaults[kind][key] == nil or Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
	for _, view in ipairs(ns.Frames.Get(kind).views) do
		assert(view.threatText == nil and view.pvpTimer == nil and view.pvpTicker == nil, kind .. " makes no threat or timer text until an option needs one")
		assert(count(view.icons.combat, "SetDesaturated") == 0, kind .. " leaves the combat icon's colour alone")
	end
end
assert(Settings.defaults.player.pvpTimer ~= nil and Settings.defaults.focus.threatPercent ~= nil and Settings.defaults.boss.eliteSize and not Settings.defaults.pet.eliteSize,
	"each frame carries the keys its rows use")
local module = Settings.Module()
assert(not module.healthDecimalBoss and not module.targetSounds and not module.reactionColors, "module options start off")

local rows = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then rows[row.key] = row end
end
for _, key in ipairs({ "healthDecimalBoss", "targetSounds", "reactionColors", "hostileColor", "tappedColor", "target.threatPercent", "focus.threatPercentPosition",
	"player.pvpTimer", "player.pvpTimerSize", "player.threatNonTank", "target.eliteSize", "boss.eliteInstances", "player.leaderSize", "pet.pvpSize",
	"player.combatClassColor", "player.powerPercentSign", "boss.auraTooltips", "player.combatSize", "player.leaderY", "target.eliteX" }) do
	assert(rows[key] and rows[key].help, key .. " has a row with help")
end
assert(not rows["player.threatPercent"] and not rows["target.pvpTimer"] and not rows["player.eliteSize"] and not rows["target.threatNonTank"], "rows show only on the frames they serve")

-- Aura tooltips: off mutes hovering on every aura button, queued in combat; on restores it.
local target = ns.Frames.Get("target").views[1]
assert(#target.auras.buttons > 0, "the target has aura buttons")
for _, entry in ipairs(target.auras.buttons) do
	assert(count(entry.button, "SetMouseMotionEnabled") == 0, "default aura buttons are left as the engine made them")
end
write("target.auraTooltips", false)
for _, entry in ipairs(target.auras.buttons) do
	assert(W.LastCall(entry.button, "SetMouseMotionEnabled")[1] == false, "aura tooltips off stops hover tooltips")
end
env.SetCombat(true)
write("target.auraTooltips", true)
assert(W.LastCall(target.auras.buttons[1].button, "SetMouseMotionEnabled")[1] == false, "a combat change waits")
env.SetCombat(false)
env.RunTimers()
for _, entry in ipairs(target.auras.buttons) do
	assert(W.LastCall(entry.button, "SetMouseMotionEnabled")[1] == true, "combat's end restores hover tooltips")
end
local calls = count(target.auras.buttons[1].button, "SetMouseMotionEnabled")
write("target.auraSize", 24)
assert(count(target.auras.buttons[1].button, "SetMouseMotionEnabled") == calls, "an unchanged switch is not set again")
local boss = ns.Frames.Get("boss").views[1]
write("boss.auraTooltips", false)
for _, entry in ipairs(boss.auras.buttons) do
	assert(W.LastCall(entry.button, "SetMouseMotionEnabled")[1] == false, "boss aura tooltips switch off apart")
end
write("boss.auraTooltips", true)
clean()

-- Boss health with two decimals, on its own and with the one-decimal switch, queued in combat; the slab shows the percent under its values.
U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41270, healthMax = 100000, reaction = 2, canAttack = true })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(U.Shown(env, boss.healthSub):find("41%", 1, true), "boss health keeps its whole percent: " .. U.Shown(env, boss.healthSub))
write("healthDecimalBoss", true)
assert(U.Shown(env, boss.healthSub):find("41.27%", 1, true), "boss health shows two decimals: " .. U.Shown(env, boss.healthSub))
assert(not U.Shown(env, target.healthText):find("%.%d%d%%"), "other frames keep their percent")
env._units.boss1.health = 50005
env.FireEvent("UNIT_HEALTH", "boss1")
assert(U.Shown(env, boss.healthSub):find("50.01%", 1, true) or U.Shown(env, boss.healthSub):find("50.00%", 1, true), "health updates keep two decimals")
write("healthDecimal", true)
assert(U.Shown(env, boss.healthSub):find("%d%.%d%d%%"), "two decimals win over one on bosses")
write("healthDecimal", false)
env.SetCombat(true)
write("healthDecimalBoss", false)
assert(U.Shown(env, boss.healthSub):find("%d%.%d%d%%"), "a combat change waits")
env.SetCombat(false)
env.RunTimers()
assert(not U.Shown(env, boss.healthSub):find("%.%d"), "off restores the whole percent: " .. U.Shown(env, boss.healthSub))
clean()

-- Power percent sign.
local player = ns.Frames.Get("player").views[1]
env._units.player.power, env._units.player.powerMax = 1500, 3000
write("player.powerText", "percent")
assert(U.Shown(env, player.powerText) == "50%", "power percent keeps its sign: " .. U.Shown(env, player.powerText))
write("player.powerPercentSign", false)
assert(U.Shown(env, player.powerText) == "50", "off shows the number alone: " .. U.Shown(env, player.powerText))
env._units.player.power = 750
env.FireEvent("UNIT_POWER_UPDATE", "player")
assert(U.Shown(env, player.powerText) == "25", "power updates stay bare")
write("player.powerText", "both")
assert(not U.Shown(env, player.powerText):find("%", 1, true), "current, max and percentage stays bare")
write("player.powerPercentSign", true)
assert(U.Shown(env, player.powerText):find("25%", 1, true), "on restores the sign")
write("player.powerText", "auto")
clean()

-- Leader, PvP and combat sizes (0 follows Icon size) and offsets (0 keeps the slot).
env._units.player.leader, env._units.player.pvp, env._units.player.faction = true, true, "Alliance"
env.FireEvent("PARTY_LEADER_CHANGED")
local leader, pvp = player.icons.leader, player.icons.pvp
local base = W.LastCall(leader, "SetSize")[1]
write("player.leaderSize", 20)
write("player.pvpSize", 18)
assert(W.LastCall(leader, "SetSize")[1] > base and W.LastCall(pvp, "SetSize")[1] > base, "the crown and badge take their own sizes")
assert(W.LastCall(player.icons.role, "SetSize")[1] == base, "other icons keep Icon size")
local slot = W.LastCall(leader, "SetPoint")
assert(slot[1] == "CENTER", "a resized icon stays centred on its slot")
write("player.leaderSize", 0)
write("player.pvpSize", 0)
assert(W.LastCall(leader, "SetSize")[1] == base and W.LastCall(pvp, "SetSize")[1] == base, "0 restores Icon size")
write("player.combatSize", 22)
assert(W.LastCall(player.icons.combat, "SetSize")[1] > base, "the swords take their own size")
write("player.combatSize", 0)
slot = W.LastCall(leader, "SetPoint")
local x0, y0 = slot[4], slot[5]
write("player.leaderX", 10)
write("player.leaderY", -6)
slot = W.LastCall(leader, "SetPoint")
assert(slot[4] > x0 and slot[5] < y0, "offsets move the crown right and down")
assert(W.LastCall(pvp, "SetPoint")[4] ~= slot[4], "other icons stay in their slots")
env.FireEvent("PARTY_LEADER_CHANGED")
assert(W.LastCall(leader, "SetPoint")[4] == slot[4], "a leader change keeps the offset")
write("player.leaderX", 0)
write("player.leaderY", 0)
slot = W.LastCall(leader, "SetPoint")
assert(slot[4] == x0 and slot[5] == y0, "0 restores the slot")
clean()

-- Elite badge: its own size and the instance rule, following PLAYER_ENTERING_WORLD.
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100, reaction = 2, canAttack = true, classification = "elite" })
env.FireEvent("PLAYER_TARGET_CHANGED")
write("target.elite", true)
local badge = assert(target.extraIcon, "the elite badge shows")
assert(badge:IsShown() and W.LastCall(badge, "SetAllPoints")[1] == target.icons.resting, "the badge fills the resting slot")
write("target.eliteSize", 20)
assert(W.LastCall(badge, "SetPoint")[2] == target.icons.resting and W.LastCall(badge, "SetSize")[1] > 0, "the badge takes its own size on the slot")
write("target.eliteInstances", false)
assert(badge:IsShown(), "outside instances the badge still shows")
env._inside = true
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(not badge:IsShown(), "inside an instance the badge hides")
env._inside = false
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(badge:IsShown(), "leaving the instance shows it again")
env._inside = true
write("target.eliteInstances", true)
assert(badge:IsShown(), "on shows the badge in instances")
env._inside = false
write("target.eliteSize", 0)
assert(W.LastCall(badge, "SetAllPoints")[1] == target.icons.resting, "0 restores the slot's size")
write("target.eliteX", 8)
local moved = W.LastCall(badge, "SetPoint")
assert(moved[1] == "CENTER" and moved[2] == target.icons.resting and moved[4] > 0, "an offset moves the badge off its slot")
write("target.eliteX", 0)
assert(W.LastCall(badge, "SetAllPoints")[1] == target.icons.resting, "0 puts it back")
write("target.elite", false)
clean()

-- Combat icon in class colour: follows combat and unit changes; a secret class stays white; off restores.
write("target.combat", true)
local swords = target.icons.combat
env._units.target.isPlayer, env._units.target.class, env._units.target.combat = true, "MAGE", true
env.FireEvent("UNIT_FLAGS", "target")
assert(count(swords, "SetDesaturated") == 0, "the default leaves the icon's colours")
write("target.combatClassColor", true)
assert(W.LastCall(swords, "SetDesaturated")[1] == true, "class colour greys the art first")
local r, g, b = W.LastCall(swords, "SetVertexColor")[1], W.LastCall(swords, "SetVertexColor")[2], W.LastCall(swords, "SetVertexColor")[3]
local cr, cg, cb = K.Theme.ClassColorForWidget("MAGE")
assert(near(r, cr) and near(g, cg) and near(b, cb), "the swords take the unit's class colour")
local tints = count(swords, "SetVertexColor")
env.FireEvent("UNIT_FLAGS", "target")
assert(count(swords, "SetVertexColor") == tints, "an unchanged class is not tinted again")
env._units.target.class = "HUNTER"
env.FireEvent("PLAYER_TARGET_CHANGED")
cr = K.Theme.ClassColorForWidget("HUNTER")
assert(near(W.LastCall(swords, "SetVertexColor")[1], cr), "a new target takes its class colour")
env._units.target.secretClass = true
env.FireEvent("UNIT_FLAGS", "target")
r = W.LastCall(swords, "SetVertexColor")
assert(r[1] == 1 and r[2] == 1 and r[3] == 1 and W.LastCall(swords, "SetDesaturated")[1] == false, "a secret class keeps the original art")
env._units.target.secretClass = nil
env.FireEvent("UNIT_FLAGS", "target")
write("target.combatClassColor", false)
r = W.LastCall(swords, "SetVertexColor")
assert(r[1] == 1 and r[2] == 1 and r[3] == 1 and W.LastCall(swords, "SetDesaturated")[1] == false, "off restores the original art")
write("target.combat", false)
clean()

-- PvP flag timer: made on first need, after the status icons, ticks once a second, stops with the flag, off hides it.
env._pvpMs = 272000
env.FireEvent("PLAYER_FLAGS_CHANGED", "player")
assert(player.pvpTimer == nil, "the timer waits for its option")
write("player.pvpTimer", true)
local timer = assert(player.pvpTimer, "the timer shows while the flag counts down")
assert(timer:IsShown() and U.Shown(env, timer) == "4:32", "it reads minutes and seconds: " .. U.Shown(env, timer))
local spot = W.LastCall(timer, "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == player.icons.resting and spot[3] == "CENTER", "it sits after the last status icon, clear of the others and the frame above")
assert(player.pvpTicker and env.LiveTickers() >= 1, "one ticker counts it down")
env._pvpMs = 61000
env.RunTickers()
assert(U.Shown(env, timer) == "1:01", "the ticker updates the time")
write("player.pvpTimerSize", 14)
assert(W.LastCall(timer, "SetFont"), "the size applies")
local ticker = player.pvpTicker
env._pvpMs = nil
env.RunTickers()
assert(not timer:IsShown() and ticker.cancelled and player.pvpTicker == nil, "the timer hides and stops when the flag stays")
env._pvpMs = 30000
env.FireEvent("PVP_TIMER_UPDATE", "player")
assert(timer:IsShown(), "PVP_TIMER_UPDATE starts it again")
write("player.pvpTimer", false)
assert(not timer:IsShown() and player.pvpTicker == nil, "off hides it and stops the ticker")
env._pvpMs = nil
clean()

-- Threat glow only as a non-tank in instances, following role and world changes.
env._units.player.threat, env._units.player.role = 3, "DAMAGER"
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
local glow = player.glowFrame
assert(glow:IsShown(), "the default glow shows anywhere")
write("player.threatNonTank", true)
assert(not glow:IsShown(), "outside instances the non-tank glow stays off")
env._inside = true
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(glow:IsShown(), "inside, a damage dealer with threat glows")
env._units.player.role = "TANK"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(not glow:IsShown(), "the tank does not glow")
env._units.player.role = "HEALER"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(glow:IsShown(), "a healer with threat glows")
write("player.threatNonTank", false)
env._units.player.role, env._inside = "TANK", false
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(glow:IsShown(), "off restores the glow for everyone")
env._units.player.threat = nil
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
clean()

-- Threat percent on the target and focus: threat events, colour, secrets, place, off.
env._units.target.detail = { false, 2, 64.4, 70, 1000 }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(target.threatText == nil, "threat percent waits for its option")
write("target.threatPercent", true)
local pct = assert(target.threatText, "threat percent shows")
assert(pct:IsShown() and U.Shown(env, pct) == "64%", "it reads the scaled percentage: " .. U.Shown(env, pct))
r, g, b = pct:GetTextColor()
cr, cg, cb = K.Theme.ThreatColor(2)
assert(near(r, cr) and near(g, cg) and near(b, cb), "it takes the threat colour")
spot = W.LastCall(pct, "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == target.health and spot[3] == "LEFT" and spot[4] < 0, "it starts left of the slab's bar, clear of the values inside it")
assert(Settings.Value("focus", "threatPercentPosition") == "OUTLEFT", "the focus slab starts with it left of the bar")
env._units.target.detail = { true, 3, 100, 100, 2000 }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(U.Shown(env, pct) == "100%", "threat updates refresh it")
write("target.threatPercentColor", false)
r, g, b = pct:GetTextColor()
cr, cg, cb = K.Tokens.Color("textEmphasis")
assert(near(r, cr) and near(g, cg) and near(b, cb), "colour off uses the frame's text colour")
env._units.target.detail = { env.Secret(true), env.Secret(3), env.Secret(90), env.Secret(90), env.Secret(9) }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(not pct:IsShown(), "secret threat values hide it")
local hides = count(pct, "Hide")
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(count(pct, "Hide") == hides, "a hidden percentage is not hidden again")
env._units.target.detail = { false, 1, 30, 30, 10 }
env.FireEvent("PLAYER_TARGET_CHANGED")
W.Tick(env, 0.06)
assert(pct:IsShown() and U.Shown(env, pct) == "30%", "a target change reads it again")
write("target.slabThreatPercentPosition", "RIGHT")
spot = W.LastCall(pct, "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == target.health and spot[3] == "RIGHT" and spot[4] < 0, "Right moves it inside the bar's right edge")
write("target.slabThreatPercentPosition", "TOPRIGHT")
assert(Settings.Value("target", "threatPercentPosition") == "OUTLEFT", "an unknown place falls back to the default")
env._units.target.detail = nil
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(not pct:IsShown(), "no threat entry hides it")
env._units.target.detail = { false, 1, 30, 30, 10 }
write("target.threatPercent", false)
assert(not pct:IsShown(), "off hides it")
U.SetUnit(env, "focus", env._units.target)
env.FireEvent("PLAYER_FOCUS_CHANGED")
local focus = ns.Frames.Get("focus").views[1]
write("focus.threatPercent", true)
assert(focus.threatText and focus.threatText:IsShown() and U.Shown(env, focus.threatText) == "30%", "the focus shows its threat percent")
write("focus.threatPercent", false)
clean()

-- Custom reaction colours on reaction bars, through faction and tapped changes.
local bar = target.health
local function fill()
	local call = W.LastCall(bar, "SetStatusBarColor")
	return call[1], call[2], call[3]
end
local tr, tg, tb = fill()
write("reactionColors", true)
write("hostileColor", { r = 0.9, g = 0.1, b = 0.5 })
r, g, b = fill()
assert(near(r, 0.9) and near(g, 0.1) and near(b, 0.5), "hostile bars take the custom colour")
env._units.target.reaction = 4
env.FireEvent("UNIT_FACTION", "target")
local nr, ng, nb = Settings.Module().neutralColor.r, Settings.Module().neutralColor.g, Settings.Module().neutralColor.b
r, g, b = fill()
assert(near(r, nr) and near(g, ng) and near(b, nb), "UNIT_FACTION turns a neutral unit the neutral colour")
env._units.target.tapDenied = true
write("tappedColor", { r = 0.2, g = 0.3, b = 0.4 })
r, g, b = fill()
assert(near(r, 0.2) and near(g, 0.3) and near(b, 0.4), "a tapped unit takes the tapped colour")
env._units.target.tapDenied, env._units.target.reaction = nil, 2
write("reactionColors", false)
r, g, b = fill()
assert(near(r, tr) and near(g, tg) and near(b, tb), "off restores the original hostile colour")
env._units.target.secretReaction = true
write("reactionColors", true)
env.FireEvent("UNIT_FACTION", "target")
assert(not near(fill(), 0.9), "a secret reaction keeps the original colour")
env._units.target.secretReaction = nil
write("reactionColors", false)
clean()

-- Target lost sound: only when Blizzard's target frame is hidden, a target was lost and the target was not soft.
assert(K.Safe.IsHidden(env.TargetFrame), "KstyleUI hides Blizzard's target frame")
U.SetUnit(env, "target", nil)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#env._sounds == 0, "off plays nothing")
write("targetSounds", true)
U.SetUnit(env, "target", { name = "Wolf", level = 60, health = 10, healthMax = 10, reaction = 2 })
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#env._sounds == 0, "picking a target leaves the game's own sound")
U.SetUnit(env, "target", nil)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#env._sounds == 1 and env._sounds[1][1] == 684 and env._sounds[1][2] == true, "losing the target plays the game's sound")
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#env._sounds == 1, "no target to lose plays nothing")
U.SetUnit(env, "target", { name = "Wolf", level = 60, health = 10, healthMax = 10, reaction = 2 })
env.FireEvent("PLAYER_TARGET_CHANGED")
env._loose = true
U.SetUnit(env, "target", nil)
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#env._sounds == 1, "a soft target plays nothing")
env._loose = nil
write("targetSounds", false)
clean()

-- The preview shows each option.
write("edit", "target")
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.target
write("target.threatPercent", true)
write("target.combat", true)
write("target.combatClassColor", true)
pane:Refresh()
assert(sample.threatText and sample.threatText:IsShown() and U.Shown(env, sample.threatText) == "87%", "the preview shows threat percent")
assert(sample.icons.combat:IsShown() and W.LastCall(sample.icons.combat, "SetDesaturated")[1] == true, "the preview shows the class-coloured swords")
write("target.threatPercent", false)
write("target.combatClassColor", false)
write("target.combat", false)
pane:Refresh()
assert(not sample.threatText:IsShown() and not sample.icons.combat:IsShown(), "the preview clears them when turned off")
write("edit", "player")
write("player.pvpTimer", true)
write("player.powerPercentSign", false)
write("player.powerText", "percent")
pane:Refresh()
local own = pane.views.player
assert(own.pvpTimer and own.pvpTimer:IsShown() and U.Shown(env, own.pvpTimer) == "4:32" and own.icons.pvp:IsShown(), "the player preview shows the badge and its timer")
assert(not U.Shown(env, own.powerText):find("%", 1, true), "the preview drops the percent sign")
local faction = env._units.player.faction
env._units.player.faction = nil
pane:Refresh()
assert(not own.pvpTimer:IsShown(), "without a faction badge the preview shows no timer")
env._units.player.faction = faction
write("player.pvpTimer", false)
write("player.powerPercentSign", true)
write("player.powerText", "auto")
pane:Refresh()
assert(not own.pvpTimer:IsShown(), "the preview hides the timer when off")
write("edit", "boss")
write("healthDecimalBoss", true)
pane:Refresh()
assert(U.Shown(env, pane.views.boss.healthText):find("72.00%", 1, true), "the boss preview shows two decimals: " .. U.Shown(env, pane.views.boss.healthText))
write("healthDecimalBoss", false)
clean()
-- Medallions slabs carry health text inside the bar, so threat percent starts left of the bar there.
local menv, MK, mns = U.New({ saved = { version = U.DbVersion(), characters = {}, profiles = { Default = { UnitFrames = { enabled = true } } } },
	setup = function(e) e.UnitDetailedThreatSituation = function() return false, 2, 64, 64, 10 end end })
U.SetUnit(menv, "target", { name = "Wolf", level = 10, health = 50, healthMax = 100, reaction = 2, canAttack = true })
menv.SetTarget(true)
assert(mns.Settings.Value("target", "threatPercentPosition") == "OUTLEFT" and mns.Settings.Value("focus", "threatPercentPosition") == "OUTLEFT", "slabs start left of the bar")
MK.Options.Write("UnitFrames", "target.threatPercent", true)
menv.RunTimers()
local slab = mns.Frames.Get("target").views[1]
spot = W.LastCall(assert(slab.threatText, "the slab shows threat percent"), "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == slab.health and spot[3] == "LEFT", "the slab's threat percent sits left of its bar")
assert(#menv._errors == 0 and MK.ErrorCount() == 0, tostring(menv._errors[1]))

-- Frames: the boss percent column widens for two decimals, class icon zoom crops only the class icon, and the column's
-- threat percent sits inside its bar.
local fenv, FK, fns = U.New({ frames = true, saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {} },
	setup = function(e)
		e.UnitDetailedThreatSituation = function() return false, 2, 64.4, 70, 1000 end
		e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
	end })
local function fwrite(key, value)
	FK.Options.Write("UnitFrames", key, value)
	fenv.RunTimers()
end
U.SetUnit(fenv, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41270, healthMax = 100000, reaction = 2, canAttack = true })
fenv.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
local fboss = fns.Frames.Get("boss").views[1]
assert(U.Shown(fenv, fboss.healthText):find("41%", 1, true), "Frames boss health keeps its whole percent: " .. U.Shown(fenv, fboss.healthText))
local width = fboss.geometry.healthText and fboss.geometry.healthText.w
fwrite("healthDecimalBoss", true)
assert(U.Shown(fenv, fboss.healthText):find("41.27%", 1, true), "Frames boss health shows two decimals: " .. U.Shown(fenv, fboss.healthText))
assert(width and fboss.geometry.healthText.w > width, "the boss percent column widens")
fwrite("healthDecimalBoss", false)
local portrait = fns.Frames.Get("player").views[1].portrait
fwrite("player.portraitZoom", 0.2)
fwrite("player.portraitStyle", "class")
local coords = W.LastCall(portrait, "SetTexCoord")
assert(coords[1] == 0 and coords[2] == 1, "portrait zoom leaves the class icon whole")
fwrite("player.classZoom", 0.2)
coords = W.LastCall(portrait, "SetTexCoord")
assert(near(coords[1], 0.12) and near(coords[2], 0.28) and near(coords[3], 0.52) and near(coords[4], 0.68), "class icon zoom crops inside the atlas")
fenv.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
assert(near(W.LastCall(portrait, "SetTexCoord")[1], 0.12), "a portrait update keeps the crop")
fwrite("player.portraitStyle", "portrait")
coords = W.LastCall(portrait, "SetTexCoord")
assert(near(coords[1], 0.1) and near(coords[2], 0.9), "the portrait takes its own zoom")
U.SetUnit(fenv, "target", { name = "Wolf", level = 10, health = 50, healthMax = 100, reaction = 2, canAttack = true })
fenv.SetTarget(true)
fwrite("target.threatPercent", true)
local column = fns.Frames.Get("target").views[1]
spot = W.LastCall(assert(column.threatText, "the column shows threat percent"), "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == column.health and spot[3] == "RIGHT" and spot[4] < 0, "it sits inside the health bar's right edge, clear of the column's text")
assert(fns.Settings.Value("focus", "threatPercentPosition") == "OUTRIGHT", "the thin focus bar starts with it beside the bar")
fwrite("target.threatPercentPosition", "OUTLEFT")
spot = W.LastCall(column.threatText, "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == column.health and spot[3] == "LEFT" and spot[4] < 0, "Left of the bar moves it outside the bar")
fwrite("target.threatPercentPosition", "TOPRIGHT")
assert(fns.Settings.Value("target", "threatPercentPosition") == "RIGHT", "an unknown place falls back to the default")
assert(#fenv._errors == 0 and FK.ErrorCount() == 0, tostring(fenv._errors[1]))
print("test-unitframes-parity-r3b: ok")
