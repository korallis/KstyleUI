-- test-groupframes-medallions.lua: under the Medallions HUD style the party wears painted badge medallions in a steel ring with no level badge or tile, the raid wears class-coloured tiles with the name on the fill and no portrait, the target ring turns steel, a painted badge drops the circle mask the engine portrait keeps, and switching back to Frames restores every look; a value the player changed from its default wins over the style's.
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
local STEEL_LIT = { 0.902, 0.925, 0.953 }

local painted, cuts = true, {}
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

K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
eq(K.HudStyle.Current(), "medallions", "the style switches out of combat")
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
	local r, g, b = f.name:GetTextColor()
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	assert(near(r, er) and near(g, eg) and near(b, eb), f.unit .. ": the name reads white on the fill")
	assert(f.tileless and not f.chrome.fill[5]:IsShown(), f.unit .. ": the fill is the tile")
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
	local gr, gg, gb = K.Tokens.Color("friendly")
	assert(near(color[1], gr) and near(color[2], gg) and near(color[3], gb), f.unit .. ": the bar is the friendly green again")
	local pieces = f.targetRing[1]
	local v = pieces[1]._state.VertexColor
	assert(not near(v[1], STEEL_LIT[1]) or not near(v[2], STEEL_LIT[2]), f.unit .. ": the target ring takes the accent again")
end)
eq(#env._errors, 0, "no error: " .. tostring(env._errors[1]))
eq(K.ErrorCount(), 0, "no addon error")
print("ok - test-groupframes-medallions")
