-- test-unitframes-parity-r4a-frames.lua: on Frames, parity round 4a keeps v0.2.8 frames, then turns on, probes after events and turns off the text bar, the boss cast bar's width and height, trailing zeros and tracked debuffs, and checks the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({ frames = true,
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} },
	setup = function(e)
		e.UnitCanAssist = function(_, token) return e._units[token] ~= nil and e._units[token].assist == true end
	end,
})
local Settings = ns.Settings

local function clean()
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
	assert(K.Options.Read("UnitFrames", key) == value, key .. " must round-trip")
end

local function same(a, b)
	return math.abs(a - b) < 1e-6
end

-- A v0.2.8-shaped profile keeps today's values and makes no text bar.
for kind in pairs(Settings.TEXT_BAR) do
	assert(Settings.Value(kind, "textBar") == false and Settings.Value(kind, "textBarPlace") == "BOTTOM" and Settings.Value(kind, "textBarStrata") == "", kind .. " text bar starts off")
	assert(ns.Frames.Get(kind).views[1].textBar == nil and ns.Frames.Get(kind).views[1].barRect == nil, kind .. " makes no strip by default")
end
assert(not Settings.defaults.pet.textBar and not Settings.defaults.boss.textBar, "only the main frames carry a text bar")
assert(Settings.Value("boss", "castbarWidth") == 0 and Settings.Snapshot("boss").cardCast == 16 and Settings.Snapshot("focus").castbarHeight == 16, "the cards keep their 16-unit cast line")
assert(Settings.Module().healthDecimalTrim == false and Settings.Value("target", "auraTrackedDebuffs") == false, "trailing zeros and tracked debuffs start off")
local rows = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then rows[row.key] = row end
end
for _, key in ipairs({ "healthDecimalTrim", "boss.castbarWidth", "target.auraTrackedDebuffs", "player.textBar", "focus.textBarPlace", "target.textBarIcon",
	"player.textBarStrata", "focus.textBarWidth", "target.textBarLeft.textFormat", "player.textBarRight.width", "focus.textBarCenter.x" }) do
	assert(rows[key] and rows[key].help, key .. " has a row with help")
end
assert(rows["boss.castbarHeight"].shown(10) == 16 and rows["boss.castbarHeight"].shown(11) == 17, "the boss card's height slider shows the card's line")
assert(not rows["pet.textBar"] and not rows["boss.textBar"] and not rows["player.auraTrackedDebuffs"] and not rows["pet.auraTrackedDebuffs"], "rows show only where they work")

-- Boss cast bar: height and width on the boss card, then under a plate.
local boss = ns.Frames.Get("boss").views[1]
U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41270, healthMax = 100000, reaction = 2, canAttack = true })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
local cast, panel = boss.geometry.cast, boss.geometry.panel
assert(cast and cast.h == 16 and same(cast.w, panel.w), "the card's cast line is 16 units across the card")
local fullW = cast.w
write("boss.castbarHeight", 18)
assert(boss.geometry.cast.h == 24, "the card's line follows the cast height, 16 at the default 10")
write("boss.castbarWidth", 100)
assert(boss.geometry.cast.w == 100 and boss.geometry.cast.x == cast.x, "the card's cast line takes the width from its left end")
local size = W.LastCall(boss.castbar.frame, "SetSize")
assert(size and math.abs(size[1] - 100) < 1 and math.abs(size[2] - 24) < 1, "the cast bar frame follows")
write("boss.castbarWidth", 2000 - 1600)
assert(boss.geometry.cast.w == fullW, "a width past the card stops at the card")
write("boss.style", "plate")
size = W.LastCall(boss.castbar.frame, "SetSize")
assert(size and math.abs(size[1] - math.min(400, boss.geometry.panel.w)) < 1, "under a plate the width applies too")
write("boss.castbarWidth", 0)
size = W.LastCall(boss.castbar.frame, "SetSize")
assert(math.abs(size[1] - boss.geometry.panel.w) < 1, "0 matches the frame again")
write("boss.style", "lumen")
write("boss.castbarHeight", 10)
assert(boss.geometry.cast.h == 16 and boss.geometry.cast.w == fullW, "the default restores the card's line")
clean()

