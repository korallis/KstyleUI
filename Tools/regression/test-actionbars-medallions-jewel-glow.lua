-- test-actionbars-medallions-jewel-glow.lua: the crest jewels' motion and full ring: at the maximum the rune ring's glyphs and halo light in the resource's colour, fading in, and fade out on a spend; a gained jewel's core flares under the ember that keeps unchanged jewels steady, and a spent jewel's ember drains; every lit layer is a one-point status bar fed the raw value now or the value before, so secret values light them with no Lua compare; Calm stills the ring's breath, Off plays nothing and shows the end states, nothing runs OnUpdate, Glow at max off keeps the plain ring and lends the paladin's and warlock's cap ring back; every layer is an even number of physical pixels centred on its setting at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")

local ENERGY, MANA = 3, 0
local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local LAYERS = { "halo", "haloWas", "rim", "gem", "flare", "ember", "core", "glint" }

local function New(class, power, size)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._points = 0
			e.Enum = e.Enum or {}
			e.Enum.PowerType = { Mana = 0, Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9 }
			e.GetComboPoints = function() return e._points end
			e.UnitPower = function() return e._points end
			e.UnitPowerMax = function() return 5 end
			e.UnitPowerType = function() return power, power == MANA and "MANA" or "ENERGY" end
		end,
	})
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	return env, K, ns
end

local function Set(env, points)
	env._points = points
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
end

-- Lit(env, bar) -> whether a one-point bar draws its fill: the engine's compare, done here on the revealed value.
local function Lit(env, bar)
	local low, high = bar:GetMinMaxValues()
	local value = bar:GetValue()
	if env.issecretvalue(value) then
		value = env.Reveal(value)
	end
	return value >= high and high > low
end

