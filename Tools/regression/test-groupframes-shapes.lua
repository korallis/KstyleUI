-- test-groupframes-shapes.lua: everything drawn on a group frame keeps the kit's 3-unit chamfered tile. The target highlight, the threat glow and the dispel highlight use the kit's chamfer, bevel and shadow textures, never a square colour box; debuff icons are the kit's chamfered icon tiles, masked and sized in whole pixels; and their chrome waits while aura data is secret.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function setup(opts)
	local env, K, ns = G.New(opts)
	local party = {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", threat = 3 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER" },
	}
	G.SetRoster(env, "party", party)
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	local function content(unit)
		local i = 1
		while ns.Headers.party._attributes["child" .. i] do
			local button = ns.Headers.party._attributes["child" .. i]
			if button._attributes.unit == unit and button._shown then
				return ns.Button.Content(button)
			end
			i = i + 1
		end
	end
	return env, K, ns, party, content
end

-- Every texture region made on an object and on the frames made on it.
local function textures(object)
	local out = {}
	for _, o in ipairs(A.Descendants(object)) do
		if o:GetObjectType() == "Texture" then
			out[#out + 1] = o
		end
	end
	return out
end

local function asset(texture)
	local state = texture._state.Texture
	return state and state[1]
end

local function kitPaths(K, names)
	local out = {}
	for _, name in ipairs(names) do
		out[(K.Tokens.Texture(name))] = name
	end
	return out
end

-- Every textured piece is one of the named kit textures. A flat colour piece may only be a straight
-- line one border thick running between two kit corner pieces, as the kit's chrome draws its bevel
-- edges, so no square corner sticks out past the chamfer. Returns the count per texture and the
-- number of straight lines.
local function kitOnly(K, list, names, owner, what)
	assert(#list > 0, what .. " draws something")
	local allowed = kitPaths(K, names)
	local border = K.Widgets.Border(owner)
	local counts, lines = {}, 0
	for _, texture in ipairs(list) do
		if texture._state.ColorTexture then
			lines = lines + 1
			eq(texture._height or texture._width, border, what .. ": a straight line is one border thick")
			eq(#texture._points, 2, what .. ": a straight line has two ends")
			for _, point in ipairs(texture._points) do
				assert(allowed[asset(point[2])], what .. ": a straight line runs between two chamfered corner pieces")
			end
		else
			local name = allowed[asset(texture)]
			assert(name, what .. ": " .. tostring(asset(texture)) .. " is not one of the kit's chamfer textures")
			counts[name] = (counts[name] or 0) + 1
		end
	end
	return counts, lines
end

local function color(texture)
	local c = texture._state.VertexColor
	return c and c[1], c and c[2], c and c[3], c and c[4]
end

local env, K, ns, party, content = setup({ width = 2560, height = 1440 })
local px = K.Scale.Pixel(1)
local function whole(units, what)
	local pixels = units / px
	assert(math.abs(pixels - math.floor(pixels + 0.5)) < 1e-6, what .. " is " .. tostring(pixels) .. " pixels, not a whole number")
end

local tank, healer = content("party1"), content("party2")

-- The target highlight: the kit's tile bevel lines in the accent, faded in by the secret target flag.
env._target = true
env.UnitIsUnit = function(a, b)
	return env.Secret(a == "party2" and b == "target")
end
env.FireEvent("PLAYER_TARGET_CHANGED")
local shown = healer.target._state.AlphaFromBoolean
assert(shown and env.issecretvalue(shown[1]), "the target highlight follows the secret target flag")
local counts, lines = kitOnly(K, textures(healer.target), { "bevelTileOuter", "bevelTileInner" }, healer.target, "the target highlight")
eq(counts.bevelTileOuter, 4, "the target highlight has the outer bevel line's corners")
eq(counts.bevelTileInner, 4, "and the inner one's, two lines thick like the old outline")
eq(lines, 8, "with four straight sides to each line")
whole(K.Widgets.Border(healer.target), "a side's thickness")
local ar, ag, ab = ns.Style.Accent()
for _, texture in ipairs(textures(healer.target)) do
	local r, g, b, a = color(texture)
	assert(near(r, ar) and near(g, ag) and near(b, ab) and near(a, 1), "the target highlight is the accent")
end
local corner = textures(healer.target)[1]
local cw = corner:GetSize()
eq(cw, (healer.chrome.outer[1]:GetSize()), "the ring's corners are the size of the tile's own bevel corners")
eq(corner._points[1][1], "TOPLEFT", "the first corner sits at the top left")
eq(corner._points[1][4], 0, "inside the frame, flush with its edge")

-- The threat border: the kit's selection glow, in the threat colour unit frames and nameplates use,
-- behind the frame's tile.
eq(tank.threat:IsShown(), true, "the tank with aggro shows the threat glow")
local _, flat = kitOnly(K, textures(tank.threat), { "shadow" }, tank.threat, "the threat glow")
eq(flat, 0, "the threat glow is all falloff texture")
local hr, hg, hb = K.Theme.ThreatColor(3)
for _, texture in ipairs(textures(tank.threat)) do
	local r, g, b = color(texture)
	assert(near(r, hr) and near(g, hg) and near(b, hb), "status 3 glows in the hostile token")
end
assert(tank.threatGlow and tank.threatGlow.holder:GetFrameLevel() < tank:GetFrameLevel(), "the glow sits behind the frame's tile")
party[1].threat = 1
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
local r, g, b = color(textures(tank.threat)[1])
local nr, ng, nb = K.Tokens.Color("neutral")
assert(near(r, nr) and near(g, ng) and near(b, nb), "status 1 recolours the glow in the neutral token")

-- The dispel highlight: a chamfered wash and the tile bevel lines, all coloured by the engine.
local slot = tank.auras._slots.dispel.frame
local registered = {}
for _, entry in ipairs(slot._aura.dispel) do
	registered[#registered + 1] = entry.texture
end
counts, lines = kitOnly(K, registered, { "chamferTile", "bevelTileOuter", "bevelTileInner" }, slot, "the dispel highlight")
eq(counts.chamferTile, 9, "the wash is the chamfered tile")
eq(counts.bevelTileOuter, 4, "the border has the outer bevel line's corners")
eq(counts.bevelTileInner, 4, "and the inner one's")
eq(lines, 8, "and their straight sides")
for _, texture in ipairs(registered) do
	if asset(texture) == (K.Tokens.Texture("chamferTile")) then
		eq(texture:GetAlpha(), 0.16, "the wash is faint")
	end
end
kitOnly(K, textures(slot), { "chamferTile", "bevelTileOuter", "bevelTileInner" }, slot, "everything on the dispel slot")

-- Debuff icons: the kit's chamfered icon tile, the icon two borders in and masked, the swipe masked.
local group = tank.auras._groups.debuffs
local button = group.frames[1]
local mask = K.Tokens.Texture("iconMask")
local icon = button._aura.icon
eq(icon:GetNumMaskTextures(), 1, "the icon is masked")
eq(asset(icon:GetMaskTexture(1)), mask, "by the kit's chamfered icon mask")
local swipe = button._aura.cooldown._state.SwipeTexture
eq(swipe and swipe[1], mask, "the duration swipe uses the same mask")
local tile = kitPaths(K, { "chamferTile", "bevelTileOuter", "bevelTileInner" })
local seen = {}
for _, texture in ipairs(textures(button)) do
	local name = tile[asset(texture)]
	if name then
		seen[name] = (seen[name] or 0) + 1
	end
end
assert((seen.chamferTile or 0) >= 9, "each icon sits on a chamfered tile")
assert((seen.bevelTileOuter or 0) >= 4 and (seen.bevelTileInner or 0) >= 4, "with the kit's double bevel edge")
local dispel = {}
for _, entry in ipairs(button._aura.dispel) do
	dispel[#dispel + 1] = entry.texture
end
counts = kitOnly(K, dispel, { "chamferTile" }, button, "the icon's debuff type border")
eq(counts.chamferTile, 9, "the debuff type colour fills a chamfered tile behind the icon")

-- Sizes in whole pixels at 1440p, where a unit is 1.33 pixels.
local bw, bh = button:GetSize()
whole(bw, "the icon width")
whole(bh, "the icon height")
whole(group.layout.elementWidth, "the layout's icon width")
whole(group.layout.elementHeight, "the layout's icon height")
whole(group.layout.elementSpacing, "the layout's icon gap")
whole(group.layout.lineSpacing, "the layout's line gap")
local dispels = tank.auras._groups.dispels
whole(dispels.layout.elementWidth, "the dispellable icons' width")
assert(near(bw, group.layout.elementWidth), "the icons are as wide as the layout places them")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- While aura data is secret nothing touches an aura button, its chrome included; it restyles after.
local function calls(list)
	local n = 0
	for _, each in ipairs(list) do
		n = n + A.CallCount(each)
	end
	return n
end
local buttons = {}
for _, f in ipairs({ tank, healer }) do
	for _, key in ipairs({ "debuffs", "dispels" }) do
		for _, each in ipairs(f.auras._groups[key].frames) do
			buttons[#buttons + 1] = each
		end
	end
end
local before = calls(buttons)
env._aurasSecret = true
K.Callbacks.Fire("ThemeChanged")
K.Callbacks.Fire("ScaleChanged")
K.Widgets.RestyleAll()
K.Options.Write("GroupFrames", "party.auraSize", 24)
eq(#env._errors, 0, "no access to aura buttons while auras are secret: " .. tostring(env._errors[1]))
eq(calls(buttons), before, "no call reaches an aura button or anything on it while auras are secret")
env._aurasSecret = false
env.RunTimers()
assert(calls(buttons) > before, "the restyle runs once auras are readable")
whole((button:GetSize()), "the resized icon")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- The settings preview draws the same shapes.
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(300, 420)
local preview = K.Options.Preview("GroupFrames")(parent)
local sample = preview.partyFrames[2]
kitOnly(K, textures(sample.target), { "bevelTileOuter", "bevelTileInner" }, sample.target, "a sample's target highlight")
kitOnly(K, textures(sample.sampleDispel), { "chamferTile", "bevelTileOuter", "bevelTileInner" }, sample.sampleDispel, "a sample's dispel highlight")
kitOnly(K, textures(preview.partyFrames[1].threat), { "shadow" }, preview.partyFrames[1].threat, "a sample's threat glow")
local sampleIcon = preview.partyFrames[1].sampleAuras[1]
eq(asset(sampleIcon.art:GetMaskTexture(1)), mask, "sample debuff icons are masked like the real ones")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

print("groupframes shapes ok")
