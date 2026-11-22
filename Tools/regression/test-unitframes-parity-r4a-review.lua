-- test-unitframes-parity-r4a-review.lua: the round 4a review's probes: the text bar clear of the frame's content with outside anchors fixed, tracked debuffs on the crest fan and for an unknown reaction, the preview's class icon, tints, Medallions boss cast and debuffs-only samples, the switched-off tag pass and static tints, and the formatter's fallbacks.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	setup = function(e)
		e.UnitCanAssist = function(_, token) return e._units[token] ~= nil and e._units[token].assist == true end
	end,
})

local function set(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function clean()
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function hit(a, b)
	return a.x < b.x + b.w - 0.01 and b.x < a.x + a.w - 0.01 and a.y < b.y + b.h - 0.01 and b.y < a.y + a.h - 0.01
end

-- Every rect the frame draws stays off the strip; a centred aura row counts with its whole block.
local function clear(view, label, placed)
	local bar = view.barRect
	assert(bar or not placed, label .. ": the strip is placed")
	if not bar then return end
	for key, r in pairs(view.geometry) do
		if type(r) == "table" and r.w and key ~= "marker" then
			local h = key == "aura" and (r.centred and select(2, ns.Auras.Footprint(view.kind)) or 0) or r.h
			if r.w > 0 and h > 0 or r.centred then
				assert(not hit({ x = r.x - (r.centred and 1 or 0), y = r.y, w = math.max(r.w, 2), h = h }, bar),
					string.format("%s: the strip (%.2f..%.2f, %.2f..%.2f) covers %s (%.2f..%.2f, %.2f..%.2f)", label, bar.x, bar.x + bar.w, bar.y, bar.y + bar.h, key, r.x, r.x + r.w, r.y, r.y + h))
			end
		end
	end
end

-- 1. The strip keeps clear of the form's own content and leaves the outside anchors where they were.
local target = ns.Frames.Get("target").views[1]
set("target.auraPosition", "SIDE")
set("target.textBarPlace", "TOP")
local before = W.LastCall(target.auras.host, "SetPoint")
set("target.textBar", true)
local after = W.LastCall(target.auras.host, "SetPoint")
assert(after[4] == before[4] and after[5] == before[5], "a top strip leaves the side auras where they were: " .. before[5] .. " then " .. after[5])
local player = ns.Frames.Get("player").views[1]
set("player.textBar", true)
set("player.textBarIcon", "LEFT")
clear(player, "Medallions player, bottom", true)
clear(target, "Medallions target, top", true)
set("focus.textBar", true)
set("focus.textBarPlace", "ABOVE")
clear(ns.Frames.Get("focus").views[1], "Medallions focus, above", true)
set("focus.textBar", false)
set("player.textBar", false)
set("target.textBar", false)
clean()

-- 2. Only tracked debuffs follows the crest fan without frame auras, and an unknown reaction is not an enemy.
U.SetUnit(env, "target", { name = "Ogre", level = 60, health = 50, healthMax = 100, reaction = 2, canAttack = true, assist = false })
env.FireEvent("PLAYER_TARGET_CHANGED")
set("target.auraTracked", "999999")
set("target.auraTrackedDebuffs", true)
set("auraLayout", "fan")
set("target.crestDebuffs", true)
set("target.auras", false)
local fan = target.auras.fan
assert(fan and fan.enabled, "the crest fan is on")
local function crest()
	local c = fan.containers[1]._groups.debuffs.candidates
	return c and c.includeSpellIDs and c.includeSpellIDs[999999]
end
assert(crest(), "the crest keeps an enemy's tracked debuffs")
env._units.target.assist = true
env.FireEvent("UNIT_FACTION", "target")
env.RunTimers()
assert(not crest(), "a friend's debuffs all show on the crest again")
set("target.auras", true)
local assist = env.UnitCanAssist
env.UnitCanAssist = nil
local c = ns.Auras.Candidates(target, "debuffs")
assert(not (c and c.includeSpellIDs), "without UnitCanAssist the reaction is unknown, so every debuff shows")
env.UnitCanAssist = assist
set("target.auraTrackedDebuffs", false)
clean()

-- 3 and 4. The preview: no unit API for a sample, tints and the icon survive the fitting pass, the Medallions boss cast and debuffs-only samples.
set("edit", "target")
set("target.textBar", true)
set("target.textBarIcon", "LEFT")
set("target.textBarLeft.textFormat", "[name]")
local unitClass = env.UnitClass
env.UnitClass = function(token)
	assert(token ~= nil, "UnitClass needs a unit token")
	return unitClass(token)
end
local pane = ns.Preview.Build(env.UIParent)
env.UnitClass = unitClass
assert(not pane.views.target.textBar.icon:IsShown(), "the beast sample has no class icon")
set("target.textBar", false)
set("edit", "focus")
set("focus.textBar", true)
set("focus.textBarLeft.textFormat", "[name]")
set("focus.textBarLeft.colorMode", "custom")
set("focus.textBarLeft.color", { r = 1, g = 0, b = 0 })
pane:Refresh()
local tint = W.LastCall(pane.views.focus.textBarLeft, "SetTextColor")
assert(tint[1] == 1 and tint[2] == 0 and tint[3] == 0, "the preview keeps a custom colour: " .. tint[1] .. ", " .. tint[2] .. ", " .. tint[3])
set("focus.textBar", false)
set("edit", "boss")
set("boss.castbarWidth", 150)
pane:Refresh()
local live = W.LastCall(ns.Frames.Get("boss").views[1].castbar.frame, "SetSize")
local cast = pane.casts.boss
assert(cast and cast.frame:IsShown() and math.abs(W.LastCall(cast.frame, "SetSize")[1] - live[1]) < 1, "the Medallions boss preview draws the cast bar the frame draws")
set("boss.castbarWidth", 0)
set("edit", "target")
set("target.auraTracked", "999999")
set("target.auraTrackedDebuffs", true)
set("target.auraFilter", "debuffs")
pane:Refresh()
assert(pane.auraCount == 0, "a debuffs-only preview tracking no sample shows none: " .. pane.auraCount)
set("target.auraFilter", "buffs")
pane:Refresh()
local buffsOnly = pane.auraCount
set("target.auraTrackedDebuffs", false)
pane:Refresh()
assert(pane.auraCount == buffsOnly, "tracked debuffs leave a buffs-only preview alone")
set("target.auraFilter", "debuffs")
set("target.auraTracked", "")
clean()

U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41200, healthMax = 100000, reaction = 2, canAttack = true })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
local boss = ns.Frames.Get("boss").views[1]

