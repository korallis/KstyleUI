-- test-actionbars-medallions-class-crowns.lua: the Medallions crowns the game feeds: a warrior's 5 banners (Sunder Armor on the target), a priest's 5 candles (Shadow Weaving, with the talent only), a mage's 4 shards (Arcane Blast), a hunter's 3 arrows (Sniper Shot) clear of the hawk perches, and a bear's 5 talons (Lacerate); each piece's glow and lit art are application bars in Blizzard's aura slots that the game feeds (the art sweeping in under ExponentialEaseOut, Immediate at Motion Off), the maximum lights the rune ring in the class colour, a lost aura clears them, nothing shows without the source, the setting off hides it all, and no class listens for another's events.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local KNOWN = { WARRIOR = 7386, PRIEST = 15257, MAGE = 400574, HUNTER = 1310687, DRUID = 1328617 }
local AURAS = { WARRIOR = 7386, PRIEST = 15258, MAGE = 400573, HUNTER = 1310687, DRUID = 1328617 }
local SPEC = {
	WARRIOR = { art = "PipBanner", count = 5, unit = "target", angles = { 130, 110, 90, 70, 50 } },
	PRIEST = { art = "PipCandle", count = 5, unit = "target", angles = { 130, 110, 90, 70, 50 } },
	MAGE = { art = "PipShard", count = 4, unit = "player", angles = { 130, 110, 70, 50 } },
	HUNTER = { art = "PipArrow", count = 3, unit = "player", angles = { 105, 90, 75 } },
	DRUID = { art = "PipTalon", count = 5, unit = "target", angles = { 130, 110, 90, 70, 50 } },
}
local ORDER = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "DRUID" }
local EXTRA = { "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED" }

local function New(class, opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			if opts.engine ~= false then
				Slots.Install(e)
			end
			e._powerType = class == "DRUID" and 1 or 0
			e.UnitPowerType = function() return e._powerType end
			e.UnitPower = function(_, kind) return kind == 0 and 1500 or 0 end
			e.UnitPowerMax = function(_, kind) return kind == 0 and 3000 or 5 end
			e.GetComboPoints = function() return 0 end
			e.GetTotemInfo = function() return false, "", 0, 0, 0, 1, 0 end
			e.GetTotemDuration = function() return { start = 0, finish = 0 } end
			if opts.setup then opts.setup(e) end
		end,
	})
	env.C_SpellBook.IsSpellKnown = function(id)
		return opts.known ~= false and (id == KNOWN[class] or class == "HUNTER" and id == 1293241)
	end
	AB.Enable(env, K)
	-- The crown alone: the glyph tide listens to the main power, and test-actionbars-medallions-glyphs covers it.
	K.Options.Write("ActionBars", "crestTide", false)
	env.RunTimers()
	return env, K, ns
end

local function Last(region, method)
	local calls = region._calls
	for i = #calls, 1, -1 do
		if calls[i].method == method then return calls[i].args end
	end
end

