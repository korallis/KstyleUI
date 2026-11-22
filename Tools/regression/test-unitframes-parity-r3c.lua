-- test-unitframes-parity-r3c.lua: round 3c's text offsets, power bar above health on a plate, power text position and colour, prediction textures and placement, overshield glow, absorb bar, lost maximum health, spell cost, five-second spark, mana in forms, druid bar text, extra text width and colour tags keep v0.2.8 looks and regions, then work switched on, follow their events and restore when off.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {} },
	setup = function(e)
		e._lost = 0.2
		e.GetUnitTotalModifiedMaxHealthPercent = function() return e._lost end
		e._costs = { [116] = { { type = 0, cost = 400 } }, [6807] = { { type = 1, cost = 15 } } }
		e.C_Spell = e.C_Spell or {}
		e.C_Spell.GetSpellPowerCost = function(id) return e._costs[id] end
	end,
})
local Settings, Widgets = ns.Settings, K.Widgets

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function plain(value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

-- Old profiles keep today's look: every new setting is at its default and no new region exists.
local NEW = {
	healthHeight = 0, incomingTexture = "", absorbTexture = "", healAbsorbTexture = "", absorbPlacement = "",
	healAbsorbPlacement = "", absorbGlow = false, absorbBar = "", absorbBarHeight = 3, maxHealthLoss = false,
	maxHealthAlpha = 0.5, powerAbove = false, powerTextAlign = "", powerTextColor = "",
}
for _, kind in ipairs(U.KINDS) do
	for key, value in pairs(NEW) do
		assert(Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
	local snapshot = Settings.Snapshot(kind)
	for key in pairs(Settings.defaults[kind]) do
		if key ~= "fonts" and snapshot[key] ~= nil then
			assert(snapshot[key] == Settings.Value(kind, key), kind .. "." .. key .. ": the snapshot's default path matches Value")
		end
	end
	for _, element in ipairs(Settings.TEXTS) do
		assert(snapshot.fonts[element].x == 0 and snapshot.fonts[element].y == 0, kind .. " " .. element .. " text has no offset")
	end
	for _, view in ipairs(ns.Frames.Get(kind).views) do
		for _, field in ipairs({ "shieldGlow", "absorbBar", "lossBar", "costBar", "manaSpark", "nudged" }) do
			assert(view[field] == nil, kind .. " makes no " .. field .. " until an option needs it")
		end
	end
end
assert(not Settings.Value("player", "powerCost") and not Settings.Value("player", "manaSpark") and not Settings.Value("player", "powerMana"), "player power options start off")
assert(Settings.Resource("manaText") == "none" and Settings.Resource("manaTextAlign") == "", "the druid bar writes no text")

local rows = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then rows[row.key] = row end
end
for _, kind in ipairs(U.KINDS) do
	for _, key in ipairs({ "powerAbove", "powerTextAlign", "absorbGlow", "absorbBar", "maxHealthLoss", "fonts.name.x", "fonts.level.y", "extra1.width" }) do
		assert(rows[kind .. "." .. key], kind .. " has a " .. key .. " row")
	end
end
assert(rows["player.powerCost"] and rows["player.manaSpark"] and rows["player.powerMana"] and not rows["target.powerCost"], "spell cost, the spark and mana in forms are player rows")
assert(rows["resource.manaText"] and rows["resource.manaTextAlign"], "the druid bar has text rows")

U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100,
	reaction = 2, canAttack = true, absorb = 500, isPlayer = true, class = "WARRIOR" })
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
local target = ns.Frames.Get("target").views[1]
local player = ns.Frames.Get("player").views[1]

-- Text offsets move each text once, a text anchored to another moves with it, and zero restores the point.
local function point(region)
	local p, rel, rp, x, y = region:GetPoint(1)
	return p, rel, rp, x or 0, y or 0
end
local _, _, _, nx, ny = point(target.name)
write("target.fonts.name.x", 10)
write("target.fonts.name.y", -4)
local _, rel, _, ax, ay = point(target.name)
assert(rel == target.parent and near(ax, nx + Widgets.Snap(target.parent, 10)) and near(ay, ny + Widgets.Snap(target.parent, -4)), "the name moves by its offsets")
write("target.fonts.name.x", 0)
write("target.fonts.name.y", 0)
_, _, _, ax, ay = point(target.name)
assert(near(ax, nx) and near(ay, ny), "zero offsets restore the name's point")
-- Power bar above health on a plate; the Medallions slab keeps its own band order and bar heights.
local s = Settings.Snapshot("player")
s.form, s.powerAbove, s.portrait = "plate", true, false
local plate = ns.Geometry.Frame(s, 260, 64, 1)
assert(plate.power.y < plate.health.y and (not plate.trackLine or plate.trackLine.y < plate.health.y), "a plate's power row and its rule move above the health track")
assert(not plate.powerText or plate.powerText.y + plate.powerText.h <= plate.health.y + 1e-6, "the power text moves with its row")

