local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function last(object, method)
	for i = #object._calls, 1, -1 do
		local call = object._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

local function texture(region)
	local state = region._state.Texture
	return state and state[1]
end

local env, K, ns = G.New()
local Unit, Settings = ns.Unit, ns.Settings
local STEEL_LIT = { K.Tokens.Color("steelLit") }

local resolver = K.Medallions
local painted, cuts = false, {}
K.Medallions = {
	Portrait = function(region, unit, cut)
		cuts[#cuts + 1] = cut
		region:SetTexture("badge:" .. tostring(unit))
		return painted
	end,
}

local function each(kind, fn)
	local n = 0
	Unit.ForEach(function(f)
		if f.unit and f.kind == kind then
			n = n + 1
			fn(f)
		end
	end)
	assert(n > 0, "some " .. kind .. " frame has a unit")
end

local party = {
	{ name = "Thessaly", class = "PALADIN", health = 92, maxHealth = 100, role = "TANK" },
	{ name = "Brannoc", class = "HUNTER", health = 64, maxHealth = 100 },
	{ name = "Ilyra", class = "PRIEST", health = 100, maxHealth = 100, role = "HEALER" },
}
G.SetRoster(env, "party", party)
assert(K.Modules.Enable("GroupFrames"), "the module switches on")
env.RunTimers()
eq(#env._errors, 0, "Enable raised no error: " .. tostring(env._errors[1]))

-- Frames: nothing of the Medallions look.
eq(Settings.current.party.portrait, false, "Frames keeps the party without a portrait")
each("party", function(f)
	assert(not f.medBezel, f.unit .. ": Frames builds no steel bezel")
	eq(#cuts, 0, "Frames asks for no painted badge")
end)

-- The first look under Medallions may find every identity secret: the engine portrait keeps its one circle mask.
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
eq(K.HudStyle.Current(), "medallions", "the style switches out of combat")
each("party", function(f)
	eq(f.portrait:GetNumMaskTextures(), 1, f.unit .. ": a secret identity keeps one circle mask")
end)
painted = true
each("party", function(f)
	Unit.Refresh(f)
end)
eq(Settings.current.party.portrait, true, "Medallions gives the party its medallion")
eq(Settings.current.raid.textLayout, "INSIDE", "and puts the raid's name on the fill")

each("party", function(f)
	assert(f.showPortrait, f.unit .. ": the medallion shows")
	assert(f.medBezel and f.medBezel:IsShown(), f.unit .. ": the steel bezel rings it")
	assert(not f.level:IsShown() and not f.badge:IsShown(), f.unit .. ": no level badge sits on the medallion")
	assert(f.tileless and not f.chrome.fill[5]:IsShown(), f.unit .. ": the row stands bare, with no tile")
	eq(texture(f.portrait), "badge:" .. f.unit, f.unit .. ": the painted badge fills the medallion")
	eq(f.portrait:GetNumMaskTextures(), 0, f.unit .. ": painted art is pre-circled, so no mask")
end)
each("party", function(f)
	local role = env.UnitGroupRolesAssigned(f.unit)
	assert(f.pipped and not f.pipFill:IsShown(), f.unit .. ": colour-only pips stay hidden")
	if role ~= "NONE" then assert(f.role:IsShown(), f.unit .. ": the role has a shield, cross or blade") end
	assert(f.parts.icons.role.left + f.parts.icons.role.width <= f.parts.name.left, f.unit .. ": the pip comes before the name")
end)
for _, cut in ipairs(cuts) do
	eq(cut, "badge", "the party asks for the 64 px badge cut")
end

-- A unit whose identity is secret gets the engine portrait, which keeps its circle mask.
painted = false
each("party", function(f)
	Unit.Refresh(f)
	eq(f.portrait:GetNumMaskTextures(), 1, f.unit .. ": the engine portrait is masked to the circle")
end)
K.Medallions = nil
each("party", function(f)
	Unit.Refresh(f)
	eq(f.portrait._portraitUnit, f.unit, f.unit .. ": without the resolver the engine portrait stands in")
	eq(f.portrait:GetNumMaskTextures(), 1, f.unit .. ": masked")
end)

-- Role rings give way to the medallion.
K.Options.Write("GroupFrames", "party.roleRing", true)
env.RunTimers()
eq(Settings.current.party.roleRing, true, "a role ring the player turned on wins")
K.Options.Write("GroupFrames", "party.roleRing", false)
env.RunTimers()

-- Lee's character, an undead warlock, gets the real resolver's painted badge in its own row.
K.Medallions = resolver
env.UnitRace = function(unit)
	if unit == "player" then
		return "Undead", "Scourge", 5
	end
end
env.UnitSex = function()
	return 2
end
env.C_Secrets = env.C_Secrets or {}
env.C_Secrets.ShouldUnitIdentityBeSecret = function()
	return false
end
G.SetRoster(env, "party", party, { name = "Morvane", class = "WARLOCK" })
env.RunTimers()
local lee
Unit.ForEach(function(f)
	if f.unit == "player" then
		lee = f
	end
end)
assert(lee, "the party shows the player's own row")
eq(lee.portrait._state.Texture[1], resolver.PortraitPath("player", "badge"), "the undead warlock wears the resolver's badge")
assert(tostring(lee.portrait._state.Texture[1]):find("scourge_warlock_male", 1, true), "the badge file is the undead warlock's: " .. tostring(lee.portrait._state.Texture[1]))
eq(lee.portrait:GetNumMaskTextures(), 0, "the painted badge is pre-circled, so no mask")
local _, warlock = env.UnitClass("player")
eq(warlock, "WARLOCK", "the player is a warlock")
local ring = lee.ring._state.VertexColor
local wr, wg, wb = ns.Unit.ClassColor("WARLOCK")
assert(near(ring[1], wr) and near(ring[2], wg) and near(ring[3], wb), "the enamel ring is warlock violet")

-- The raid: class-coloured tiles, white names on the fill, no medallion, a steel target ring.
G.SetRoster(env, "raid", G.Members(10, function(i, m)
	m.health, m.maxHealth = 50 + i, 100
end))
env.RunTimers()
eq(#env._errors, 0, "the raid raised no error: " .. tostring(env._errors[1]))
each("raid", function(f)
	assert(not f.showPortrait, f.unit .. ": raid tiles carry no medallion")
	assert(f.parts.nameInside, f.unit .. ": the name sits on the fill")
	local _, class = env.UnitClass(f.unit)
	local c = G.CLASS_COLORS[class]
	local color = last(f.health, "SetStatusBarColor")
	assert(near(color[1], c[1]) and near(color[2], c[2]) and near(color[3], c[3]), f.unit .. ": the tile is the class colour")
	local ink = ns.Medallions.Inked(class)
	eq(ink, class ~= "SHAMAN" and class ~= "DEATHKNIGHT", f.unit .. ": " .. class .. " takes dark ink only on a light fill")
	local sr = f.name:GetShadowColor()
	if ink then
		assert(f.medInked and sr > 0.9, f.unit .. ": dark ink on " .. class .. " with a soft light shadow")
		local values = last(f.name, "SetTextColor")
		local cr = values and values[1]
		if env.issecretvalue(cr) then
			cr = env.Reveal(cr)
		end
		local dr = K.Tokens.Color("slabBottom")
		assert(near(cr, dr), f.unit .. ": the ink is near-black above the low-health line, got " .. tostring(cr))
		assert(f.medChip and f.medChip:IsShown(), f.unit .. ": the percent sits on its steel chip")
	else
		local r, g, b = f.name:GetTextColor()
		local er, eg, eb = K.Tokens.Color("textEmphasis")
		assert(near(r, er) and near(g, eg) and near(b, eb), f.unit .. ": the name reads white on the fill")
		assert(not f.medInked and sr < 0.1, f.unit .. ": with a dark shadow")
	end
	assert(f.tileless and not f.chrome.fill[5]:IsShown(), f.unit .. ": the fill is the tile")
	assert(f.medSlab and f.medSlab[5]:IsShown() and f.medSlab[5]:GetTexture() == (K.Tokens.Texture("medGroupTile")), f.unit .. ": the tile sits in the group tile slab material")
	local namePath, _, nameFlags = f.name:GetFont()
	eq(namePath, K.Tokens.FontPath("InterSemiBold"), f.unit .. ": the name is in the Medallions label face")
	eq(nameFlags == "OUTLINE", not ink, f.unit .. ": light ink takes an outline; dark ink takes a light shadow")
	eq(f.name:GetText(), K.Locale.Upper(f.name:GetText()), f.unit .. ": the fitted name stays in caps")
	local percentPath = f.healthText:GetFont()
	eq(percentPath, (K.Tokens.Font("number")), f.unit .. ": the percent follows the number role")
	assert(not f.health.sparkFrame, f.unit .. ": keep Medallions group bars spark-free like tooltip and tracked bars")
	for _, line in ipairs(f.targetRing) do
		for _, piece in ipairs(line) do
			local v = piece._state.VertexColor
			assert(near(v[1], STEEL_LIT[1]) and near(v[2], STEEL_LIT[2]) and near(v[3], STEEL_LIT[3]), f.unit .. ": the target ring is steel")
		end
	end
end)

-- The style lays its look over the defaults only: a value the player changed wins.
eq(Settings.current.raid.buffCount, 0, "the style drops the raid's own heals row")
K.Options.Write("GroupFrames", "raid.buffCount", 2)
env.RunTimers()
eq(Settings.current.raid.buffCount, 2, "a heals count the player chose wins")

-- Back to Frames: every look returns.
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
eq(Settings.current.party.portrait, false, "Frames takes the medallion away")
eq(Settings.current.raid.textLayout, "ABOVE", "and the raid's name goes back above the bar")
each("raid", function(f)
	local color = last(f.health, "SetStatusBarColor")
	local _, class = env.UnitClass(f.unit)
	local gr, gg, gb = K.Theme.ClassColor(class)
	assert(near(color[1], gr) and near(color[2], gg) and near(color[3], gb), f.unit .. ": the bar keeps its class colour")
	assert(not f.health.sparkFrame, f.unit .. ": keep group bars spark-free when returning to Frames")
	assert(not f.medSlab[5]:IsShown(), f.unit .. ": the slab material goes with the style")
	assert(f.name:GetFont() ~= K.Tokens.FontPath("InterSemiBold"), f.unit .. ": the name leaves the Medallions label face")
	eq(f.name:GetText(), f.rawName, f.unit .. ": in its own case")
	eq((f.healthText:GetFont()), (K.Tokens.Font("number")), f.unit .. ": the percent takes the number role")
	assert(not (f.medChip and f.medChip:IsShown()), f.unit .. ": no percent chip")
	assert(not f.medInked, f.unit .. ": no ink")
	if f.auraClip then
		eq(f.auraClip:GetAlpha(), 1, f.unit .. ": the debuffs show")
	end
	local pieces = f.targetRing[1]
	local v = pieces[1]._state.VertexColor
	assert(not near(v[1], STEEL_LIT[1]) or not near(v[2], STEEL_LIT[2]), f.unit .. ": the target ring takes the accent again")
end)
each("party", function(f)
	assert(not f.medBezel or not f.medBezel:IsShown(), f.unit .. ": no steel bezel")
end)

-- A theme change drops the cached ink choice, so a class whose colour changed is judged again.
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
eq(ns.Medallions.Inked("PRIEST"), true, "white priest tiles take dark ink")
local classColor = env.C_ClassColor and env.C_ClassColor.GetClassColor
local dark = { r = 0.2, g = 0.2, b = 0.3, GetRGB = function() return 0.2, 0.2, 0.3 end }
if classColor then
	env.C_ClassColor.GetClassColor = function(file)
		if file == "PRIEST" then
			return dark
		end
		return classColor(file)
	end
end
env.RAID_CLASS_COLORS.PRIEST = dark
K.Callbacks.Fire("ThemeChanged")
eq(ns.Medallions.Inked("PRIEST"), false, "after a theme change a dark priest colour takes white text")
eq(#env._errors, 0, "no error: " .. tostring(env._errors[1]))
eq(K.ErrorCount(), 0, "no addon error")
print("ok - test-groupframes-medallions")