local function Alpha(group)
	local list = {}
	for _, anim in ipairs(group._anims) do
		local from, to = anim._state.FromAlpha[1], anim._state.ToAlpha[1]
		list[#list + 1] = { from, to, anim._state.Duration[1], (anim._state.Order or { 1 })[1] }
	end
	return list
end

local function Length(group)
	local total = 0
	for _, a in ipairs(Alpha(group)) do
		total = total + a[3]
	end
	return total
end

local function Playing(ns)
	local n = 0
	for _, jewel in ipairs(ns.SlabJewels.state.jewels) do
		for _, group in ipairs(jewel.fades) do
			n = n + (group:IsPlaying() and 1 or 0)
		end
	end
	local ring = ns.SlabJewels.state.ring
	for _, group in ipairs({ ring.now.fade, ring.was.fade, ring.breath }) do
		n = n + (group:IsPlaying() and 1 or 0)
	end
	return n
end

-- Updating(ns) -> how many of the jewels' and ring's frames run an OnUpdate script.
local function Updating(ns)
	local state, frames = ns.SlabJewels.state, {}
	for _, jewel in ipairs(state.jewels) do
		frames[#frames + 1] = jewel.holder
		for _, key in ipairs(LAYERS) do
			frames[#frames + 1] = jewel[key]
		end
	end
	local ring = state.ring
	for _, side in ipairs({ ring.now, ring.was }) do
		frames[#frames + 1], frames[#frames + 2], frames[#frames + 3] = side, side.glyphs, side.halo
	end
	frames[#frames + 1] = ring
	local n = 0
	for _, frame in ipairs(frames) do
		if frame:GetScript("OnUpdate") then
			n = n + 1
		end
	end
	return n
end

do
	local env, K, ns = New("ROGUE", ENERGY)
	local state = ns.SlabJewels.state
	local ring, jewels, hub = state.ring, state.jewels, ns.Slab.hub
		assert(ring and ring:IsShown() and ring.breath:IsPlaying(), "Glow at max is on by default and the ring breathes at Full")
	assert(ring:GetFrameLevel() < hub:GetFrameLevel() and ring.now.halo:GetFrameLevel() < hub:GetFrameLevel(), "the ring's halo sits under the hub, so its rim and socket keep it off the crest")
	assert(ring.now.glyphs:GetFrameLevel() > hub:GetFrameLevel(), "the ring's glyphs glow over the rune band")
	local er, eg, eb = K.Tokens.Color("jewelCombo")
	local r, g, b = ring.now.glyphs:GetStatusBarColor()
	assert(math.abs(r - er) + math.abs(g - eg) + math.abs(b - eb) < 1e-3, "a rogue's ring glows in the embers of the combo jewels")
	assert(not Lit(env, ring.now.glyphs) and not Lit(env, ring.was.glyphs), "no combo points leave the ring dark")

	Set(env, 4)
	assert(not Lit(env, ring.now.glyphs), "four of five leave the ring dark")
	Set(env, 5)
	assert(Lit(env, ring.now.glyphs) and Lit(env, ring.now.halo), "at the maximum the whole ring and its halo light")
	assert(not Lit(env, ring.was.glyphs), "the value before stayed below the maximum")
	local now, was = Alpha(ring.now.fade), Alpha(ring.was.fade)
	assert(ring.now.fade:IsPlaying() and now[1][1] == 0 and now[1][2] == 1 and math.abs(now[1][3] - 0.2) < 1e-6, "the ring fades in over 0.2 s")
	assert(ring.was.fade:IsPlaying() and was[1][1] == 1 and was[1][2] == 0 and was[1][3] == now[1][3], "the ring before fades out over the same time, so a ring lit before and after adds to a steady glow")
	assert(ring.now:GetAlpha() == 1 and ring.was:GetAlpha() == 0, "the fades end on the ring now, so Off shows the end state")

	Set(env, 2)
	assert(not Lit(env, ring.now.glyphs) and Lit(env, ring.was.glyphs) and ring.was.fade:IsPlaying(), "a spend fades the full ring out")

	-- 2 -> 3: jewel 3 ignites; jewels 1 and 2 hold.
	Set(env, 3)
	local j1, j3 = jewels[1], jewels[3]
	assert(Lit(env, j3.gem) and Lit(env, j3.flare) and not Lit(env, j3.ember), "a gained jewel lights with its flare and no ember over it")
	assert(j3.flare.fade:IsPlaying(), "the gained jewel's core flares")
	local flare = Alpha(j3.flare.fade)
	assert(flare[1][1] == 0 and flare[1][2] == 1 and flare[2][1] == 1 and flare[2][2] == 0 and flare[2][4] == 2, "the flare rises, then settles")
	assert(j3.flare:GetAlpha() == 0, "the flare ends unseen")
	assert(Lit(env, j1.ember) and Lit(env, j1.flare), "a jewel lit before and after has its ember over its flare")
	assert(j1.ember:GetFrameLevel() > j1.flare:GetFrameLevel(), "the ember draws over the flare")
	assert(j1.ember.units >= j1.flare.units, "the ember covers the whole flare")
	local ember = Alpha(j1.ember.fade)
	assert(ember[1][1] == 1 and ember[1][2] == 1 and ember[1][3] >= Length(j3.flare.fade), "the ember holds until the flare has ended")
	assert(ember[2][1] == 1 and ember[2][2] == 0 and ember[2][4] == 2, "then it drains")
	assert(j1.core:GetFrameLevel() > j1.ember:GetFrameLevel() and j1.glint:GetFrameLevel() > j1.ember:GetFrameLevel(), "a held jewel's core and glint stay over its ember")
	assert(Lit(env, j1.halo) and Lit(env, j1.haloWas) and not Lit(env, j3.haloWas), "the halo cross-fades: a gained jewel's blooms in, a held jewel's adds to a steady glow")
	local h, hw = Alpha(j1.halo.fade), Alpha(j1.haloWas.fade)
	assert(h[1][1] == 0 and hw[1][2] == 0 and h[1][2] == hw[1][1] and h[1][3] == hw[1][3], "the two halos fade in step")

	-- 3 -> 1: jewels 2 and 3 drain.
	Set(env, 1)
	assert(not Lit(env, j3.gem) and Lit(env, j3.ember) and j3.ember.fade:IsPlaying(), "a spent jewel drains through its ember")
	assert(not Lit(env, j3.halo) and Lit(env, j3.haloWas) and j3.haloWas.fade:IsPlaying(), "its glow fades out")
	assert(j3.ember:GetAlpha() == 0 and j3.haloWas:GetAlpha() == 0, "the drain ends dark")
	assert(Lit(env, j1.gem) and not Lit(env, jewels[2].gem), "one point keeps one jewel")
	assert(Updating(ns) == 0, "no jewel effect runs OnUpdate")

	-- Calm stills the breath; Off plays nothing at all.
	K.Options.Write("Medallions", "motion", "calm")
	assert(ring:IsShown() and not ring.breath:IsPlaying(), "Calm stills the ring's breath")
	Set(env, 5)
	assert(ring.now.fade:IsPlaying() and j3.flare.fade:IsPlaying(), "Calm keeps the fades and the flare")
	K.Options.Write("Medallions", "motion", "off")
	Set(env, 3)
	assert(Playing(ns) == 0, "Off plays no jewel or ring animation")
	assert(Lit(env, j3.gem) and not Lit(env, jewels[4].gem) and not Lit(env, ring.now.glyphs), "Off shows the end state at once")
	Set(env, 5)
	assert(Playing(ns) == 0 and Lit(env, ring.now.glyphs) and ring.now:GetAlpha() == 1, "Off lights the full ring at once, still")
	assert(Updating(ns) == 0, "no jewel effect runs OnUpdate at Off")
	K.Options.Write("Medallions", "motion", "full")
	assert(ring.breath:IsPlaying(), "Full brings the breath back")

	K.Options.Write("ActionBars", "crestJewelGlow", false)
	env.RunTimers()
	assert(not ring:IsShown() and not ring.breath:IsPlaying() and jewels[1].holder:IsShown(), "Glow at max off keeps the jewels and the plain ring")
	Set(env, 4)
	Set(env, 5)
	assert(not ring:IsShown(), "and the ring stays plain at the maximum")
	K.Options.Write("ActionBars", "crestJewelGlow", true)
	env.RunTimers()
	assert(ring:IsShown() and Lit(env, ring.now.glyphs), "turning it back on lights the full ring")
	K.Options.Write("ActionBars", "crestJewels", false)
	env.RunTimers()
	assert(not ring:IsShown(), "Crest resource jewels off takes the glow with them")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("ROGUE", ENERGY)
	local state = ns.SlabJewels.state
	local four, five = env.Secret(4), env.Secret(5)
	env._points = four
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env._points = five
	env.FireEvent("COMBO_TARGET_CHANGED")
	local jewel, ring = state.jewels[5], state.ring
	for _, key in ipairs({ "halo", "rim", "gem", "flare", "core", "glint" }) do
		assert(jewel[key]:GetValue() == five, "the " .. key .. " gets the secret value as it is")
	end
	assert(jewel.ember:GetValue() == four and jewel.haloWas:GetValue() == four, "the ember and the glow before get the secret before")
	assert(ring.now.glyphs:GetValue() == five and ring.was.glyphs:GetValue() == four, "the ring is fed the secrets too, for the engine to compare with its maximum")
	assert(Lit(env, ring.now.glyphs) and not Lit(env, ring.was.glyphs), "five secret points light the full ring")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

for _, class in ipairs({ "PALADIN", "WARLOCK" }) do
	local env, K, ns = New(class, MANA)
	local kind = class == "PALADIN" and "jewelHoly" or "jewelShard"
	local r, g, b = ns.SlabJewels.state.ring.now.halo:GetStatusBarColor()
	local er, eg, eb = K.Tokens.Color(kind)
	assert(math.abs(r - er) + math.abs(g - eg) + math.abs(b - eb) < 1e-3, class .. ": the ring glows in the jewels' colour")
	assert(ns.SlabEffects.PowerType() == nil, class .. ": the cap ring leaves the resource to the jewels' glow")
	K.Options.Write("ActionBars", "crestJewelGlow", false)
	env.RunTimers()
	assert(ns.SlabEffects.PowerType() ~= nil, class .. ": Glow at max off lends the cap ring back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = New("ROGUE", ENERGY, size)
	local k = size[2] / 768
	local function Edges(region)
		local s = region:GetEffectiveScale() * k
		return region:GetLeft() * s, region:GetRight() * s, region:GetBottom() * s, region:GetTop() * s
	end
	local function Even(value)
		local n = math.floor(value + 0.5)
		return math.abs(value - n) < 1e-3 and n % 2 == 0
	end
	local jewels, centres = ns.SlabJewels.state.jewels, {}
	for i, jewel in ipairs(jewels) do
		local l, r, b, t = Edges(jewel.holder)
		local cx, cy = (l + r) / 2, (b + t) / 2
		centres[i] = { cx, cy }
		local parts = { jewel.setting[1], jewel.setting[2], jewel.setting[3] }
		for _, key in ipairs(LAYERS) do
			parts[#parts + 1] = jewel[key]
		end
		for n, part in ipairs(parts) do
			local pl, pr, pb, pt = Edges(part)
			assert(Even(pr - pl) and Even(pt - pb), at .. "jewel " .. i .. " layer " .. n .. " is an even number of pixels: " .. (pr - pl))
			if part ~= jewel.glint then
				assert(math.abs((pl + pr) / 2 - cx) < 1e-3 and math.abs((pb + pt) / 2 - cy) < 1e-3, at .. "jewel " .. i .. " layer " .. n .. " centres on its setting")
			end
		end
	end
	local hx = (Edges(ns.Slab.hub)) + (select(2, Edges(ns.Slab.hub)) - Edges(ns.Slab.hub)) / 2
	local gaps = {}
	for i = 1, #centres do
		local mirror = centres[#centres + 1 - i]
		assert(math.abs((centres[i][1] - hx) + (mirror[1] - hx)) < 1e-3 and math.abs(centres[i][2] - mirror[2]) < 1e-3, at .. "jewel " .. i .. " mirrors its partner across the crown")
		if i > 1 then
			gaps[i - 1] = math.sqrt((centres[i][1] - centres[i - 1][1]) ^ 2 + (centres[i][2] - centres[i - 1][2]) ^ 2)
		end
	end
	for _, gap in ipairs(gaps) do
		assert(math.abs(gap - gaps[1]) <= 1.5, at .. "the jewels sit evenly: " .. table.concat(gaps, ", "))
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars medallions jewel glow ok")
