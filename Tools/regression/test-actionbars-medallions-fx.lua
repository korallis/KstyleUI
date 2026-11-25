-- test-actionbars-medallions-fx.lua: the Medallions action effects: a slot's ready flash under Medallions is the effects layer's steel flash, it yields to a proc on that slot and a proc ends it, Calm keeps it and Off drops it, and Frames keeps the old flash; the hub's ring brightens through a UnitPowerPercent curve while the resource is capped, tracks the class's secondary resource for a mana user unless the crest jewels glow at its maximum, breathes only at Full and listens to power events only under Medallions (the clean screen, which listens to the main power out of combat, is off here); a proc and a level-up add a 3D model at the hub inside the three-model cap while the 2D burst still plays, and the hub's ambient sheen and particles yield while an effect holds it; no effect sets an OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")

local FX = dofile("Tools/regression/effects_env.lua")

local function New(class)
	local env, K, ns = AB.New({ class = class or "WARRIOR", setup = FX.Install })
	AB.Enable(env, K)
	K.Options.Write("Rest", "enabled", false)
	return env, K, ns
end

local function Refresh(env)
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.RunTimers()
end

local function Updating(env)
	local set = {}
	for _, frame in ipairs(env._frames) do
		if frame:GetScript("OnUpdate") then
			set[frame] = true
		end
	end
	return set
end

local function NoUpdates(env, before)
	for frame in pairs(Updating(env)) do
		assert(before[frame], "no effect drives a visual from OnUpdate")
	end
end

local function Listening(env, event)
	for _, frame in ipairs(env._frames) do
		if frame:IsEventRegistered(event) then
			return true
		end
	end
	return false
end