-- Power text position and colour, kept through power type changes, restored when off.
write("player.powerTextAlign", "CENTER")
assert(player.powerText:GetJustifyH() == "CENTER" and player.powerFillText:GetJustifyH() == "CENTER", "the power text centres")
write("player.powerTextAlign", "")
assert(player.powerText:GetJustifyH() == "RIGHT", "off restores the style's alignment")
write("player.powerTextCustom", { r = 1, g = 0, b = 0 })
write("player.powerTextColor", "custom")
local r, gg, b = player.powerText:GetTextColor()
assert(r == 1 and gg == 0 and b == 0, "the power text takes the custom colour")
env.FireEvent("UNIT_DISPLAYPOWER", "player")
r, gg, b = player.powerText:GetTextColor()
assert(r == 1 and gg == 0 and b == 0, "a power type change keeps the colour")
write("player.powerTextColor", "")
r, gg, b = player.powerText:GetTextColor()
assert(not (r == 1 and gg == 0 and b == 0), "off restores the power text's own colour")

-- Absorb placement from the bar's end shows the whole shield, unclamped.
write("target.absorbPlacement", "END")
local p, anchor, rp = target.absorb:GetPoint(1)
assert(anchor == target.health and p == rp, "shields draw back from the bar's own end")
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(plain(W.LastCall(target.absorb, "SetValue")[1]) == 500, "the full shield amount fills from the end")
write("target.absorbPlacement", "")
_, anchor = target.absorb:GetPoint(1)
assert(anchor == target.incoming:GetStatusBarTexture(), "off chains shields after incoming heals again")

-- Overshield glow: made on first use, lit by the calculator's clamp flag, readable or secret.
write("target.absorbGlow", true)
local glow = assert(target.shieldGlow, "the glow is made when switched on")
assert(glow:IsShown() and glow:GetAlpha() == 0, "no overshield, no light")
env._units.target.overshield = true
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(glow:GetAlpha() == 1, "an overshield lights the bar's end")
env._units.target.overshield = env.Secret(true)
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(W.LastCall(glow, "SetAlphaFromBoolean"), "a secret flag goes to the engine")
write("target.absorbs", false)
write("target.healPrediction", false)
env._units.target.overshield = true
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(glow:IsShown() and glow:GetAlpha() == 1 and not target.absorb:IsShown(), "the glow works with the shield overlay and incoming heals off")
env._units.target.overshield = nil
write("target.absorbs", true)
write("target.healPrediction", true)
write("target.absorbGlow", false)
assert(not glow:IsShown(), "off hides the glow")

-- Absorb bar along the health bar.
write("target.absorbBar", "TOP")
local strip = assert(target.absorbBar, "the absorb bar is made when chosen")
assert(strip:IsShown() and plain(W.LastCall(strip, "SetValue")[1]) == 500, "it fills with the unit's shields")
local sp, sa, srp = strip:GetPoint(1)
assert(sp == "TOPLEFT" and sa == target.health and srp == "TOPLEFT", "it runs along the health bar's top")
write("target.absorbBarHeight", 6)
assert(strip.opts.height == 6, "its height follows the setting")
env._units.target.absorb = 800
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(plain(W.LastCall(strip, "SetValue")[1]) == 800, "UNIT_ABSORB_AMOUNT_CHANGED refills it")
write("target.healPrediction", false)
env._units.target.absorb = 900
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
assert(strip:IsShown() and plain(W.LastCall(strip, "SetValue")[1]) == 900, "the absorb bar works with incoming heals off")
write("target.healPrediction", true)
write("target.absorbBar", "")
assert(not strip:IsShown(), "None hides it")

-- Heal absorbs from the bar's start.
write("target.healAbsorbs", true)
write("target.healAbsorbPlacement", "START")
p, anchor, rp = target.healAbsorb:GetPoint(1)
assert(anchor == target.health and p == rp, "heal absorbs draw from the bar's start")
write("target.healAbsorbPlacement", "")
_, anchor = target.healAbsorb:GetPoint(1)
assert(anchor == target.health:GetStatusBarTexture(), "off draws them back from the fill's end")
write("target.healAbsorbs", false)

-- Lost maximum health shortens the fill and marks the lost part, on its own event.
write("target.maxHealthLoss", true)
local loss = assert(target.lossBar, "the lost part is marked")
local _, _, top = U.Bar(env, target.health)
assert(near(top, 4000 / 0.8) and loss:IsShown() and W.LastCall(loss, "SetValue")[1] == 0.2, "the fill shortens by the lost share")
env._lost = 0
env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "target", env.Secret(0))
_, _, top = U.Bar(env, target.health)
assert(top == 4000 and not loss:IsShown(), "UNIT_MAX_HEALTH_MODIFIERS_CHANGED restores the full fill")
env._lost = env.Secret(0.3)
env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "target", env._lost)
_, _, top = U.Bar(env, target.health)
assert(top == 4000 and not loss:IsShown(), "a secret share marks nothing")
env._lost = 0.2
write("target.maxHealthLoss", false)
env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "target", 0.2)
_, _, top = U.Bar(env, target.health)
assert(top == 4000 and not loss:IsShown(), "off restores the range and stops listening")

