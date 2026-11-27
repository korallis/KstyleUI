-- test-actionbars-crest-melee-auras.lua: the warrior's, paladin's and rogue's crest marks as animated auras (the KSTY-51 plan, the captain's ask that everything a player tracks on the crest be an animated spell effect): every cooldown sigil on their rails and every perched or overlaid object with a sheet burns its own Blender aura; a class's own sigil keeps the colour baked into it while the racial and potion sigils every class shares take the rail's colour; a racial the character does not know draws flat and never loads its sheet (direction d-7cyxs7, art loaded only when needed); an object's light burns only inside its lit fill and takes the colour the strike's pick gives it.
local F = dofile("Tools/regression/crest_armory_fixture.lua")
local AB, New, Clean, Find = F.AB, F.New, F.Clean, F.Find

local ROOT = "Interface\\AddOns\\KstyleUI\\"

local function File(region)
	local state = region._state and region._state.Texture
	return state and state[1]
end

-- Every region under a piece whose texture is the given file.
local function Drawn(piece, path)
	local found = {}
	F.Walk(piece, function(region)
		if File(region) == path then found[#found + 1] = region end
	end)
	return found
end

local function Colour(region)
	local r, g, b = region:GetVertexColor()
	return string.format("%.3f,%.3f,%.3f", r, g, b)
end

local function Token(K, color)
	local r, g, b = K.Tokens.Color(color)
	return string.format("%.3f,%.3f,%.3f", r, g, b)
end

local function Sheet(kind, name)
	return ROOT .. "Media\\Textures\\Auras\\" .. kind .. "\\" .. name .. ".png"
end

-- Each class's rail: its own first cooldown sigil, Blood Fury (known, shared) and Berserking (a racial this character lacks).
local RAILS = {
	{ "WARRIOR", 1719, "Crossed", "gilt" },
	{ "PALADIN", 642, "Bubble", "white" },
	{ "ROGUE", 13877, "Flurry", "pipPriestGlow" },
}
for _, rail in ipairs(RAILS) do
	local class, spell, own, color = rail[1], rail[2], rail[3], rail[4]
	local env, K, ns = New(class, { spell, 20572 })
	local rim = assert(Find(ns, "crestCooldowns"), class .. " builds its cooldown rim")
	local mine = Drawn(rim, Sheet("Sigils", own))
	assert(#mine == 2, class .. ": its own " .. own .. " sigil burns its sheet as a fire and a still, got " .. #mine)
	for _, region in ipairs(mine) do
		assert(Colour(region) == "1.000,1.000,1.000", class .. ": its own sigil keeps the colour baked into its sheet")
	end
	local shared = Drawn(rim, Sheet("Sigils", "Axe"))
	assert(#shared == 2, class .. ": the shared Blood Fury sigil burns its sheet, got " .. #shared)
	for _, region in ipairs(shared) do
		assert(Colour(region) == Token(K, color), class .. ": a shared sigil takes the rail's colour " .. color .. ", got " .. Colour(region))
	end
	assert(#Drawn(rim, Sheet("Sigils", "Tusks")) == 0, class .. ": an unknown racial never loads its sheet")
	assert(#Drawn(rim, (K.Tokens.Texture("sigilTusks"))) == 1, class .. ": and draws its flat line art instead")
	Clean(env, K, class .. " rail")
end

-- The warrior's Battle Shout horn: its light burns inside the lit fill, in the piece's colour, on its own copy of the aura slot.
do
	local env, K, ns = New("WARRIOR", { 25289 })
	local horn = assert(Find(ns, "crestShout"), "the warrior builds the horn")
	local fire = assert(horn.lit.fire, "the horn has an aura fire")
	assert(File(fire) == Sheet("Effects", "Horn") and File(fire.still) == Sheet("Effects", "Horn"), "the horn burns its own sheet")
	local clip = fire:GetParent()
	local function Clips(frame)
		local call = AB.W.LastCall(frame, "SetClipsChildren")
		return call and call[1] == true
	end
	assert(Clips(clip) and Clips(fire.still:GetParent()), "the fire and the still burn inside clipped frames")
	local fill = horn.lit.bar:GetStatusBarTexture()
	local anchored = false
	for i = 1, clip:GetNumPoints() do
		local _, to = clip:GetPoint(i)
		anchored = anchored or to == fill
	end
	assert(anchored, "the fire's clip follows the fill's lit end, so the light drains with it")
	assert(Colour(fire) == Token(K, horn.spec.color), "the horn's light takes its piece's colour")
	assert(clip:GetParent() == horn.lit.flames.lit, "the fire burns on the aura slot's own copy")
	Clean(env, K, "horn")
end

-- The opening: the strike's pick swaps the weapon's sheet and recolours its light.
do
	local env, K, ns = New("WARRIOR", { 6673, 20662, 11585 })
	local opening = Find(ns, "crestOpening")
	env._usable[11585] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local fire = opening.lit.fire
	assert(File(fire) == Sheet("Effects", "Sword") and Colour(fire) == Token(K, "gilt"), "Overpower burns its sword's light in gilt")
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(File(fire) == Sheet("Effects", "Axe") and File(fire.still) == Sheet("Effects", "Axe"), "Execute taking over burns its axe's sheet")
	assert(Colour(fire) == Token(K, "plateHostile") and Colour(fire.still) == Token(K, "plateHostile"), "in Execute's red")
	Clean(env, K, "opening")
end

-- Every sheet a melee token names is on disk.
do
	local env, K, ns = New("WARRIOR", {})
	for look, spec in pairs(ns.SlabArmory.LOOKS) do
		if spec.aura then
			local path = (K.Tokens.Texture(spec.aura)):sub(#ROOT + 1):gsub("\\", "/")
			assert(io.open(path, "rb"), look .. "'s aura sheet " .. path .. " is in the addon")
		end
	end
	Clean(env, K, "sheets")
end

print("actionbars crest melee auras ok")
