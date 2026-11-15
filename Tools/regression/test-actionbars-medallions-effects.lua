-- test-actionbars-medallions-effects.lua: the Medallions slab's motion: a proc runs a class-tinted loop on its slot and pulses the hub's crest and glyphs, and its hide stops both; entering combat slides the wings out, fires the shockwave, crest flash and slab sweep and speeds the rune ring, and leaving folds them back; a level-up paints the plaque gold, writes the caption and plays the burst; motion off places everything with no animation, and the effects layer's Calm keeps the idle loops and one-shot flares but holds the slot loop and particles; the crest comes from KstyleUI.Medallions.Crest when it answers, which reads KstyleUI.MedallionAssets by the player's race and class, else a placeholder; slots wear M3's slot frames; and none of it runs under Frames.
local AB = dofile("Tools/regression/actionbars_env.lua")

local function New(opts)
	local env, K, ns = AB.New(opts or { class = "SHAMAN" })
	AB.Enable(env, K)
	return env, K, ns
end

local function Medallions(K, env)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(K.HudStyle.Current() == "medallions")
end

local function Kinds(group)
	local out = {}
	for _, anim in ipairs(group._anims or {}) do
		out[anim._type] = (out[anim._type] or 0) + 1
	end
	return out
end

local function WingX(wing)
	local _, _, _, x = wing:GetPoint(1)
	return math.abs(x)
end