do
	local env, K, ns = New()
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	b.realCooldown = true
	b:FlashReady()
	assert(b.readyFlash:IsPlaying() and not b.medReady, "under Frames the slot keeps its own ready flash")
	assert(not Listening(env, "UNIT_POWER_UPDATE"), "under Frames the hub ring does not listen to power")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	Refresh(env)
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	local before = Updating(env)
	b.realCooldown = true
	b.readyFlash:Stop()
	b.cooldown:GetScript("OnCooldownDone")(b.cooldown)
	assert(b.medReady and b.medReady.anim:IsPlaying(), "OnCooldownDone plays the steel flash under Medallions")
	assert(not b.readyFlash:IsPlaying(), "the old flash does not also play")
	assert(K.Effects.Holder(b) == K.Effects.PRIORITY.ready, "the flash holds its slot")
	local w = b.medReady:GetWidth()
	assert(w > b:GetWidth(), "the flash is larger than the slot, which is its middle 70%")
	-- The outline alone read as a faint edge at actual size; the wash over the icon is what makes ready legible.
	local wash = b.medReady.wash
	assert(wash and wash.anim:IsPlaying(), "the ready flash also washes the slot's icon")
	assert(math.abs(wash:GetWidth() - b.icon:GetWidth()) + math.abs(wash:GetHeight() - b.icon:GetHeight()) < 0.01, "the wash covers the icon")
	assert(wash.rise._state.ToAlpha[1] >= 0.5, "the wash brightens the icon by at least half, so ready reads in greyscale")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.proc and not b.medReady.anim:IsPlaying() and not wash.anim:IsPlaying(), "a proc on the slot ends its ready flash and wash")
	assert(K.Effects.Holder(b) == K.Effects.PRIORITY.proc, "the proc holds the slot")
	b:FlashReady()
	assert(not b.medReady.anim:IsPlaying() and not b.readyFlash:IsPlaying(), "a ready flash yields to the proc")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	assert(K.Effects.Holder(b) == nil, "the proc frees the slot when it ends")
	K.Options.Write("Medallions", "motion", "calm")
	b:FlashReady()
	assert(b.medReady.anim:IsPlaying() and wash.anim:IsPlaying(), "Calm keeps the ready flash and wash")
	env.RunTimers()
	K.Options.Write("Medallions", "motion", "off")
	b.medReady.anim:Stop()
	wash.anim:Stop()
	b:FlashReady()
	assert(not b.medReady.anim:IsPlaying() and not wash.anim:IsPlaying() and not b.readyFlash:IsPlaying(), "Off plays no flash or wash")
	NoUpdates(env, before)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New()
	Refresh(env)
	local Fx, hub = ns.SlabEffects, ns.Slab.hub
	assert(hub and hub:IsShown(), "the hub shows under Medallions")
	local frame = Fx and select(1, hub:GetChildren())
	assert(Listening(env, "UNIT_POWER_UPDATE"), "under Medallions the hub ring listens to power")
	local capped
	for _, child in ipairs({ hub:GetChildren() }) do
		if child.glyphs then
			capped = child
		end
	end
	assert(frame and capped and capped:IsShown(), "the cap ring sits on the hub")
	assert(capped:GetFrameLevel() < hub.top:GetFrameLevel(), "the cap ring sits under the crest")
	assert(env.Reveal(capped._lastAlpha.args[1]) == 1, "a full resource lights the ring through the curve")
	env._power = 0.5
	env.FireEvent("UNIT_POWER_UPDATE", "player", "RAGE")
	assert(env.Reveal(capped._lastAlpha.args[1]) == 0, "below the cap the ring is dark, with no compare in Lua")
	assert(env._askedPower == 1, "a rage user's ring follows rage")
	assert(capped.breath:IsPlaying(), "the ring breathes at Full")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not capped.breath:IsPlaying() and capped:IsShown(), "the ring holds still at Calm")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(not capped:IsShown() and not Listening(env, "UNIT_POWER_UPDATE"), "leaving Medallions hides the ring and stops listening")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("PALADIN")
	env._powerType, env._powerToken = 0, "MANA"
	Refresh(env)
	assert(ns.SlabEffects.PowerType() == nil, "a paladin's crest jewels glow at full holy power, so the cap ring leaves it to them")
	K.Options.Write("ActionBars", "crestJewelGlow", false)
	env.RunTimers()
	assert(env._askedPower == 9, "with Glow at max off, a paladin's ring follows holy power, not mana")
	env._powerType, env._powerToken = 0, "MANA"
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("MAGE")
	env._powerType, env._powerToken = 0, "MANA"
	Refresh(env)
	local hub = ns.Slab.hub
	local before = Updating(env)
	for _, child in ipairs({ hub:GetChildren() }) do
		assert(not (child.glyphs and child:IsShown()), "a mage has no capped resource to show")
	end
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(K.Effects.LiveModels() == 1 and K.Effects.Holder("hub") == K.Effects.PRIORITY.proc, "a proc adds the class model at the hub")
	assert(hub.crest.pulse:IsPlaying(), "the hub's own 2D pulse still plays")
	assert(not hub.sheen.run:IsPlaying(), "the hub's sheen yields while the proc holds it")
	env.FireEvent("PLAYER_LEVEL_UP", 12)
	assert(hub.burst.anim:IsPlaying(), "a level-up still plays the 2D burst")
	assert(K.Effects.LiveModels() == 1 and K.Effects.Holder("hub") == K.Effects.PRIORITY.levelUp, "the level-up model takes the hub from the proc's, an equal priority")
	for i = 2, 4 do
		AB.Slot(env, i, { texture = 1, type = "spell", id = 100 + i })
		env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100 + i)
	end
	assert(K.Effects.LiveModels() == 1 and K.Effects.Holder("hub") == K.Effects.PRIORITY.levelUp, "the fading proc model yields to level-up and later procs cannot displace it")
	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" and frame:IsShown() then
			assert(frame:GetFrameStrata() == hub:GetFrameStrata(), "a hub model stays in the hub's strata, under every slot")
		end
	end
	env.RunTimers()
	assert(K.Effects.Holder("hub") == nil, "the hold ends with its time")
	assert(hub.sheen.run:IsPlaying(), "the sheen comes back after the hold")
	NoUpdates(env, before)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("WARLOCK")
	env._powerType, env._powerToken = 0, "MANA"
	Refresh(env)
	K.Options.Write("ActionBars", "crestJewels", false)
	env.RunTimers()
	assert(ns.SlabEffects.PowerType() == nil and env._askedPower ~= 7, "Lee's warlock: Soul Shards are bag items, so the cap ring reads no soul shard power")
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.medProc and b.medProc:IsShown(), "a warlock proc runs the slot's loop")
	assert(b.medProc:GetTexture():find("ProcWarlock", 1, true), "the slot's loop is the fel flipbook: " .. tostring(b.medProc:GetTexture()))
	local fel
	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" and frame:IsShown() then
			fel = frame.actor._state.ModelByFileID and frame.actor._state.ModelByFileID[1]
		end
	end
	assert(fel == K.Effects.MODELS.WARLOCK, "the hub's proc model is the warlock's fel fire: " .. tostring(fel))
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("ok actionbars medallions fx")
