-- test-actionbars-medallions-glyphs.lua: the crest's rune glyph band (SlabGlyphs.lua). Glyph tide: two vertical bars fed UnitPower over UnitPowerMax, raw or secret, one eased and one immediate, whose fills mask the lit layers (resource-coloured glyphs, a paler core and a fringe), so a gain eases and a spend drops at once; the turning band shows only above it; a mana user's tide shows in combat only, feeds nothing while hidden and settles away after it; the cap ring follows the tide's power (combat mana, a new form's power at once) as its last step, with a band glow and an outer glow on a 4.2 s breath, and is the old ring with the tide off. Stance mantle: the form's tint on the band and an inner rim, every glyph layer turning together (the band's turn and the notch), the old ink cross-fading into the new, a new form ID turning even in the same tint, Motion Off stopping every effect and landing it, a secret form read again when the restriction ends, Travel Form teal, Stealth dimming the emblem, Frames tinting only the active stance button's rim. Both switches off give the old crest exactly; nothing is built in combat, and held-back work runs when combat or the restriction ends; no part sits under an aura button or runs OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local RAGE, MANA = 1, 0
local COLORS = { RAGE = { r = 1, g = 0, b = 0 }, MANA = { r = 0, g = 0, b = 1 } }

local function New(class, kind, token, opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			e._kind, e._token, e._power, e._max, e._form = kind, token, 20, 100, opts.form
			e.PowerBarColor = COLORS
			e._secretKind = opts.secretKind
			e.UnitPowerType = function()
				if e._secretKind then return e.Secret(e._kind), e.Secret(e._token) end
				return e._kind, e._token
			end
			e.UnitPower = function() return e._power end
			e.UnitPowerMax = function() return e._max end
			e.GetShapeshiftFormID = function() return e._form end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return id == 6673 end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	local E, mine = K.Events, {}
	env._glyph = mine
	for _, name in ipairs({ "Register", "RegisterUnit" }) do
		local fn = E[name]
		E[name] = function(owner, event, ...)
			if owner:find("SlabGlyphs", 1, true) then mine[owner .. "|" .. event] = true end
			return fn(owner, event, ...)
		end
	end
	local unregister, all = E.Unregister, E.UnregisterAll
	E.Unregister = function(owner, event)
		mine[owner .. "|" .. event] = nil
		return unregister(owner, event)
	end
	E.UnregisterAll = function(owner)
		for key in pairs(mine) do
			if key:find(owner .. "|", 1, true) == 1 then mine[key] = nil end
		end
		return all(owner)
	end
	if opts.off then
		K.Options.Write("ActionBars", "crestTide", false)
		K.Options.Write("ActionBars", "crestMantle", false)
	end
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

local function Near(a, b, what)
	assert(math.abs(a - b) < 1e-4, what .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

-- Same(what, { r, g, b }, er, eg, eb): the expected colour last, so a call there gives all three values.
local function Same(what, rgb, er, eg, eb)
	Near(rgb[1], er, what)
	Near(rgb[2], eg, what)
	Near(rgb[3], eb, what)
end

local function Listening(env, event)
	for key in pairs(env._glyph) do
		if key:sub(-#event - 1) == "|" .. event then return true end
	end
	return false
end

local function Power(env, value)
	env._power = value
	env.FireEvent("UNIT_POWER_FREQUENT", "player", env._token)
end

local function Value(bar)
	local v = bar._state.Value
	return v[1], v[2]
end

local function Kind(group, kind)
	for _, a in ipairs(group._anims) do
		if a._type == kind then return a end
	end
end


local function Has(list, item)
	for _, x in ipairs(list or {}) do
		if x == item then return true end
	end
	return false
end

local function Targets(group)
	local set = {}
	for _, a in ipairs(group._anims) do
		if a._type == "Rotation" then set[a._state.Target and a._state.Target[1] or group:GetParent()] = a end
	end
	return set
end

local function Cap(ns)
	for _, kid in ipairs(ns.Slab.hub._kids) do
		if kid.glyphs and kid.halo and kid.breath then return kid end
	end
end

local function Curves(env, share)
	env._share = share
	env.UnitPowerPercent = function(_, _, _, curve) return curve and curve.at and (env._share >= curve.at and 1 or 0) or env._share end
	env.C_CurveUtil = { CreateCurve = function()
		local c = {}
		function c.SetType() end
		function c.AddPoint(_, x, y) if y == 1 and not c.at then c.at = x end end
		return c
	end }
end

-- Glyph tide: two bars, one eased and one immediate, so a gain eases and a spend drops at once with no Lua compare.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE")
	local tide, hub = ns.SlabGlyphs.tide, ns.Slab.hub
	local eased, now = tide.eased, tide.now
	assert(tide.frame and tide.frame:IsShown() and eased:GetOrientation() == "VERTICAL" and now:GetOrientation() == "VERTICAL", "a warrior's tide is two vertical bars on the crest")
	assert(tide.frame:GetFrameLevel() == hub:GetFrameLevel() + 1, "it lights the glyph layer the cap ring lights")
	for _, t in ipairs({ tide.lit, tide.core, tide.fringe }) do
		assert(Has(t._masks, tide.easedMask) and Has(t._masks, tide.nowMask), "each lit layer shows only under both fills: the lower one wins, so a spend drops at once")
		assert(t._state.BlendMode[1] == "ADD", "and adds its light")
	end
	assert(select(2, tide.easedMask:GetPoint(1)) == eased:GetStatusBarTexture() and select(2, tide.nowMask:GetPoint(1)) == now:GetStatusBarTexture(), "the masks follow the fills, so the glyphs never squash")
	assert(eased:GetStatusBarTexture():GetAlpha() == 0 and now:GetStatusBarTexture():GetAlpha() == 0, "the fills themselves draw nothing")
	assert(Has(hub.runes._masks, tide.above) and select(2, tide.above:GetPoint(1)) == now:GetStatusBarTexture(), "the turning band shows only above the tide")
	local v, mode = Value(eased)
	assert(v == 20 and mode == 0 and Value(now) == 20, "built at once from UnitPower over UnitPowerMax")
	local lr, lg, lb = K.Theme.Brighten(1, 0, 0)
	Same("the lit runes are the power bar's colour", { tide.lit:GetVertexColor() }, lr, lg, lb)
	Same("the fringe too", { tide.fringe:GetVertexColor() }, lr, lg, lb)
	local cr, cg, cb = tide.core:GetVertexColor()
	assert(cr >= lr and cg > lg and cb > lb, "a paler core lights the strokes from within")
	Power(env, 60)
	v, mode = Value(eased)
	local nv, nmode = Value(now)
	assert(v == 60 and mode == 1 and nv == 60 and nmode == 0, "a gain eases the one bar and sets the other")
	local secret = env.Secret(80)
	Power(env, secret)
	assert(Value(eased) == secret and Value(now) == secret, "a secret value reaches both bars, which compare it")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	Power(env, 40)
	v, mode = Value(eased)
	assert(v == 40 and mode == 0, "Off sets the tide at once")
	Clean(env, K, "tide")
end

-- The cap ring: the tide's last step in the tide's colour, its own art swapped for a band glow and an outer glow on a 4.2 s
-- breath; the old ring, at 1.3 times over the hub on a 2.2 s breath, when the tide is off.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE")
	Curves(env, 1)
	ns.SlabEffects.UpdateCap()
	local cap, hub = Cap(ns), ns.Slab.hub
	assert(cap and cap:IsShown(), "the cap ring stands at full")
	assert(not cap.glyphs:IsShown() and not cap.halo:IsShown() and cap.band:IsShown() and cap.outer:IsShown(), "with the tide on, the lit band and an outer glow replace the cap's own glyphs and halo")
	assert(cap.outer:GetParent():GetFrameLevel() < hub:GetFrameLevel(), "the outer glow sits under the hub, off the emblem")
	assert(cap.outer:GetHeight() / 2 < 130, "and fades out before the screen's edge")
	Same("in the tide's colour", { cap.band:GetVertexColor() }, K.Theme.Brighten(1, 0, 0))
	assert(math.abs(Kind(cap.breath, "Alpha")._state.Duration[1] - 2.1) < 1e-6, "breathing over 4.2 s")
	K.Options.Write("ActionBars", "crestTide", false)
	env.RunTimers()
	assert(cap.glyphs:IsShown() and cap.halo:IsShown() and not cap.band:IsShown() and not cap.outer:IsShown(), "with the tide off, the old cap ring")
	assert(cap.halo:GetParent():GetFrameLevel() > hub:GetFrameLevel() and math.abs(cap.halo:GetWidth() - 1.3 * 150) < 1, "its halo 1.3 times the ring over the hub, as before")
	assert(math.abs(Kind(cap.breath, "Alpha")._state.Duration[1] - 1.1) < 1e-6, "on its old breath")
	Clean(env, K, "cap")
end

-- Full mana reaches the cap while the tide shows it (in combat); a form's new power reaches it at once.
do
	local env, K, ns = New("MAGE", MANA, "MANA")
	Curves(env, 1)
	ns.SlabEffects.UpdateCap()
	local cap = Cap(ns)
	assert(not (cap and cap:IsShown()), "a resting mage's full mana lights no cap, as before")
	env.SetCombat(true)
	cap = Cap(ns)
	assert(cap and cap:IsShown() and cap.band:IsShown(), "in combat, full mana is the tide's last step")
	env.SetCombat(false)
	assert(not cap:IsShown(), "and goes with the tide after combat")
	Clean(env, K, "mana cap")

	local denv, DK, dns = New("DRUID", MANA, "MANA", { form = 0 })
	Curves(denv, 1)
	dns.SlabEffects.UpdateCap()
	denv._kind, denv._token, denv._form = RAGE, "RAGE", 5
	denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
	denv.FireEvent("UNIT_DISPLAYPOWER", "player")
	cap = Cap(dns)
	assert(cap and cap:IsShown() and cap.band:IsShown(), "a druid shifting to bear with full rage gets the cap at once")
	Clean(denv, DK, "bear cap")
end

-- A mana user's tide shows in combat only, feeds nothing while hidden, and settles away after combat.
do
	local env, K, ns = New("MAGE", MANA, "MANA")
	local tide = ns.SlabGlyphs.tide
	local frame = tide.frame
	assert(frame and not frame:IsShown() and not Has(ns.Slab.hub.runes._masks, tide.above), "a resting mage's tide waits for combat and leaves the band whole")
	local writes = #tide.eased._calls
	Power(env, 50)
	assert(#tide.eased._calls == writes, "a hidden tide reads and writes nothing on a power tick")
	env.SetCombat(true)
	assert(frame:IsShown() and Value(tide.eased) == 50 and Has(ns.Slab.hub.runes._masks, tide.above), "combat shows it, fed afresh, over the band")
	env.SetCombat(false)
	assert(frame.settle:IsPlaying() and Kind(frame.settle, "Alpha")._state.ToAlpha[1] == 0, "leaving combat settles it away")
	frame.settle:GetScript("OnFinished")(frame.settle)
	assert(not frame:IsShown(), "and hides it once settled")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	env.SetCombat(true)
	env.SetCombat(false)
	assert(not frame:IsShown() and not frame.settle:IsPlaying(), "Off hides it at once")
	K.Options.Write("ActionBars", "crestTide", false)
	env.RunTimers()
	assert(not frame:IsShown() and not Listening(env, "UNIT_POWER_FREQUENT"), "its switch hides it and stops its power events")
	K.Options.Write("ActionBars", "crestTide", true)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	env.SetCombat(true)
	assert(not frame:IsShown() and not Listening(env, "UNIT_POWER_FREQUENT"), "under Frames there is no tide")
	Clean(env, K, "mana")
end

-- Stance mantle: the whole band, lit and unlit, turns one notch together; the old ink cross-fades into the new.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE", { form = 17 })
	local m, tide, hub = ns.SlabGlyphs.mantle, ns.SlabGlyphs.tide, ns.Slab.hub
	local runes, ink = hub.runes, m.ink
	local band = { runes, ink, tide.lit, tide.core }
	Same("Battle Stance tints the band's glyphs gilt", { runes:GetVertexColor() }, K.Tokens.Color("gilt"))
	assert(m.halo:IsShown() and math.abs(m.halo:GetAlpha() - 1) < 1e-6, "and lights the inner rim fully")
	assert(math.abs(runes:GetAlpha() - 0.7) < 1e-6, "a worn mantle lifts the band's glyphs from 0.25, so the tint reads")
	assert(not m.turn:IsPlaying() and not m.ripple:IsShown() and not runes.lift:IsPlaying() and not ink:IsShown(), "the first paint moves nothing")
	local turning = Targets(runes.turn)
	for _, t in ipairs(band) do
		assert(turning[t], "every glyph layer turns with the band's own turn, so lit and unlit stay in phase")
	end
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Same("Defensive Stance tints them steel blue", { runes:GetVertexColor() }, K.Tokens.Color("magic"))
	local notch = Targets(m.turn)
	for _, t in ipairs(band) do
		local a = notch[t]
		assert(a and a._state.Degrees[1] == -30 and a._state.Duration[1] == 0.3 and a._state.Smoothing[1] == "OUT", "the whole band, the lit part too, turns one notch in 0.3 s easing out")
	end
	assert(m.turn:IsPlaying(), "the notch plays")
	assert(ink:IsShown() and ink.fade:IsPlaying() and Kind(ink.fade, "Alpha")._state.ToAlpha[1] == 0 and Kind(ink.fade, "Alpha")._state.Duration[1] == 0.25, "the old ink fades out over 0.25 s")
	Same("in the old tint", { ink:GetVertexColor() }, K.Tokens.Color("gilt"))
	assert(runes.lift:IsPlaying() and Kind(runes.lift, "Alpha")._state.FromAlpha[1] == 0, "while the new ink fades in")
	assert(m.ripple:IsShown() and m.ripple.anim:IsPlaying(), "the old rim lifts off as a ripple")
	Same("in the old tint", { m.ripple:GetVertexColor() }, K.Tokens.Color("gilt"))
	Near(Kind(m.ripple.anim, "Scale")._state.ScaleTo[1] * 122 - 122, 20, "ten units outward")
	m.turn:GetScript("OnFinished")(m.turn)
	for _, t in ipairs(band) do
		Near(t:GetRotation(), 2 * math.pi - math.rad(30), "every glyph layer keeps the notch when the turn ends")
	end
	env._form = 5
	ns.SlabGlyphs.Update()
	env._form = 8
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(m.turn:IsPlaying() and m.ripple.anim:IsPlaying(), "a new form ID turns the band even in the same tint (Bear to Dire Bear)")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	assert(not m.turn:IsPlaying() and not m.ripple:IsShown() and not m.halo.fade:IsPlaying() and not runes.lift:IsPlaying() and not ink:IsShown() and not hub.crest.dim:IsPlaying(), "Motion Off stops every effect in flight")
	for _, t in ipairs(band) do
		Near(t:GetRotation(), 2 * math.pi - math.rad(90), "and lands the notch")
	end
	env._form = 19
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Same("Berserker Stance tints them ember", { runes:GetVertexColor() }, K.Tokens.Color("schoolFire"))
	assert(not m.turn:IsPlaying() and not m.ripple:IsShown() and not ink:IsShown(), "Off plays nothing")
	Near(runes:GetRotation(), 2 * math.pi - math.rad(120), "and still lands the notch")
	env._aurasSecret = true
	env._form = env.Secret(18)
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Same("a secret form keeps the last tint", { runes:GetVertexColor() }, K.Tokens.Color("schoolFire"))
	env._form = 17
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Same("and the form is read again when the restriction ends", { runes:GetVertexColor() }, K.Tokens.Color("gilt"))
	Clean(env, K, "mantle")
end

-- Both switches off: the crest exactly as it was, whatever the mantle and tide did before.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE", { form = 17 })
	Curves(env, 1)
	ns.SlabEffects.UpdateCap()
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local m, tide, hub = ns.SlabGlyphs.mantle, ns.SlabGlyphs.tide, ns.Slab.hub
	m.turn:GetScript("OnFinished")(m.turn)
	K.Options.Write("ActionBars", "crestTide", false)
	K.Options.Write("ActionBars", "crestMantle", false)
	env.RunTimers()
	local runes = hub.runes
	Same("the band's glyphs take the class colour", { runes:GetVertexColor() }, K.Theme.ClassColor("WARRIOR"))
	assert(math.abs(runes:GetAlpha() - 0.25) < 1e-6 and (runes:GetRotation() or 0) == 0 and (runes:GetNumMaskTextures() or 0) == 0, "at their own alpha, unturned and unmasked")
	assert(not tide.frame:IsShown() and not m.frame:IsShown() and not m.ink:IsShown() and hub.crest:GetAlpha() == 1, "and nothing of either shows")
	local cap = Cap(ns)
	assert(cap.glyphs:IsShown() and cap.halo:IsShown() and not cap.band:IsShown() and not cap.outer:IsShown(), "the cap ring is the old one")
	ns.SlabGlyphs.Update()
	assert(not Listening(env, "UPDATE_SHAPESHIFT_FORM") and not Listening(env, "UNIT_POWER_FREQUENT"), "and nothing listens")
	Clean(env, K, "both off")
end

-- Stealth dims the emblem; Travel Form is teal; leaving a form drops the rim; a hunter gets nothing.
do
	local env, K, ns = New("ROGUE", 3, "ENERGY", { form = 0 })
	local m, hub = ns.SlabGlyphs.mantle, ns.Slab.hub
	assert(not m.halo:IsShown() and hub.crest:GetAlpha() == 1, "out of Stealth no rim and a full emblem")
	env._form = 30
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Same("Stealth gives violet glyphs", { hub.runes:GetVertexColor() }, K.Tokens.Color("schoolShadow"))
	assert(math.abs(hub.crest:GetAlpha() - 0.55) < 1e-6 and hub.crest.dim:IsPlaying(), "and dims the emblem")
	assert(m.ripple:IsShown() and m.turn:IsPlaying(), "entering a form ripples and turns too")
	env._form = 0
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(hub.crest:GetAlpha() == 1 and not m.halo:IsShown(), "leaving Stealth brings the emblem back and drops the rim")
	Same("and the class colour", { hub.runes:GetVertexColor() }, K.Theme.ClassColor("ROGUE"))
	Clean(env, K, "stealth")

	local denv, DK, dns = New("DRUID", MANA, "MANA", { form = 3 })
	Same("Travel Form is teal", { dns.Slab.hub.runes:GetVertexColor() }, DK.Tokens.Color("mantleTravel"))
	Clean(denv, DK, "travel")

	local henv, HK, hns = New("HUNTER", MANA, "MANA", { form = 3 })
	local hm = hns.SlabGlyphs.mantle
	assert(not hm.on and not hm.frame:IsShown() and not Listening(henv, "UPDATE_SHAPESHIFT_FORM"), "a hunter has no form and no mantle")
	Clean(henv, HK, "hunter")
end

-- Built only out of combat; work the restriction held back runs when it ends.
do
	local fresh, fK, fns = New("WARRIOR", RAGE, "RAGE", { form = 17, off = true })
	fresh._aurasSecret = true
	fresh.SetCombat(true)
	fK.Options.Write("ActionBars", "crestTide", true)
	fK.Options.Write("ActionBars", "crestMantle", true)
	fresh.RunTimers()
	assert(not fns.SlabGlyphs.tide.frame and not fns.SlabGlyphs.mantle.frame, "switched on in combat, nothing is built or anchored")
	fresh._aurasSecret = false
	fresh.SetCombat(false)
	assert(fns.SlabGlyphs.tide.frame and fns.SlabGlyphs.tide.frame:IsShown() and fns.SlabGlyphs.mantle.frame and fns.SlabGlyphs.mantle.halo:IsShown(), "combat's end builds both")
	Clean(fresh, fK, "deferred build")

	local s, sK, sns = New("WARRIOR", RAGE, "RAGE", { secretKind = true })
	assert(not Listening(s, "UNIT_POWER_FREQUENT"), "a secret power type subscribes nothing")
	s._secretKind = false
	s.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	assert(Listening(s, "UNIT_POWER_FREQUENT") and sns.SlabGlyphs.tide.frame:IsShown(), "the restriction's end subscribes the tide")
	Clean(s, sK, "secret kind")
end

-- Frames: only the active stance button's rim takes the tint.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE", { form = 18, frames = true })
	local g = env._game
	g.forms = { { texture = 1, isActive = false, spellID = 2457 }, { texture = 2, isActive = true, spellID = 71 }, { texture = 3, isActive = false, spellID = 2458 } }
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	env._form = 17
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local stance = ns.stanceButtons
	local tinted
	for i, b in ipairs(stance) do
		if b.mantle then
			tinted = i
			Same("the active stance's rim takes Defensive Stance's steel blue", { b.accent[1], b.accent[2], b.accent[3] }, K.Tokens.Color("magic"))
		end
	end
	assert(tinted == 2, "only the active stance button is tinted")
	local accent = ns.AccentRGB()
	assert((stance[1].accent and stance[1].accent[1]) == accent, "the others keep the accent")
	assert(not ns.SlabGlyphs.tide.frame or not ns.SlabGlyphs.tide.frame:IsShown(), "Frames has no tide")
	K.Options.Write("ActionBars", "crestMantle", false)
	env.RunTimers()
	assert(not stance[2].mantle, "its switch gives the rim back")
	assert((stance[2].accent and stance[2].accent[1]) == accent, "to the accent")
	Clean(env, K, "frames")
end

-- In combat with auras secret: no forbidden writes, nothing under an aura button, nothing on OnUpdate.
do
	local env, K, ns = New("WARRIOR", RAGE, "RAGE", { form = 17 })
	env._aurasSecret = true
	env.SetCombat(true)
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Power(env, env.Secret(55))
	env._max = env.Secret(100)
	env.FireEvent("UNIT_MAXPOWER", "player", "RAGE")
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Clean(env, K, "combat")
	local m, tide = ns.SlabGlyphs.mantle, ns.SlabGlyphs.tide
	for _, f in ipairs({ m.frame, tide.frame, tide.eased, tide.now }) do
		assert(not f:GetScript("OnUpdate"), "nothing runs OnUpdate")
	end
	for _, region in ipairs({ m.frame, m.halo, m.ripple, m.ink, tide.frame, tide.lit, tide.core, tide.fringe, tide.eased, tide.now }) do
		local node = region
		while node do
			assert(node:GetObjectType() ~= "AuraContainer" and not node._restricted, "no glyph part sits under an engine aura button")
			node = node:GetParent()
		end
	end
	env.SetCombat(false)
	env._aurasSecret = false
	Clean(env, K, "after combat")
end

print("actionbars medallions glyphs ok")
