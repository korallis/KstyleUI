-- test-nameplates-medallions.lua: under the Medallions HUD style a plate draws KSTY-110's look: a 120 by 9 bar, the name in Inter SemiBold caps at the kit's 11-unit text floor, the level in Barlow at 12 units at the bar's left in its difficulty colour with no diamond, 22-unit debuffs, two 2-unit gunmetal ticks for the target with no glow, and a painted badge over a friendly player's name; a setting the player changed keeps the player's value, and switching back to Frames restores every look.
local N = dofile("Tools/regression/nameplates_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (tolerance or 1e-6)
end

local function tinted(region, r, g, b)
	local v = region._state.VertexColor
	return v ~= nil and near(v[1], r) and near(v[2], g) and near(v[3], b)
end

local env, K, ns = N.New()
local resolver = K.Medallions
local painted, cuts = true, {}
K.Medallions = {
	Portrait = function(region, unit, cut)
		cuts[#cuts + 1] = cut
		region:SetTexture("badge:" .. tostring(unit))
		return painted
	end,
}
env.GetCreatureDifficultyColor = function(level)
	if level >= 10 then
		return { r = 1, g = 0.1, b = 0.1 }
	end
	return { r = 0.25, g = 0.75, b = 0.25 }
end

N.Add(env, "nameplate1", { name = "Decrepit Darkhound", level = 12, reaction = 2, canAttack = true })
N.Add(env, "nameplate2", { name = "Leduc", level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "PALADIN" })
N.Add(env, "nameplate3", { name = "Azuregos", level = -1, classification = "worldboss", reaction = 2, canAttack = true })
N.Add(env, "nameplate6", { name = "Rotting Dead", level = 6, reaction = 2, canAttack = true })
N.Target(env, "nameplate1")
env.RunTimers()
local enemy, friend, boss, low = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3"), ns.Plates.Get("nameplate6")

local function face(text)
	local path, size, flags = text:GetFont()
	return path, size, flags
end

env.RunTimers()
eq(#env._errors, 0, "the switch raised no error: " .. tostring(env._errors[1]))

-- The bar: 120 by 9 units, snapped to the plate's pixels.
for _, plate in ipairs({ enemy, friend, boss }) do
	local w, h = plate:GetSize()
	assert(near(w, 120, 1) and near(h, 9, 1), "the plate is 120 by 9: " .. w .. " by " .. h)
	assert(near(plate.barW, 120, 1) and near(plate.barH, 9, 1), "the bar is 120 by 9: " .. plate.barW .. " by " .. plate.barH)
end

-- The name: Inter SemiBold caps, outlined, at the kit's 11-unit text floor.
local path, size, flags = face(enemy.name)
eq(path, K.Tokens.FontPath("InterSemiBold"), "the name is Inter SemiBold")
assert(near(size, 11, 0.6), "the name is 11 units: " .. tostring(size))
eq(flags, "OUTLINE", "the name is outlined over the world")

-- The level: Barlow, 12 units, at the bar's left outside the target tick, so it never moves with the target, and no diamond behind it.
path, size = face(enemy.levelText)
eq(path, K.Tokens.FontPath("BarlowSemiBold"), "the level is Barlow Semi Condensed")
eq(path, (K.Tokens.Font("number")), "the level is the Medallions number face")
assert(near(size, 12, 0.6), "the level is 12 units: " .. tostring(size))
local point, relative, relativePoint, x = enemy.levelText:GetPoint(1)
eq(point, "RIGHT", "the level hangs from its right")
eq(relative, enemy.health, "beside the bar")
eq(relativePoint, "LEFT", "on the bar's left")
assert(x <= -8 and x > -11, "clear of the target tick, a few units off the bar: " .. tostring(x))
for _, layer in ipairs(enemy.level.layers) do
	assert(not layer:IsShown(), "the diamond's layers are gone")
end

-- The level's colour: the creature's difficulty, lifted for legibility; the skull stays red; a world boss's marker wins.
local r, g, b = enemy.levelText:GetTextColor()
local dr, dg, db = K.Theme.Brighten(1, 0.1, 0.1)
assert(near(r, dr) and near(g, dg) and near(b, db), "a level 12 enemy reads in its difficulty colour")
r, g, b = low.levelText:GetTextColor()
dr, dg, db = K.Theme.Brighten(0.25, 0.75, 0.25)
assert(near(r, dr) and near(g, dg) and near(b, db), "a level 6 enemy reads in its own difficulty colour")
r, g, b = boss.levelText:GetTextColor()
local mr, mg, mb = K.Tokens.Color("nameHostile")
assert(near(r, mr) and near(g, mg) and near(b, mb), "the world boss's skull reads in its marker colour")

-- The target: two 2-unit gunmetal ticks a few units off each end of the bar, no arms and no glow.
local gun = { K.Tokens.Color("medText") }
for _, side in ipairs(enemy.brackets.sides) do
	local w, h = unpack(N.Last(side, "SetSize"))
	assert(near(w, 2, 0.6), side.side .. " tick is 2 units wide: " .. tostring(w))
	assert(near(h, enemy.barH + 4, 0.6), side.side .. " tick stands 2 units past the bar each way: " .. tostring(h))
	assert(not side.top:IsShown() and not side.bottom:IsShown(), side.side .. " tick has no arms")
	assert(tinted(side.stroke, gun[1], gun[2], gun[3]), side.side .. " tick is gunmetal")
	eq(side.glow, nil, side.side .. " tick has no glow")
	local ox = side.open._state.Offset
	assert(ox and math.abs(ox[1]) == K.Widgets.Snap(enemy, 3) and ox[2] == 0, side.side .. " tick appears in place, with no slide")
end
local tp, trel, trp, tx = enemy.brackets.sides[1]:GetPoint(1)
eq(tp, "RIGHT", "the left tick hangs from its right")
eq(trel, enemy.health, "beside the bar")
eq(trp, "LEFT", "off the bar's left end")
assert(tx < 0, "clear of the bar")

-- Debuffs: 22 units with 11-unit counts, read through the module's settings.
eq(ns.Settings.Get("debuffs.size"), 22, "debuffs are 22 units")
eq(ns.Settings.Get("debuffs.textSize"), 11, "their timers are 11 units")

-- A setting the player changed keeps the player's value, even the value the look replaced before it became the default.
local chosen = { ["debuffs.size"] = 29, ["debuffs.textSize"] = 13, ["name.size"] = 16, ["name.outline"] = "NONE", ["level.size"] = 13, ["level.outline"] = "NONE" }
for key, value in pairs(chosen) do
	K.Options.Write("Nameplates", key, value)
end
env.RunTimers()
for key, value in pairs(chosen) do
	eq(ns.Settings.Get(key), value, "a chosen " .. key .. " stays")
end
size, flags = select(2, face(enemy.name))
assert(near(size, 16, 0.6) and flags == "", "the name draws the chosen size and no outline: " .. tostring(size) .. " " .. tostring(flags))
size, flags = select(2, face(enemy.levelText))
assert(near(size, 13, 0.6) and flags == "", "the level draws the chosen size and no outline: " .. tostring(size) .. " " .. tostring(flags))

-- The friendly player's badge: painted, unmasked, centred over the name.
local badge = friend.medBadge
assert(badge:IsShown(), "a friendly player wears a badge")
eq(cuts[#cuts], "badge", "the plate asks for the badge cut")
eq(badge._state.Texture[1], "badge:nameplate2", "the badge shows the unit's painted art")
eq(badge:GetNumMaskTextures(), 0, "painted art is pre-circled, so no mask")
assert(badge.ring:IsShown(), "a ring rings it")
point, relative, relativePoint = badge:GetPoint(1)
eq(point, "BOTTOM", "the badge hangs from its bottom")
eq(relative, friend.name, "over the name")
eq(relativePoint, "TOP", "on the name's top")
local w, h = unpack(N.Last(badge, "SetSize"))
assert(w >= 20 and w <= 24 and near(w, h), "the badge is 20 to 24 units and round: " .. tostring(w))
assert(not enemy.medBadge:IsShown() and not boss.medBadge:IsShown(), "an enemy wears no badge")

painted = false
friend:Refresh(true)
eq(badge:GetNumMaskTextures(), 1, "the engine portrait keeps its circle mask")
painted = true
badge:SetTexture("engine")
env.FireEvent("UNIT_PORTRAIT_UPDATE", "nameplate2")
eq(badge._state.Texture[1], "badge:nameplate2", "the portrait event repaints the badge")
eq(badge:GetNumMaskTextures(), 0, "and drops the mask")

-- Lee's warlock out with an imp: an undead warlock friend wears the real Scourge warlock badge, and the imp's
-- friendly plate wears none.
K.Medallions = resolver
env.UnitRace = function(unit)
	local u = env._units[unit]
	if u and u.race then
		return u.race, u.race, 5
	end
end
env.UnitSex = function()
	return 2
end
env.C_Secrets = env.C_Secrets or {}
env.C_Secrets.ShouldUnitIdentityBeSecret = function()
	return false
end
N.Add(env, "nameplate4", { name = "Morvane", level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "WARLOCK", race = "Scourge" })
N.Add(env, "nameplate5", { name = "Zevrim", level = 58, reaction = 5, canAttack = false })
env.RunTimers()
local lee, imp = ns.Plates.Get("nameplate4"), ns.Plates.Get("nameplate5")
assert(lee.medBadge:IsShown(), "the undead warlock wears a badge")
assert(tostring(lee.medBadge._state.Texture[1]):find("scourge_warlock_male", 1, true), "the Scourge warlock badge: " .. tostring(lee.medBadge._state.Texture[1]))
assert(not (imp.medBadge and imp.medBadge:IsShown()), "the imp wears no badge")
r, g, b = imp.levelText:GetTextColor()
local er, eg, eb = K.Tokens.Color("medText")
assert(near(r, er) and near(g, eg) and near(b, eb), "a friendly level takes the Medallions label colour, not a difficulty")

eq(#env._errors, 0, "no error: " .. tostring(env._errors[1]))
eq(K.ErrorCount(), 0, "no addon error")
print("ok - test-nameplates-medallions")
