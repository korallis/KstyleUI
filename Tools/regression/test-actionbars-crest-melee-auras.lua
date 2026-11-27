-- test-actionbars-crest-melee-auras.lua: the warrior's, paladin's and rogue's crest marks as animated auras (the KSTY-51 plan, the captain's ask that everything a player tracks on the crest be an animated spell effect): every cooldown sigil on their rails and every perched or overlaid object with a sheet burns its own Blender aura; a class's own sigil keeps the colour baked into it while the racial and potion sigils every class shares take the rail's colour; a racial the character does not know draws flat and never loads its sheet (direction d-7cyxs7, art loaded only when needed); an object's light burns only inside its lit fill and takes the colour the strike's pick gives it; and every feed's light leaves with its piece, stopping when the piece leaves the crest and drawing nothing while a stance swap hides it.
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

-- Each class's rail: its own first cooldown sigil, Blood Fury (known, shared), the potion every class shares, the rogue's Sprint (whose
-- sheet the druid's Dash shares) and Berserking (a racial this character lacks).
local RAILS = {
	{ "WARRIOR", 1719, "Crossed", "gilt", { "Axe", "Potion" } },
	{ "PALADIN", 642, "Bubble", "white", { "Axe", "Potion" } },
	{ "ROGUE", 13877, "Flurry", "pipPriestGlow", { "Axe", "Potion", "Dash" }, 2983 },
}
for _, rail in ipairs(RAILS) do
	local class, spell, own, color, tinted = rail[1], rail[2], rail[3], rail[4], rail[5]
	local env, K, ns = New(class, { spell, 20572, rail[6] })
	local rim = assert(Find(ns, "crestCooldowns"), class .. " builds its cooldown rim")
	local mine = Drawn(rim, Sheet("Sigils", own))
	assert(#mine == 2, class .. ": its own " .. own .. " sigil burns its sheet as a fire and a still, got " .. #mine)
	for _, region in ipairs(mine) do
		assert(Colour(region) == "1.000,1.000,1.000", class .. ": its own sigil keeps the colour baked into its sheet")
	end
	for _, name in ipairs(tinted) do
		local shared = Drawn(rim, Sheet("Sigils", name))
		assert(#shared == 2, class .. ": the shared " .. name .. " sigil burns its sheet, got " .. #shared)
		for _, region in ipairs(shared) do
			assert(Colour(region) == Token(K, color), class .. ": the shared " .. name .. " sigil takes the rail's colour " .. color .. ", got " .. Colour(region))
		end
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
	-- Both clips span exactly the lit fill along the horn's length, so an empty fill shows no light and a half fill lights only its lit half
	-- (review of 071e48df, aura-clip-leads-fill).
	local fill = horn.lit.bar:GetStatusBarTexture()
	for _, each in ipairs({ clip, fire.still:GetParent() }) do
		local ends = {}
		for i = 1, each:GetNumPoints() do
			local point, to, at, x, y = each:GetPoint(i)
			assert(to == fill and point == at and x == 0 and y == 0, "a clip's " .. point .. " sits on the fill's own " .. tostring(at))
			ends[point] = true
		end
		assert(ends.TOP and ends.BOTTOM and each:GetNumPoints() == 2, "a clip is held at both ends of the fill")
	end
	assert(Colour(fire) == Token(K, horn.spec.color), "the horn's light takes its piece's colour")
	assert(clip:GetParent() == horn.lit.lights.flame, "the fire burns on the aura slot's own copy")
	assert(fire.still:GetParent():GetParent() == horn.lit.lights.calm, "and the still on another, so each layer can go dark alone")
	-- Battle Shout up with the crest already at Calm, then auras hidden: each motion level chosen in the settings swaps what reaches the screen at
	-- once, the engine playing the fire's loop masked behind the still, with no write to the aura buttons' animations (the instant-motion rule in
	-- test-actionbars-crest-motion.lua; review of 3349b893, prove-lit-armory-restricted-transition).
	local flame = horn.lit.lights.flame
	local writes = 0
	for _, verb in ipairs({ "AddAuraShownAnimation", "RemoveAuraShownAnimation" }) do
		local real = flame[verb]
		flame[verb] = function(...) writes = writes + 1 return real(...) end
	end
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	local function Shows(region)
		return region:IsVisible() and region:GetEffectiveAlpha() > 0
	end
	env.SetTarget(true)
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	F.Slots.Set(env, "player", { { id = horn.spec.spells[1], start = 0, duration = 120 } })
	assert(Engine(function() return Shows(fire.still) and not Shows(fire) and fire.loop:IsPlaying() end), "Battle Shout up at Calm: the still shows, the fire's loop plays masked behind it")
	env._aurasSecret = true
	env.SetCombat(true)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
	writes = 0
	for _, level in ipairs({ "full", "calm", "full", "off" }) do
		K.Options.Write("Medallions", "motion", level)
		env.RunTimers()
		local burning = level == "full"
		assert(Engine(function() return Shows(fire) == burning and Shows(fire.still) == not burning and fire.loop:IsPlaying() end),
			level .. " chosen under hidden values: the horn shows its " .. (burning and "moving fire" or "still") .. " at once")
	end
	assert(writes == 0, "no level choice under hidden values writes to the aura buttons' animations, got " .. writes)
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	-- The prepared loop is masked only while its aura shows: Battle Shout gone, it stops.
	F.Slots.Set(env, "player", nil)
	assert(not fire.loop:IsPlaying() and not Shows(fire) and not Shows(fire.still), "Battle Shout gone: the horn's light and its loop stop")
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
	-- The opening's light burns on no aura slot, so it keeps answering the motion level while auras are hidden (review of 071e48df,
	-- object-motion-freezes-under-restriction).
	env._aurasSecret = true
	env.SetCombat(true)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	ns.SlabMedals.Rest()
	assert(fire:GetAlpha() == 0 and fire.still:GetAlpha() == 1 and not fire.loop:IsPlaying(), "Calm under hidden values: the opening's light stills at once")
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	ns.SlabMedals.Rest()
	assert(fire:GetAlpha() == 1 and fire.still:GetAlpha() == 0 and fire.loop:IsPlaying(), "and Full burns it again at once")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Clean(env, K, "opening")
end

-- A piece's light leaves with it, for every feed: an object turned off in the settings leaves the crest and its fire's loop stops,
-- whether the engine plays it (an aura on the player or the target) or the addon does (a usable strike, a cooldown, an item), and
-- turned back on it burns again. A stance swap only hides a piece, so its light draws nothing until the stance returns (review of
-- d126cc5a, loop shutdown across feeds).
local FEEDS = {
	{ "WARRIOR", { 25289 }, "crestShout", "aura", function(env) F.Slots.Set(env, "player", F.Auras(env, { 25289 })) end },
	{ "WARRIOR", { 6673, 20662, 11585 }, "crestOpening", "usable", function(env) env._usable[11585] = true env.FireEvent("SPELL_UPDATE_USABLE") end },
	{ "PALADIN", { 20271 }, "crestJudgement", "cooldown", function(env) env._cooling[20271] = true env.FireEvent("SPELL_UPDATE_COOLDOWN") end },
	{ "PALADIN", { 20154, 20271, 20473, 10308 }, "crestFootLeft", "item", function(env) env.FireEvent("BAG_UPDATE_DELAYED") end },
	{ "ROGUE", { 1856, 11275 }, "crestRupture", "aura", function(env) F.Slots.Set(env, "target", F.Auras(env, { 11275 }, true)) end },
}
local function Burning(env, piece)
	env._engine = true
	local burning = piece:IsVisible() and piece.lit.fire:IsVisible() and piece.lit.fire.loop:IsPlaying()
	env._engine = nil
	return burning
end
for _, case in ipairs(FEEDS) do
	local class, key, feed = case[1], case[3], case[4]
	local env, K, ns = New(class, case[2])
	env.SetTarget(true)
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	case[5](env)
	env.RunTimers()
	local piece = assert(Find(ns, key), class .. " seats " .. key)
	assert(piece.spec.feed == feed and piece.lit.fire, key .. " is the " .. feed .. " feed's object, with an aura fire")
	assert(Burning(env, piece), key .. " (" .. feed .. ") burns its loop while fed")
	local fire = piece.lit.fire
	K.Options.Write("ActionBars", key, false)
	env.RunTimers()
	env._engine = true
	assert(not fire:IsVisible() and not fire.loop:IsPlaying(), key .. " (" .. feed .. ") turned off: its light and its loop stop")
	env._engine = nil
	K.Options.Write("ActionBars", key, true)
	env.RunTimers()
	assert(Burning(env, assert(Find(ns, key))), key .. " (" .. feed .. ") turned back on burns again")
	Clean(env, K, key .. " off and on")
end
do
	local env, K, ns = New("ROGUE", { 1856, 11275 })
	-- Vanish counts on the shoulder in Stealth only while the crest rail does not hold it.
	K.Options.Write("ActionBars", "crestRail", false)
	env.SetTarget(true)
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	F.Slots.Set(env, "target", F.Auras(env, { 11275 }, true))
	env._cooling[1856] = true
	local function Stance(form)
		env._form = form
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
		env.RunTimers()
		-- The client runs OnHide on a hidden piece's descendants, where the light's host stops its loop; the stub runs no OnHide, so
		-- the next Rest, which stops each addon-played light it finds hidden, stands in for it.
		ns.SlabMedals.Rest()
	end
	Stance(0)
	local rupture = assert(Find(ns, "crestRupture"))
	assert(rupture.spec.feed == "aura" and Burning(env, rupture), "Rupture's stain burns out of Stealth")
	Stance(30)
	local vanish = assert(Find(ns, "crestRupture"))
	assert(vanish.spec.feed == "cooldown" and Burning(env, vanish), "in Stealth Vanish's stain takes the seat and burns")
	assert(not rupture.lit.fire:IsVisible(), "and Rupture's light draws nothing while its piece is hidden")
	Stance(0)
	assert(Find(ns, "crestRupture") == rupture and Burning(env, rupture), "out of Stealth Rupture's stain burns again")
	assert(not vanish.lit.fire:IsVisible() and not vanish.lit.fire.loop:IsPlaying(), "and Vanish's light and loop stop")
	Clean(env, K, "stealth swap")
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