-- Hide trailing zeros: one decimal, then the boss's two, live and after health changes, queued in combat.
write("healthDecimal", true)
local target = ns.Frames.Get("target").views[1]
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 2000, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
local function pct(view) return U.Shown(env, view.healthText):match("[%d%.]+%%") end
assert(pct(target) == "50.0%", "one decimal keeps its zero: " .. tostring(pct(target)))
write("healthDecimalTrim", true)
assert(pct(target) == "50%", "trimmed: " .. tostring(pct(target)))
env._units.target.health = 2223
env.FireEvent("UNIT_HEALTH", "target")
assert(pct(target) == "55.6%", "a real decimal stays: " .. tostring(pct(target)))
write("healthDecimalBoss", true)
assert(pct(boss) == "41.27%", "boss keeps two places: " .. tostring(pct(boss)))
env._units.boss1.health = 41200
env.FireEvent("UNIT_HEALTH", "boss1")
assert(pct(boss) == "41.2%", "the boss drops its trailing zero: " .. tostring(pct(boss)))
env.SetCombat(true)
write("healthDecimalTrim", false)
assert(pct(boss) == "41.2%", "a combat change waits")
env.SetCombat(false)
env.RunTimers()
assert(pct(boss) == "41.20%" and pct(target) == "55.6%", "off restores the fixed places: " .. tostring(pct(boss)))
write("healthDecimalBoss", false)
write("healthDecimal", false)
assert(pct(target) == "56%", "the whole percent is back: " .. tostring(pct(target)))
clean()

-- Tracked debuffs: enemies only, with faction changes, the +N count and the crest's filters.
write("target.auraFilter", "both")
local groups = target.auras.container._groups
write("target.auraTracked", "1459, 589")
write("target.auraTrackedDebuffs", true)
assert(groups.debuffs.candidates.includeSpellIDs[589] and groups.buffs.candidates == nil, "an enemy shows only tracked debuffs")
assert(target.auras.overflow.debuffs.ghost._groups.count.candidates.includeSpellIDs[589], "the +N count follows")
env._units.target.assist = true
env.FireEvent("UNIT_FACTION", "target")
assert(groups.debuffs.candidates == nil, "a friend's debuffs show as usual")
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 2223, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(groups.debuffs.candidates.includeSpellIDs[1459], "a new enemy target is tracked again")
write("target.auraTrackedOnly", true)
assert(groups.buffs.candidates == nil, "tracked buffs still wait for a friend")
write("target.auraTrackedOnly", false)
write("target.auraTrackedDebuffs", false)
assert(groups.debuffs.candidates == nil, "off restores every debuff")
write("target.auraTracked", "")
clean()