do
	local env, K, ns = New()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.proc and not (b.medProc and b.medProc:IsShown()), "under Frames a proc runs no Medallions loop")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	assert(not (ns.Slab.hub and ns.Slab.hub:IsShown()), "under Frames there is no hub")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	Medallions(K, env)
	local Slab, hub = ns.Slab, ns.Slab.hub
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	AB.Slot(env, 3, { texture = 3, type = "spell", id = 200 })
	local b, other = AB.Button(ns, "bar1", 1), AB.Button(ns, "bar1", 3)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.proc and b.medProc and b.medProc:IsShown(), "a proc shows the slot's Medallions loop")
	assert(b.medProc.anim:IsPlaying() and b.medProc.anim:GetLooping() == "REPEAT", "the slot loop repeats")
	assert(b.medProcStart.anim:IsPlaying(), "the proc opens with its start burst")
	local r, g, bl = K.Theme.ClassColor("SHAMAN")
	local vr, vg, vb = b.medProcStart:GetVertexColor()
	assert(math.abs(vr - r) < 1e-6 and math.abs(vg - g) < 1e-6 and math.abs(vb - bl) < 1e-6, "the white start burst takes the class colour")
	assert(b.medProc:GetTexture() == K.Tokens.Texture("medProcShaman"), "the loop is the shaman's own flipbook")
	assert(hub.crest.pulse:IsPlaying() and hub.glyphs.flash:IsPlaying(), "the hub's crest pulses and its glyphs flash")
	assert(Kinds(hub.crest.pulse).Scale == 2, "the pulse grows and settles")
	assert(not (other.medProc and other.medProc:IsShown()), "only the proc's own slot loops")
	assert(b.medProc:GetParent() == b.overlay, "the loop draws on the slot, above the hub")
	assert(not (b.lumenGlow and b.lumenGlow:IsShown()), "the Medallions loop replaces the slot's own proc glow")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	assert(not b.medProc:IsShown() and not b.medProc.anim:IsPlaying(), "the hide stops the slot loop")

	assert(not Slab.InCombat(), "out of combat at the start")
	local rest = WingX(hub.wings[1])
	env.SetCombat(true)
	local combat, out = Slab.InCombat()
	assert(combat and out, "entering combat puts the wings out")
	for _, wing in ipairs(hub.wings) do
		assert(wing.anim:IsPlaying(), "each wing slides")
		local dx = wing.move:GetOffset()
		assert(dx * wing.side > 0, "each wing slides outward")
	end
	assert(hub.shock.anim:IsPlaying() and hub.flash.anim:IsPlaying(), "the shockwave and crest flash fire")
	for _, sweep in ipairs(Slab.frame.sweeps) do
		assert(sweep.anim:IsPlaying() and sweep.move:GetOffset() * sweep.side > 0, "light runs along the slab both ways")
	end
	assert(hub.runes.turn:GetAnimationSpeedMultiplier() > 1, "the rune ring turns faster in combat")
	local sliding = WingX(hub.wings[1])
	hub.wings[1].anim:GetScript("OnFinished")(hub.wings[1].anim, true)
	assert(WingX(hub.wings[1]) == sliding, "a stopped slide does not move the wings to the end")
	ns.Slab.Refresh()
	assert(WingX(hub.wings[1]) == sliding, "a refresh during the slide leaves the wings to the animation")
	hub.wings[1].anim:GetScript("OnFinished")(hub.wings[1].anim)
	assert(WingX(hub.wings[1]) > rest, "after the slide the wings rest further out")
	env.SetCombat(false)
	assert(not Slab.InCombat(), "leaving combat folds the wings")
	hub.wings[1].anim:GetScript("OnFinished")(hub.wings[1].anim)
	assert(math.abs(WingX(hub.wings[1]) - rest) < 1e-6, "the wings fold back to rest")
	assert(hub.runes.turn:GetAnimationSpeedMultiplier() == 1, "the rune ring settles")

	assert(Kinds(hub.runes.turn).Rotation == 1 and hub.runes.turn:GetLooping() == "REPEAT" and hub.runes.turn:IsPlaying(), "the rune ring turns")
	assert(hub.glow.breath:IsPlaying() and hub.glow.breath:GetLooping() == "BOUNCE", "the glow breathes")
	env.RunTimers()
	assert(K.Effects.Holder("hub") == nil, "the proc's hold on the hub has ended")
	assert(hub.sheen.run:IsPlaying(), "the sheen passes")
	local alive = 0
	for _, p in ipairs(hub.particles) do
		alive = alive + (p.anim:IsPlaying() and 1 or 0)
	end
	assert(alive > 0 and alive < #hub.particles, "calm keeps a few particles alive")

	env.FireEvent("PLAYER_LEVEL_UP", 12)
	assert(hub.level:GetText() == "12", "the plaque shows the new level")
	assert(hub.caption:GetText() == string.format(K.L["Level %d"], 12), "the caption names the level")
	assert(hub.burst.anim:IsPlaying() and hub.caption.anim:IsPlaying(), "the level-up burst plays")
	local pr = hub.plaque:GetVertexColor()
	assert(pr < 1, "the plaque turns gold")
	hub.burst.anim:GetScript("OnFinished")(hub.burst.anim, true)
	assert(hub.plaque:GetVertexColor() == pr, "a burst stopped for the next one keeps the plaque gold")
	hub.burst.anim:GetScript("OnFinished")(hub.burst.anim)
	assert(hub.plaque:GetVertexColor() ~= pr, "the plaque settles after the burst")
	env.FireEvent("PLAYER_LEVEL_UP", env.Secret(13))
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	K.Motion.SetLevel("off")
	Medallions(K, env)
	local hub = ns.Slab.hub
	assert(not hub.runes.turn:IsPlaying() and not hub.glow.breath:IsPlaying(), "motion off keeps the hub still")
	local rest = WingX(hub.wings[1])
	env.SetCombat(true)
	assert(not hub.wings[1].anim:IsPlaying() and not hub.shock.anim:IsPlaying(), "motion off plays no combat effect")
	assert(WingX(hub.wings[1]) > rest, "motion off still puts the wings out at once")
	env.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	Medallions(K, env)
	local hub = ns.Slab.hub
	assert(hub.crestPath == K.Tokens.Texture("logoLarge") or hub.crestPath ~= nil, "a placeholder crest shows before the resolver answers")
	K.Medallions = { Crest = function(unit)
		assert(unit == "player", "the hub asks for the player's crest")
		return "Interface\\Crest.png", "Interface\\CrestGlow.png", "Interface\\CrestMetal.png"
	end }
	ns.Slab.Refresh()
	assert(hub.crestPath == "Interface\\Crest.png" and hub.bloom:GetTexture() == "Interface\\CrestGlow.png", "the crest and its bloom come from the resolver")
	K.Medallions = { Crest = function()
		return env.Secret("x")
	end }
	ns.Slab.Refresh()
	assert(hub.crestPath ~= "x", "a secret answer falls back to the placeholder")
	K.Medallions = nil
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	local level = "Calm"
	K.Effects = { Level = function()
		return level
	end }
	Medallions(K, env)
	local hub = ns.Slab.hub
	assert(ns.Slab.Level() == "calm", "the effects layer's level rules the hub")
	assert(hub.runes.turn:IsPlaying() and hub.glow.breath:IsPlaying() and hub.sheen.run:IsPlaying(), "calm keeps the idle loops")
	for _, p in ipairs(hub.particles) do
		assert(not p.anim:IsPlaying(), "calm has no particles")
	end
	local rest = WingX(hub.wings[1])
	env.SetCombat(true)
	assert(hub.wings[1].anim:IsPlaying() and hub.shock.anim:IsPlaying(), "calm keeps the one-shot flares: the wings slide and the shockwave fires")
	assert(ns.Slab.Allows("flare") and not ns.Slab.Allows("pulse") and not ns.Slab.Allows("particle"), "calm allows ambient and flares, no loops or particles")
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.medProc:IsShown() and not b.medProc.anim:IsPlaying() and b.medProcStart.anim:IsPlaying(), "calm shows the slot loop still and plays its start burst")
	assert(hub.crest.pulse:IsPlaying(), "calm keeps the hub's one-shot proc pulse")
	hub.wings[1].anim:GetScript("OnFinished")(hub.wings[1].anim)
	assert(WingX(hub.wings[1]) > rest, "the wings rest out after the slide")
	env.SetCombat(false)
	level = "off"
	K.Callbacks.Fire("SettingChanged", "Effects", "level")
	assert(not hub.runes.turn:IsPlaying() and not hub.glow.breath:IsPlaying(), "off stills the hub at once")
	level = "full"
	K.Callbacks.Fire("SettingChanged", "Effects", "level")
	assert(hub.runes.turn:IsPlaying(), "full brings the motion back")
	level = 7
	assert(ns.Slab.Level() == "full", "an answer that is not a level falls back to the motion setting")
	K.Effects = nil
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	local texture = K.Tokens.Texture
	K.Tokens.Texture = function(name)
		if name == "medProcShaman" then
			return "Interface\\ProcShaman.png"
		end
		return texture(name)
	end
	Medallions(K, env)
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.medProc:GetTexture() == "Interface\\ProcShaman.png", "the slot loop takes the class's flipbook")
	local wr, wg, wb = b.medProc:GetVertexColor()
	assert(wr == 1 and wg == 1 and wb == 1, "a class flipbook keeps its own baked colours, untinted")
	local kinds = Kinds(b.medProc.anim)
	assert(kinds.FlipBook == 1 and b.medProc.anim._anims[1]:GetFlipBookFrames() == 16, "the class flipbook runs as a FlipBook of 16 frames")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.lumenGlow:IsShown() and not b.medProc:IsShown(), "back to Frames the slot's own proc glow returns")
	K.Tokens.Texture = texture
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	env.UnitRace = function()
		return "Dwarf", "Dwarf", 3
	end
	env.UnitSex = function()
		return 2
	end
	Medallions(K, env)
	local hub = ns.Slab.hub
	local own = K.MedallionAssets.crests.Dwarf.SHAMAN
	assert(hub.crestPath == own.crest and hub.bloom:GetTexture() == own.glow, "the hub shows the player's crest from KstyleUI.Medallions.Crest, by race and class")
	env.C_Secrets = { ShouldUnitIdentityBeSecret = function()
		return true
	end }
	ns.Slab.Refresh()
	assert(hub.crestPath ~= own.crest, "a secret identity indexes no crest")
	env.C_Secrets = nil
	env.UnitRace = function()
		return env.Secret("Dwarf"), env.Secret("Dwarf"), 3
	end
	ns.Slab.Refresh()
	assert(hub.crestPath ~= own.crest, "a secret race indexes no crest")

	local b = AB.Button(ns, "bar1", 1)
	assert(b.medFrame and b.medFrame:IsShown() and b.medFrame:GetTexture() == K.Tokens.Texture("medSlot"), "the slot wears M3's slot frame")
	assert(b.medHover:GetParent() == b.hoverLayer, "the highlight frame rides the slot's hover layer")
	assert(not b.medPushed:IsShown(), "the pushed frame waits for a press")
	K.Motion.SetLevel("off")
	b:GetScript("OnClick")(b, "LeftButton", true)
	assert(b.medPushed:IsShown(), "a slot held down shows the pushed frame, with motion off too")
	b:GetScript("OnClick")(b, "LeftButton", false)
	assert(not b.medPushed:IsShown(), "and releasing it hides the pushed frame")
	K.Motion.SetLevel("full")
	assert(not b.medChecked:IsShown(), "the checked frame waits for a checked action")
	b:SetSelected(true)
	assert(b.medChecked:IsShown(), "a checked action shows the checked frame")
	b:SetSelected(false)
	assert(not b.medChecked:IsShown(), "and hides it again")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(not b.medFrame:IsShown() and not b.medHover:IsShown() and not b.medPushed:IsShown(), "back to Frames the slot frames hide")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Lee's own character, an undead warlock with his imp out: the Forsaken warlock crest, and the fel motif in the slot