local function Reveal(env, value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

local function Listening(env, event)
	local n = 0
	for _, f in ipairs(env._frames) do
		if f._events and f._events[event] then n = n + 1 end
	end
	return n
end

local function Clean(env, K, where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function Lit(p)
	return Slots.Engine(p.env, function()
		local bar = p.blade
		local low = bar:GetMinMaxValues()
		return bar:IsShown() and bar:GetParent():IsShown() and Reveal(p.env, Last(bar, "SetValue")[1]) > low
	end)
end

for _, class in ipairs(ORDER) do
	local spec = SPEC[class]
	local env, K, ns = New(class)
	local S = ns.SlabCrown.state
	local crown = S.crown
	assert(crown and #crown.pips == spec.count and not S.shown, class .. ": the crest wears a fed crown of " .. spec.count)
	for i, p in ipairs(crown.pips) do
		p.env = env
		local angle = spec.angles[i]
		assert(tostring(Last(p.steel, "SetTexture")[1]):find(spec.art .. "Steel" .. angle .. ".png", 1, true), class .. " piece " .. i .. " is dormant art at " .. angle)
		if class == "HUNTER" then
			-- The aura plan: a hunter's arrows burn as Blender auras, each the shot's arrow figure at its angle over its body drawn black.
			local a = p.aura
			local bar = a.bars[1]
			local fill, low, high = bar:GetStatusBarTexture(), bar:GetMinMaxValues()
			for _, t in ipairs({ a.moving, a.still }) do
				local clip = t:GetParent()
				assert(select(2, clip:GetPoint(1)) == fill and select(2, clip:GetPoint(2)) == fill and Last(clip, "SetClipsChildren")[1] == true and low == i - 1 and high == i,
					"arrow " .. i .. " shows only inside its own stack's application bar fill")
				assert(tostring(Last(t, "SetTexture")[1]):find("Auras\\Figures\\Arrow" .. angle .. ".png", 1, true) and Last(t, "SetBlendMode")[1] == "ADD", "arrow " .. i .. " burns the arrow figure's aura at " .. angle)
			end
			assert(a.still:GetParent():GetParent() == bar and a.moving:GetParent():GetParent() == crown.burn, "the still copy sits on the arrow's aura slot and the burning copy on the crown's own layer")
			assert(tostring(Last(p.blade, "SetStatusBarTexture")[1]):find(spec.art .. angle .. ".png", 1, true) and Last(p.blade, "SetStatusBarColor")[1] + Last(p.blade, "SetStatusBarColor")[2] + Last(p.blade, "SetStatusBarColor")[3] == 0, "over the arrow's body swept up in black")
		else
			assert(tostring(Last(p.blade, "SetStatusBarTexture")[1]):find(spec.art .. angle .. ".png", 1, true), class .. " piece " .. i .. " lights its own art")
		end
		local _, _, _, x, y = p.frame:GetPoint(1)
		assert(math.abs(math.deg(math.atan2(y, x)) - angle) < 1, class .. " piece " .. i .. " fans out at " .. angle)
		local low, high = p.blade:GetMinMaxValues()
		assert(low == i - 1 and high == i, class .. " piece " .. i .. " is a one-point application bar")
		assert(Last(p.blade, "SetOrientation")[1] == "VERTICAL", "the art sweeps up from its base")
		assert(not p.blade:GetParent():IsShown(), class .. ": no aura, every piece dormant")
		assert(not p.frame._scripts.OnUpdate, "no piece runs OnUpdate")
	end
	assert(not crown.max:GetParent():IsShown(), class .. ": the ring waits for the maximum")
	assert(K.Widgets.ClassCrown() == S.line, class .. ": the crest tells the unit frames it shows the crown")
	assert(Listening(env, "PLAYER_TOTEM_UPDATE") == (class == "HUNTER" and 1 or 0), class .. " never listens for totems (a hunter's hawks do)")
	assert(Listening(env, "UNIT_POWER_FREQUENT") == 0 or class == "DRUID", class .. " does not count combo points")

	-- A gain is fed by the game: the count reaches the bars as a secret, the lit art eased, the glow at once.
	local aura = { id = AURAS[class], count = 1, harmful = spec.unit == "target", mine = true }
	Slots.Set(env, spec.unit, { aura })
	assert(Lit(crown.pips[1]) and not Lit(crown.pips[2]), class .. ": one stack lights one piece")
	aura.count = spec.count - 1
	Slots.Set(env, spec.unit, { aura })
	for i, p in ipairs(crown.pips) do
		local value, mode = unpack(Last(p.blade, "SetValue"))
		assert(env.issecretvalue(value), class .. " piece " .. i .. " gets the secret count")
		assert(mode == 1 and Last(p.halo, "SetValue")[2] == 0, class .. ": the art eases in over the glow, which lights at once")
		assert(Lit(p) == (i < spec.count), class .. " piece " .. i .. " at " .. aura.count)
	end
	assert(not crown.max:IsShown(), class .. ": below the maximum the ring stays dark")
	aura.count = spec.count
	Slots.Set(env, spec.unit, { aura })
	assert(crown.max:IsShown() and crown.max:GetParent():IsShown(), class .. ": the maximum lights the ring")
	local r, g, b = K.Theme.ClassColor(class)
	local glyphs = crown.max._kids[1]._regions[1]
	local vr, vg, vb = unpack(Last(glyphs, "SetVertexColor"))
	assert(vr == r and vg == g and vb == b and tostring(Last(glyphs, "SetTexture")[1]):find("RuneGlyphs", 1, true), class .. ": in the class colour")

	-- Motion Off binds Immediate; the aura going clears every piece at once.
	K.Options.Write("Medallions", "motion", "off")
	aura.count = 2
	Slots.Set(env, spec.unit, { aura })
	assert(Last(crown.pips[1].blade, "SetValue")[2] == 0, class .. ": Off shows the end state")
	K.Options.Write("Medallions", "motion", "full")
	Slots.Set(env, spec.unit, nil)
	for _, p in ipairs(crown.pips) do
		assert(not p.blade:GetParent():IsShown() and p.frame:IsShown(), class .. ": a lost aura leaves the dormant crown")
	end

	-- The setting off hides the crown, disables the game's feed and stops listening; on again brings it back.
	local listening, extra = Listening(env, "PLAYER_TARGET_CHANGED"), {}
	for i, event in ipairs(EXTRA) do extra[i] = Listening(env, event) end
	K.Store.Profile().UnitFrames = { resource = { classPips = false } }
	K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", false)
	assert(not crown.holder:IsShown() and crown.container._enabled == false and not K.Widgets.ClassCrown(), class .. ": off hides it, stops the feed and gives the row back")
	assert(spec.unit ~= "target" or Listening(env, "PLAYER_TARGET_CHANGED") == listening - 1, class .. ": off stops following the target")
	for i, event in ipairs(EXTRA) do
		local want = class == "DRUID" and event ~= "PLAYER_REGEN_ENABLED" and 1 or 0
		assert(extra[i] - Listening(env, event) == want, class .. "'s crown listens for " .. event .. " only when it needs it")
	end
	K.Store.Profile().UnitFrames.resource.classPips = true
	K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", true)
	assert(crown.holder:IsShown() and crown.container._enabled == true, class .. ": on again")
	Clean(env, K, class)

	-- No source, no crown: the spell unknown, or the game's aura slots missing.
	local nenv, NK, nns = New(class, { known = false })
	assert(not nns.SlabCrown.state.crown and #nenv._slotContainers == (class == "DRUID" and 1 or 0), class .. " without the spell has no crown")
	Clean(nenv, NK, class .. " unknown")
	local menv, MK, mns = New(class, { engine = false })
	assert(not mns.SlabCrown.state.crown, class .. " without the aura engine draws nothing")
	Clean(menv, MK, class .. " no engine")
end

-- A druid's talons are its bear form's; cat form keeps the claws and caster form shows nothing.
do
	local env, K, ns = New("DRUID")
	local S = ns.SlabCrown.state
	env._powerType = 3
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(S.shown and not S.crown and not S.crowns.BEAR.holder:IsShown(), "cat form: the claws, not the talons")
	env._powerType = 0
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(not S.shown and not S.crown, "caster form: no crown")
	env._powerType = 1
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(S.crown and S.crown.holder:IsShown(), "bear form: the talons again")
	assert(S.line and K.Widgets.ClassCrown() == S.line, "and seats the druid bar above them")
	Clean(env, K, "druid forms")
end

-- A druid who starts in caster form and first shifts to bear while the game guards its aura buttons finds the talons bound.
do
	local lock = false
	local env, K, ns = New("DRUID", { setup = function(e)
		e._powerType = 0
		e.C_Secrets = e.C_Secrets or {}
		e.C_Secrets.ShouldAurasBeSecret = function() return lock end
	end })
	local bear = ns.SlabCrown.state.crowns.BEAR
	lock = true
	env._powerType = 1
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Slots.Set(env, "target", { { id = AURAS.DRUID, count = 5, harmful = true, mine = true } })
	for _, f in ipairs(bear.feeds) do
		assert(f.button._applicationBar, "the talons were bound while the game allowed it")
	end
	bear.pips[5].env = env
	assert(bear.holder:IsShown() and Lit(bear.pips[5]) and Slots.Engine(env, bear.max.IsShown, bear.max), "so five Lacerate stacks light every talon and the ring")
	local r, g, b = K.Theme.ClassColor("DRUID")
	for _, t in ipairs(bear.ring) do
		local vr, vg, vb = unpack(Last(t, "SetVertexColor") or {})
		assert(vr == r and vg == g and vb == b, "the ring wears the druid's colour, tinted when the talons were built")
	end
	Clean(env, K, "first bear form")
end

-- A spellbook update or the end of combat leaves a gain playing on the combo crowns.
for _, class in ipairs({ "ROGUE", "DRUID" }) do
	local env, K, ns = New(class)
	env._powerType = 3
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env.GetComboPoints = function() return 1 end
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	local rise = ns.SlabCrown.state.pips[1].rise
	for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
		env.FireEvent(event)
		assert(rise:IsShown() and rise.anim:IsPlaying(), class .. ": " .. event .. " leaves the gain playing")
	end
	Clean(env, K, class .. " combo motion")
end

-- A palette edit recolours the full ring as it does the crest's other class colours.
do
	local env, K, ns = New("MAGE")
	K.Theme.SetPalette({ MAGE = { r = 0.77, g = 0.12, b = 0.33 } }, 0)
	env.RunTimers()
	for _, frame in ipairs(ns.SlabCrown.state.crown.max._kids) do
		local r, g, b = unpack(Last(frame._regions[1], "SetVertexColor"))
		assert(r == 0.77 and g == 0.12 and b == 0.33, "the ring takes the edited class colour")
	end
	Clean(env, K, "palette")
end

-- Aura slots without the application bar cannot be fed: no crown, and the unit frames keep the seat.
do
	local env, K, ns = New("MAGE", { setup = function(e)
		local create = e.CreateFrame
		e.CreateFrame = function(kind, ...)
			local frame = create(kind, ...)
			if kind == "AuraContainer" then
				local add = frame.AddAuraSlot
				frame.AddAuraSlot = function(self, ...)
					local button = add(self, ...)
					button.SetApplicationBar = false
					return button
				end
			end
			return frame
		end
	end })
	assert(not ns.SlabCrown.state.crown and not K.Widgets.ClassCrown(), "no application bar: nothing shows and the seat stays free")
	Clean(env, K, "no application bar")
end

-- A priest without Shadow Weaving gets nothing, and learning it brings the candles.
do
	local learned = false
	local env, K, ns = New("PRIEST", { known = false })
	assert(not ns.SlabCrown.state.crown, "a priest without the talent has no crown")
	env.C_SpellBook.IsSpellKnown = function(id) return learned and id == 15257 end
	learned = true
	env.FireEvent("SPELLS_CHANGED")
	assert(ns.SlabCrown.state.crown, "learning Shadow Weaving lights the candles' crown")
	Clean(env, K, "priest talent")
end

-- While the game keeps auras secret the slots are not built; they are once it stops.
do
	local secret = true
	local env, K, ns = New("WARRIOR", { setup = function(e)
		e.C_Secrets = e.C_Secrets or {}
		e.C_Secrets.ShouldAurasBeSecret = function() return secret end
	end })
	assert(not ns.SlabCrown.state.crown and #env._slotContainers == 0, "secret auras: nothing is built")
	secret = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(ns.SlabCrown.state.crown, "built once auras are open")
	local blade = ns.SlabCrown.state.crown.pips[1].blade
	local slot = blade:GetParent()
	assert(slot._applicationBar[2].interpolation == 1, "Full eases the art in")
	local bind, tries = slot.SetApplicationBar, 0
	slot.SetApplicationBar = function(...) tries = tries + 1 return bind(...) end
	secret = true
	K.Options.Write("Medallions", "motion", "off")
	assert(tries == 0 and slot._applicationBar[2].interpolation == 1, "while the game guards its aura buttons the binding waits, untried")
	secret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
	assert(slot._applicationBar[2].interpolation == 0, "and Off takes once the restriction ends")
	Clean(env, K, "secret auras")
end

-- The hunter's arrow auras loop only for the Sniper stacks the player holds, only at Full with the crest awake, and never while
-- auras are secret; otherwise each arrow holds its first frame (review of the hunter auras: hidden arrows kept looping, and the
-- loops stayed bound while auras were secret).
do
	local reads = 0
	local env, K, ns = New("HUNTER", { setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		e.C_UnitAuras = e.C_UnitAuras or {}
		e.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
			if e._aurasSecret then reads = reads + 1 return nil end
			for _, a in ipairs(e._slotAuras.player or {}) do
				if a.id == id then return { spellId = id, applications = a.count } end
			end
		end
	end })
	local crown = ns.SlabCrown.state.crown
	local function Burning()
		local lit = {}
		for i, p in ipairs(crown.pips) do
			local a = p.aura
			assert(a.loop:IsPlaying() == a.lit:IsShown(), "arrow " .. i .. " loops exactly while it shows")
			assert(a.gate:GetAlpha() == (a.lit:IsShown() and 0 or 1), "arrow " .. i .. "'s still copy shows exactly while it does not burn")
			lit[i] = a.loop:IsPlaying() and "1" or "0"
		end
		return table.concat(lit)
	end
	local sniper = { id = 1310687, count = 1 }
	local function Stack(n)
		sniper.count = n
		Slots.Set(env, "player", n > 0 and { sniper } or nil)
		env.FireEvent("UNIT_AURA", "player", {})
	end
	env.SetTarget(true)
	env.RunTimers()
	assert(Burning() == "000", "at Full with the crest awake and no stack, nothing loops")
	Stack(1)
	assert(Burning() == "100", "one stack burns the first arrow alone")
	Stack(2)
	assert(Burning() == "110", "two stacks burn two arrows")
	Stack(3)
	assert(Burning() == "111", "three stacks burn all three")
	Stack(1)
	assert(Burning() == "100", "losing two stacks stops the second and third arrows' loops")
	local third = crown.pips[3].aura
	assert(third.still:GetParent():GetParent() == third.bars[1] and third.gate:GetAlpha() == 1, "and hands each back to its still copy on the stack's fill, which drains")
	AB.Hiding(env)
	ns.Slab.hub:Hide()
	assert(Burning() == "000", "the crest hidden by an ancestor: every loop stops")
	Stack(2)
	assert(Burning() == "000", "and a stack gained while hidden starts none")
	ns.Slab.hub:Show()
	assert(Burning() == "110", "shown again, the two held stacks burn")
	Stack(2)
	env.SetTarget(false)
	env.RunTimers()
	assert(ns.Slab.Resting() and Burning() == "000", "the crest resting: every loop stops and the still copies show")
	env.SetTarget(true)
	env.RunTimers()
	assert(Burning() == "110", "woken with two stacks still up, their two loops play again")
	K.Options.Write("Medallions", "motion", "calm")
	assert(Burning() == "000", "Calm shows the still copies")
	K.Options.Write("Medallions", "motion", "full")
	assert(Burning() == "110", "back to Full the held stacks burn")
	env._aurasSecret = true
	env.FireEvent("UNIT_AURA", "player", {})
	assert(Burning() == "000", "auras going secret stop every loop and the engine-fed still copies show")
	Stack(3)
	assert(Burning() == "000", "a stack gained while auras are secret still burns nothing")
	for _, motion in ipairs({ "calm", "off", "full" }) do
		K.Options.Write("Medallions", "motion", motion)
		assert(Burning() == "000", "while auras are secret, " .. motion .. " plays nothing")
	end
	assert(reads == 0, "and the crown never reads an aura while auras are secret")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
	assert(Burning() == "111", "once the restriction ends the three held stacks burn")
	Stack(0)
	assert(Burning() == "000", "the aura gone, nothing loops")
	Clean(env, K, "hunter arrow auras")
end

-- The hunter's arrows stay clear of the hawk perches.
do
	local env, K, ns = New("HUNTER")
	local hawks = ns.SlabHawks.state.perches
	assert(#hawks == 2 and hawks[1].holder:IsShown(), "the hunter knows Summon Hawk, so the perches show")
	for _, p in ipairs(ns.SlabCrown.state.crown.pips) do
		local _, _, _, x, y = p.frame:GetPoint(1)
		for _, perch in ipairs(hawks) do
			local _, _, _, hx, hy = perch.holder:GetPoint(1)
			local side = math.rad(p.axis)
			local across = math.abs((hx - x) * math.sin(side) - (hy - y) * math.cos(side))
			assert(across > 21 + 6, "arrow " .. p.i .. " passes the perch at " .. hx .. " by " .. across)
		end
	end
	Clean(env, K, "hunter perches")
end


-- Classes with no crown, and a priest without Shadow Weaving, create no slots and listen for nothing new.
for _, class in ipairs({ "PALADIN", "WARLOCK", "ROGUE", "SHAMAN", "PRIEST" }) do
	local env, K, ns = New(class, { known = class ~= "PRIEST" })
	assert(not ns.SlabCrown.state.crown and #env._slotContainers == 0, class .. " has no fed crown")
	local events = { "PLAYER_TOTEM_UPDATE", "PLAYER_TARGET_CHANGED", unpack(EXTRA) }
	local on = {}
	for i, event in ipairs(events) do on[i] = Listening(env, event) end
	K.Store.Profile().UnitFrames = { resource = { classPips = false } }
	K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", false)
	for i, event in ipairs(events) do
		local crowned = class == "ROGUE" and event ~= "PLAYER_TOTEM_UPDATE" and event ~= "PLAYER_REGEN_ENABLED" and 1 or 0
		assert(on[i] == Listening(env, event) + crowned, class .. " listens for " .. event .. " only for its own crown")
	end
	Clean(env, K, class)
end

print("actionbars medallions class crowns ok")