-- 6. A strip switched off costs the tag pass nothing, and a health event leaves a static colour alone.
local function count()
	local calls = 0
	debug.sethook(function() calls = calls + 1 end, "", 1)
	for _ = 1, 100 do ns.Unit.TextTags(player, "player", "Health") end
	debug.sethook()
	return calls
end
local idle = count()
set("player.textBar", true)
set("player.textBarLeft.textFormat", "[name]")
set("player.textBar", false)
assert(count() == idle, "the tag pass is as cheap as before the strip")
set("player.textBar", true)
set("player.textBarLeft.colorMode", "custom")
local tints = #W.Calls(player.textBarLeft, "SetTextColor")
env.FireEvent("UNIT_HEALTH", "player")
assert(#W.Calls(player.textBarLeft, "SetTextColor") == tints, "a health event does not tint a static name again")
set("player.textBar", false)
clean()

-- 7. Only the frames with aura rows carry the tracked debuffs switch.
assert(ns.Settings.defaults.targettarget.auraTrackedDebuffs == nil and ns.Settings.defaults.focustarget.auraTrackedDebuffs == nil, "their targets have no tracked debuffs")

-- 8. A curve the client cannot make keeps the fixed places, and a comma decimal mark still trims.
local function pct(region) return U.Shown(env, region):match("[%d%.,]+%%") end
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 2000, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
set("target.healthText", "percent")
set("healthDecimal", true)
env._units.target.health = 2223
env.FireEvent("UNIT_HEALTH", "target")
local create = env.C_CurveUtil.CreateCurve
env.C_CurveUtil.CreateCurve = function() return nil end
set("healthDecimalTrim", true)
env._units.target.health = 2000
env.FireEvent("UNIT_HEALTH", "target")
assert(pct(target.healthText) == "50.0%", "no curve keeps one fixed place: " .. tostring(pct(target.healthText)))
env.C_CurveUtil.CreateCurve = function() error("no curve") end
set("healthDecimalBoss", true)
assert(pct(boss.healthSub) == "41.20%", "a failing curve keeps two fixed places: " .. tostring(pct(boss.healthSub)))
env.C_CurveUtil.CreateCurve = create
clean()

local comma, Kc, nsc = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, healthDecimal = true, healthDecimalTrim = true } } }, characters = {} },
	setup = function(e)
		local abbreviate = e.AbbreviateNumbers
		e.AbbreviateNumbers = function(...)
			local text = abbreviate(...)
			return e.issecretvalue(text) and text or (text:gsub("%.", ","))
		end
	end,
})
local view = nsc.Frames.Get("target").views[1]
U.SetUnit(comma, "target", { name = "Ogre", level = 62, health = 2000, healthMax = 4000, reaction = 2, canAttack = true })
comma.FireEvent("PLAYER_TARGET_CHANGED")
assert(U.Shown(comma, view.healthText):find("50%", 1, true) and not U.Shown(comma, view.healthText):find("50,0", 1, true), "a comma mark trims too: " .. U.Shown(comma, view.healthText))
comma._units.target.health = 2223
comma.FireEvent("UNIT_HEALTH", "target")
assert(U.Shown(comma, view.healthText):find("55[,.]6%%"), "and keeps a real decimal: " .. U.Shown(comma, view.healthText))
assert(#comma._errors == 0 and Kc.ErrorCount() == 0, tostring(comma._errors[1]))
print("test-unitframes-parity-r4a-review: ok")