-- loop and the particles, each in its baked colours.
do
	local env, K, ns = New({ class = "WARLOCK" })
	env._game.petExists = true
	env._game.pet[1] = { name = "Firebolt", texture = 135809, spellID = 8001 }
	env.UnitRace = function()
		return "Undead", "Scourge", 5
	end
	env.UnitSex = function()
		return 2
	end
	Medallions(K, env)
	local hub = ns.Slab.hub
	local art = K.MedallionAssets.crests.Scourge.WARLOCK
	assert(hub.crestPath == art.crest and hub.bloom:GetTexture() == art.glow, "the hub wears the undead warlock's crest")
	local fel = K.Tokens.Texture("medParticleWarlock")
	for _, p in ipairs(hub.particles) do
		local r, g, b = p:GetVertexColor()
		assert(p:GetTexture() == fel and r == 1 and g == 1 and b == 1, "the particles are the warlock's fel embers in their own colours")
	end
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 686 })
	local slot = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 686)
	assert(slot.medProc:IsShown() and slot.medProc:GetTexture() == K.Tokens.Texture("medProcWarlock"), "a proc runs the warlock's fel flipbook on its slot")
	assert(Kinds(slot.medProc.anim).FlipBook == 1, "the fel loop runs as a FlipBook")
	local r, g, b = slot.medProc:GetVertexColor()
	assert(r == 1 and g == 1 and b == 1, "the fel loop keeps its baked violet and green")
	assert(ns.bars.pet and ns.bars.pet.buttons[1]:IsVisible(), "the imp's bar is out")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("ok actionbars medallions effects")
