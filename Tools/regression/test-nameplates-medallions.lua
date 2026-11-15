-- test-nameplates-medallions.lua: under the Medallions HUD style a friendly player's plate carries a painted badge over its name, the target's brackets turn steel with a soft glow at each corner and the level diamond turns steel, while every bar keeps Blizzard's size and anchor (#373); an enemy never wears a badge, and switching back to Frames restores every look.
local N = dofile("Tools/regression/nameplates_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local STEEL, STEEL_LIT = { 0.725, 0.757, 0.8 }, { 0.902, 0.925, 0.953 }

local function steel(region, tone)
	tone = tone or STEEL_LIT
	local v = region._state.VertexColor
	return v ~= nil and near(v[1], tone[1]) and near(v[2], tone[2]) and near(v[3], tone[3])
end

local env, K, ns = N.New()
local painted, cuts = true, {}
K.Medallions = {
	Portrait = function(region, unit, cut)
		cuts[#cuts + 1] = cut
		region:SetTexture("badge:" .. tostring(unit))
		return painted
	end,
}

N.Add(env, "nameplate1", { name = "Galestrider", level = 6, reaction = 2, canAttack = true })
N.Add(env, "nameplate2", { name = "Leduc", level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "PALADIN" })
N.Add(env, "nameplate3", { name = "Azuregos", level = -1, classification = "worldboss", reaction = 2, canAttack = true })
N.Target(env, "nameplate1")
env.RunTimers()
local enemy, friend, boss = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")

local function geometry(plate)
	local w, h = plate:GetSize()
	local point, relative, relativePoint, x, y = plate:GetPoint(1)
	local hw, hh = plate.barW, plate.barH
	return table.concat({ w, h, point, tostring(relative), relativePoint, x, y, hw, hh }, " ")
end

-- Frames: a plate builds nothing for the style, so its cost stays the Frames build's, and the brackets take the accent.
assert(friend.medBadge == nil and enemy.brackets.sides[1].glow == nil, "Frames builds no badge and no glow")
eq(#cuts, 0, "Frames asks for no painted badge")
assert(not steel(enemy.brackets.sides[1].stroke), "Frames brackets take the accent")
ns.Plates.RestyleAll()
env.RunTimers()
local before = { geometry(enemy), geometry(friend), geometry(boss) }

K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
eq(K.HudStyle.Current(), "medallions", "the style switches out of combat")
eq(#env._errors, 0, "the switch raised no error: " .. tostring(env._errors[1]))

-- Every bar keeps Blizzard's size and anchor.
local after = { geometry(enemy), geometry(friend), geometry(boss) }
for i = 1, #before do
	eq(after[i], before[i], "plate " .. i .. " keeps its size and anchor")
end

-- The friendly player's badge: painted, unmasked, centred over the name.
local badge = friend.medBadge
assert(badge:IsShown(), "a friendly player wears a badge")
eq(cuts[#cuts], "badge", "the plate asks for the badge cut")
eq(badge._state.Texture[1], "badge:nameplate2", "the badge shows the unit's painted art")
eq(badge:GetNumMaskTextures(), 0, "painted art is pre-circled, so no mask")
assert(badge.ring:IsShown(), "a steel ring rings it")
local point, relative, relativePoint, x, y = badge:GetPoint(1)
eq(point, "BOTTOM", "the badge hangs from its bottom")
eq(relative, friend.name, "over the name")
eq(relativePoint, "TOP", "on the name's top")
assert(near(x, 0) and y > 0, "centred, with a gap above the name")
local w, h = unpack(N.Last(badge, "SetSize"))
assert(w >= 20 and w <= 24 and near(w, h), "the badge is 20 to 24 units and round: " .. tostring(w))
assert(not enemy.medBadge:IsShown() and not boss.medBadge:IsShown(), "an enemy wears no badge")

painted = false
friend:Refresh(true)
eq(badge:GetNumMaskTextures(), 1, "the engine portrait keeps its circle mask")

-- The target's brackets: steel, with a glow at each of the four corners.
for _, s in ipairs(enemy.brackets.sides) do
	assert(steel(s.stroke) and steel(s.top) and steel(s.bottom), s.side .. " bracket is steel")
	eq(#s.glow, 2, s.side .. " bracket glows at two corners")
	for _, glow in ipairs(s.glow) do
		assert(glow:IsShown(), s.side .. " glow shows")
		eq(glow._state.BlendMode and glow._state.BlendMode[1], "ADD", s.side .. " glow adds light")
	end
end

-- The level diamond: steel numbers, but the skull keeps its red.
assert(steel(enemy.level.rim, STEEL), "the plain diamond's rim is steel")
local r, g, b = enemy.levelText:GetTextColor()
assert(near(r, STEEL_LIT[1]) and near(g, STEEL_LIT[2]) and near(b, STEEL_LIT[3]), "the level reads in steel")
local hr, hg, hb = K.Tokens.Color("hostile")
r, g, b = boss.levelText:GetTextColor()
assert(near(r, hr) and near(g, hg) and near(b, hb), "the skull level stays red")

-- Back to Frames.
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
assert(not badge:IsShown() and not badge.ring:IsShown(), "Frames takes the badge away")
for _, s in ipairs(enemy.brackets.sides) do
	assert(not steel(s.stroke), s.side .. " bracket takes the accent again")
	for _, glow in ipairs(s.glow) do
		assert(not glow:IsShown(), s.side .. " glow hides")
	end
end
assert(not steel(enemy.level.rim, STEEL), "the diamond's rim is gilt again")
eq(geometry(enemy), before[1], "and the bar never moved")
eq(#env._errors, 0, "no error: " .. tostring(env._errors[1]))
eq(K.ErrorCount(), 0, "no addon error")
print("ok - test-nameplates-medallions")