-- Text bar: carved from the frame, at the bottom, the top or apart, with its texts, icon and strata.
local focus = ns.Frames.Get("focus").views[1]
U.SetUnit(env, "focus", { name = "Elunara", class = "MAGE", level = 60, health = 2530, healthMax = 4010, isPlayer = true, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
local before = focus.geometry
local bodyH, healthY = before.panel.h, before.health.y
write("focus.textBar", true)
local bar = focus.textBar
assert(bar and bar:IsShown() and focus.barRect.h == 16 and same(focus.barRect.y, bodyH - 16), "the strip takes the frame's bottom 16 units")
assert(same(focus.geometry.panel.h, bodyH - 16), "the frame's body gives it the room")
local carvedY = focus.geometry.health.y
write("focus.textBarLeft.textFormat", "[name] > [target]")
write("focus.textBarRight.textFormat", "[c:ff8800][hp:pct][/c]")
assert(U.Shown(env, focus.textBarLeft):find("Elunara > ", 1, true), "the left text: " .. U.Shown(env, focus.textBarLeft))
assert(U.Shown(env, focus.textBarRight):find("63%", 1, true) and U.Shown(env, focus.textBarRight):find("|cffff8800", 1, true), "the right text, coloured: " .. U.Shown(env, focus.textBarRight))
assert(focus.textBarCenter == nil or not focus.textBarCenter:IsShown(), "a blank slot stays hidden")
env._units.focus.health = 1203
env.FireEvent("UNIT_HEALTH", "focus")
assert(U.Shown(env, focus.textBarRight):find("30%", 1, true), "health events update the strip: " .. U.Shown(env, focus.textBarRight))
U.SetUnit(env, "focustarget", { name = "Valerin", level = 60, health = 1, healthMax = 1, reaction = 5 })
env.FireEvent("UNIT_TARGET", "focus")
assert(U.Shown(env, focus.textBarLeft):find("Elunara > Valerin", 1, true), "the unit's target follows: " .. U.Shown(env, focus.textBarLeft))
write("focus.textBarIcon", "LEFT")
local points = W.Calls(bar.inner, "SetPoint")
assert(bar.icon:IsShown() and points[#points - 1][4] > W.LastCall(bar.icon, "SetSize")[1], "the class icon takes the left end and the texts move past it")
U.SetUnit(env, "focus", { name = "Gorbash", level = 60, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
assert(not bar.icon:IsShown() and U.Shown(env, focus.textBarLeft):find("Gorbash", 1, true), "a unit change rereads the icon and texts")
write("focus.textBarPlace", "TOP")
assert(focus.barRect.y == 0 and same(focus.geometry.health.y, carvedY + 16) and focus.geometry.panel.y == 16, "at the top the body moves down")
write("focus.textBarPlace", "BELOW")
write("focus.textBarWidth", 120)
assert(focus.barRect.w == 120 and same(focus.barRect.x, (before.panel.w - 120) / 2 + before.panel.x) and same(focus.geometry.panel.h, bodyH - 20), "apart, the strip is centred at its own width with a gap")
write("focus.textBarStrata", "HIGH")
assert(W.LastCall(bar, "SetFrameStrata")[1] == "HIGH", "the strip takes its strata")
write("focus.textBarStrata", "")
assert(W.LastCall(bar, "SetFrameStrata")[1] == focus.parent:GetFrameStrata(), "the frame's strata again")
env.SetCombat(true)
write("focus.textBar", false)
assert(bar:IsShown(), "a combat change waits")
env.SetCombat(false)
env.RunTimers()
assert(not bar:IsShown() and not focus.textBarLeft:IsShown() and same(focus.geometry.panel.h, bodyH) and focus.geometry.health.y == healthY, "off restores the frame exactly")
clean()

-- The preview shows the strip, the boss cast size, trimmed decimals and the tracked debuffs.
write("edit", "focus")
write("focus.textBar", true)
write("focus.textBarIcon", "RIGHT")
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.focus
assert(sample.textBar and sample.textBar:IsShown() and U.Shown(env, sample.textBarLeft):find("Elunara", 1, true) and sample.textBar.icon:IsShown(), "the preview draws the strip with its sample")
write("focus.textBar", false)
pane:Refresh()
assert(not sample.textBar:IsShown(), "the preview clears it")
write("edit", "target")
pane:Refresh()
assert(pane.auraChips.target and pane.auraChips.target:IsShown(), "the full sample grid shows its +N chip")
write("target.auraTracked", "57723")
write("target.auraTrackedDebuffs", true)
pane:Refresh()
assert(not pane.auraChips.target:IsShown(), "the preview drops untracked debuffs, and the +N chip with them")
write("target.auraTrackedDebuffs", false)
write("healthDecimal", true)
write("healthDecimalTrim", true)
write("edit", "boss")
write("boss.castbarHeight", 16)
pane:Refresh()
assert(pane.casts.boss and same(W.LastCall(pane.casts.boss.frame, "SetSize")[2], 22), "the preview's boss cast takes its height")
assert(not U.Shown(env, pane.views.boss.healthText):find("%.0%%"), "the preview trims zeros: " .. U.Shown(env, pane.views.boss.healthText))
clean()

print("test-unitframes-parity-r4a: ok")