-- Spell cost and the five-second spark listen to casts only while switched on.
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-0", 116)
assert(player.costBar == nil, "no cost mark while off")
write("player.powerCost", true)
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
local cost = assert(player.costBar, "a mana spell marks its cost")
local value, _, max = U.Bar(env, cost)
assert(cost:IsShown() and value == 400 and max == 4000, "the cost covers its share of the bar: " .. tostring(value))
local cp, crel = cost:GetPoint(1)
assert(crel == player.power:GetStatusBarTexture() and cp == "RIGHT", "it eats back from the fill's end")
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
assert(not cost:IsShown(), "the mark clears when the cast ends")
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", env.Secret(116))
assert(not cost:IsShown(), "a secret spell is refused")
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 6807)
assert(not cost:IsShown(), "a cost in another power marks nothing")
write("player.manaSpark", true)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 116)
local spark = assert(player.manaSpark, "spending mana starts the spark")
assert(spark:IsShown() and spark.group:IsPlaying(), "the spark sweeps")
spark.group:Stop()
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", 6807)
assert(not spark.group:IsPlaying(), "a cast that spends no mana starts no spark")
write("player.powerCost", false)
write("player.manaSpark", false)
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-6", 116)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-6", 116)
assert(not cost:IsShown() and not spark.group:IsPlaying(), "off stops listening")

-- Mana in forms, with the druid bar showing the form's power and its text.
local me = env._units.player
me.class, me.powerType, me.powerToken, me.power, me.powerMax = "DRUID", 3, "ENERGY", 60, 100
me.powers, me.powerMaxes = { [0] = 2500, [3] = 60 }, { [0] = 5000, [3] = 100 }
env.FireEvent("UNIT_DISPLAYPOWER", "player")
write("resource.manaText", "percent")
local res = ns.Resource.state
assert(res.showMana and res.text and res.text:IsShown(), "the druid bar writes its text")
write("player.powerMana", true)
value, _, max = U.Bar(env, player.power)
assert(value == 2500 and max == 5000, "the power bar keeps showing mana in a form")
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
value = U.Bar(env, player.power)
assert(value == 2500, "power updates keep mana")
assert(res.flipped == 3, "the druid bar shows the form's power")
local rv, _, rmax = U.Bar(env, res.mana)
assert(rv == 60 and rmax == 100, "the druid bar fills with energy")
write("player.powerMana", false)
value, _, max = U.Bar(env, player.power)
assert(value == 60 and max == 100 and not res.flipped, "off shows the form's power again")
write("resource.manaText", "none")
assert(not res.text:IsShown(), "None hides the druid bar text")
me.class, me.powerType, me.powerToken, me.power, me.powerMax, me.powers, me.powerMaxes = "HUNTER", 0, "MANA", 2000, 4000, nil, nil
env.FireEvent("UNIT_DISPLAYPOWER", "player")

-- Extra text width and colour tags.
write("target.extra1.textFormat", "[c:ff8800][name][/c]")
assert(U.Shown(env, target.extra1) == "|cffff8800Ogre|r", "a colour tag colours its part: " .. U.Shown(env, target.extra1))
local full = W.LastCall(target.extra1, "SetWidth")[1]
write("target.extra1.width", 50)
assert(near(W.LastCall(target.extra1, "SetWidth")[1], Widgets.Snap(target.parent, target.parent:GetWidth() * 0.5)) and full > W.LastCall(target.extra1, "SetWidth")[1], "the text keeps to half the frame's width")
write("target.extra1.width", 100)
write("target.extra1.textFormat", "")

-- The preview shows each option.
write("edit", "player")
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.player
write("player.absorbGlow", true)
write("player.absorbBar", "BOTTOM")
write("player.maxHealthLoss", true)
write("player.powerCost", true)
write("player.manaSpark", true)
write("player.powerTextColor", "custom")
write("player.fonts.name.x", 12)
pane:Refresh()
assert(sample.shieldGlow:IsShown() and sample.absorbBar:IsShown() and sample.lossBar:IsShown(), "the preview shows the glow, absorb bar and lost health")
assert(sample.costBar:IsShown() and sample.manaSpark:IsShown(), "the preview shows the spell cost and spark")
assert(sample.name.nudge[1] == 12, "the preview takes the offset")
r = sample.powerText:GetTextColor()
assert(r == 1, "the preview colours the power text")
for _, key in ipairs({ "absorbGlow", "maxHealthLoss", "powerCost", "manaSpark" }) do write("player." .. key, false) end
write("player.absorbBar", "")
pane:Refresh()
assert(not sample.shieldGlow:IsShown() and not sample.absorbBar:IsShown() and not sample.lossBar:IsShown() and not sample.costBar:IsShown() and not sample.manaSpark:IsShown(), "the preview clears them when off")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-unitframes-parity-r3c: ok")
