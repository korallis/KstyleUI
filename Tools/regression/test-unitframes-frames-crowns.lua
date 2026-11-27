-- test-unitframes-frames-crowns.lua: under Frames the player's class resource row holds the crowns the game feeds, upright, as the rogue's daggers stand: a warrior's 5 banners, a priest's 5 candles (with Shadow Weaving only), a mage's 4 shards, a hunter's 3 arrows, a bear's 5 talons standing on its druid bar, which keeps its own height and place and a shaman's 3 Lightning Shield storm orbs; each piece is the dagger's size, centred on the plain pips' places, its glow and lit art application bars Blizzard's aura slots feed (Immediate at Motion Off), the full row glows at the maximum, and the row has a mover; Class-themed pips off, Medallions or no source shows nothing; a spellbook update brings a learnt crown and secret auras put the build off until combat ends.
local U = dofile("Tools/regression/unitframes_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local W = U.W

local SPEC = {
	WARRIOR = { art = "PipBanner", count = 5, unit = "target", known = 7386, aura = 7386 },
	PRIEST = { art = "PipCandle", count = 5, unit = "target", known = 15257, aura = 15258 },
	MAGE = { art = "PipShard", count = 4, unit = "player", known = 400574, aura = 400573 },
	HUNTER = { art = "PipArrow", count = 3, unit = "player", known = 1310687, aura = 1310687 },
	DRUID = { art = "PipTalon", count = 5, unit = "target", known = 1328617, aura = 1328617 },
	SHAMAN = { art = "PipStorm", count = 3, unit = "player", known = 10432, aura = 10432 },
	PALADIN = { art = "PipShard", count = 5, unit = "player", known = 20049, aura = 20050 },
}
local ORDER = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "DRUID", "SHAMAN", "PALADIN" }

local function New(class, opts)
	opts = opts or {}
	local env, K, ns = U.New({
		saved = {
			version = U.DbVersion(),
			profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = { style = opts.style or "frames" } } },
			characters = {},
		},
		setup = function(e)
			Slots.Install(e)
			local player = e._units.player
			player.class = class
			player.powerType, player.powerToken = class == "DRUID" and 1 or class == "ROGUE" and 3 or 0, class == "DRUID" and "RAGE" or "MANA"
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return opts.known ~= false and SPEC[class] and id == SPEC[class].known end
			e.C_UnitAuras = e.C_UnitAuras or {}
			e.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
				for _, a in ipairs(e._slotAuras.player or {}) do
					if a.id == id then return { spellId = id, applications = a.count } end
				end
			end
			if opts.setup then opts.setup(e) end
		end,
	})
	return env, K, ns
end

local function Reveal(env, value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

local function Lit(env, p)
	local bar = p.blade
	local low = bar:GetMinMaxValues()
	local value = W.LastCall(bar, "SetValue")
	return bar:IsShown() and bar:GetParent():IsShown() and value ~= nil and Reveal(env, value[1]) > low
end

local function Clean(env, K, where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function Listening(env, event)
	local n = 0
	for _, f in ipairs(env._frames) do
		if f._events and f._events[event] then n = n + 1 end
	end
	return n
end

-- The rogue's daggers set the size every piece takes; a cat's claws, which share the row with the druid bar, a bear's.
local renv, RK, rns = New("ROGUE")
local dagger = rns.Pips.state.pips[1].frame:GetWidth()
assert(rns.Resource.state.themed and not rns.Resource.state.fed and dagger > 0 and not rns.Pips.state.watching, "a rogue keeps its combo row, no fed crown and no spellbook watch")
Clean(renv, RK, "rogue")
local cenv, CK, cns = New("DRUID", { setup = function(e) e._units.player.powerType, e._units.player.powerToken = 3, "ENERGY" end })
local claw = cns.Pips.state.pips[1].frame:GetWidth()
assert(cns.Resource.state.themed and not cns.Resource.state.fed and claw > 0, "a cat keeps its claws and no fed crown")
Clean(cenv, CK, "cat")

for _, class in ipairs(ORDER) do
	local spec = SPEC[class]
	local env, K, ns = New(class)
	local R, P = ns.Resource.state, ns.Pips.state
	local crown = P.crown
	assert(R.fed and crown and #crown.pips == spec.count, class .. ": the Frames row holds a fed crown of " .. spec.count)
	assert(R.content:IsShown() and crown.holder:IsShown() and K.Layout.Live("unitframes.resource"), class .. ": the row shows and has a mover")
	for i, pip in ipairs(R.pips) do
		assert(not pip:IsShown(), class .. ": plain pip " .. i .. " stays hidden")
	end
	local n = spec.count
	for i, p in ipairs(crown.pips) do
		assert(tostring(W.LastCall(p.steel, "SetTexture")[1]):find(spec.art .. "Steel90.png", 1, true), class .. " piece " .. i .. " is upright dormant steel")
		if class == "HUNTER" then
			-- The aura plan: under Frames too a hunter's arrow burns as the upright arrow figure's aura.
			assert(tostring(W.LastCall(p.aura.moving, "SetTexture")[1]):find("Auras\\Figures\\Arrow90.png", 1, true), "hunter arrow " .. i .. " burns the upright arrow's aura")
			assert(not p.aura.loop:IsPlaying(), "and with no stack held its loop waits")
		else
			assert(tostring(W.LastCall(p.blade, "SetStatusBarTexture")[1]):find(spec.art .. "90.png", 1, true), class .. " piece " .. i .. " lights its upright art")
		end
		assert(math.abs(p.frame:GetWidth() - (class == "DRUID" and claw or dagger)) < 1e-6, class .. " piece " .. i .. " is the size of the combo pieces")
		local point, anchor, rel, x, y = p.frame:GetPoint(1)
		local mirror = select(4, crown.pips[n + 1 - i].frame:GetPoint(1))
		local centred = anchor == R.pips[3] and y == 0
		if class == "DRUID" then centred = point == "BOTTOM" and anchor == R.mana and rel == "TOP" and y > 0 end
		assert(centred and math.abs(x + mirror) < 1e-6, class .. " piece " .. i .. " is centred on the plain pips' places (a bear's standing clear on its druid bar)")
		assert(not p.frame._scripts.OnUpdate, class .. ": no piece runs OnUpdate")
	end
	if n == 5 then
		local _, _, _, x2 = crown.pips[2].frame:GetPoint(1)
		local _, _, _, x1 = crown.pips[1].frame:GetPoint(1)
		local a, b = R.pips[1]:GetPoint(1), R.pips[2]:GetPoint(1)
		assert(a and b and x2 - x1 > 0, class .. ": five pieces keep the pips' order, left to right")
	end
	if class == "DRUID" then
		assert(R.showMana and R.mana:IsShown(), "a bear keeps its druid bar under the talons")
		local place, height = { R.mana:GetPoint(1) }, R.mana.opts.height
		K.Options.Write("UnitFrames", "resource.classPips", false)
		local plain = { R.mana:GetPoint(1) }
		assert(height == R.mana.opts.height and height == ns.Resource.MANA_MAX and plain[4] == place[4] and plain[5] == place[5], "the talons leave the druid bar its full height and place, as without them (" .. height .. " at " .. place[5] .. ")")
		K.Options.Write("UnitFrames", "resource.classPips", true)
	end

	local aura = { id = spec.aura, count = 1, harmful = spec.unit == "target", mine = true }
	Slots.Set(env, spec.unit, { aura })
	assert(Lit(env, crown.pips[1]) and not Lit(env, crown.pips[2]), class .. ": one stack lights one piece")
	assert(not crown.max:IsShown(), class .. ": below the maximum the row does not glow")
	local function Warmth(i)
		local slot = crown.container._slots["heat" .. i]
		local bar = slot and slot.frame._applicationBar[1]
		if not bar then return false end
		local low, high = bar:GetMinMaxValues()
		return bar:IsShown() and (Reveal(env, W.LastCall(bar, "SetValue")[1]) - low) / (high - low) >= 1, bar
	end
	if class == "PALADIN" then
		assert(not crown.container._slots.heat1, "a paladin's Vengeance row has no Rising heat")
	else
		assert(Warmth(1) and not Warmth(2), class .. ": Rising heat lights one step of the row's glow per stack")
	end
	aura.count = n
	Slots.Set(env, spec.unit, { aura })
	if class == "HUNTER" then
		env.FireEvent("UNIT_AURA", "player", {})
		for i, p in ipairs(crown.pips) do
			assert(p.aura.loop:IsPlaying() and p.aura.lit:IsShown(), "at Full under Frames three stacks burn hunter arrow " .. i)
		end
	end
	for i, p in ipairs(crown.pips) do
		assert(Lit(env, p) and env.issecretvalue(W.LastCall(p.blade, "SetValue")[1]), class .. " piece " .. i .. " lights from the game's secret count")
	end
	assert(crown.max:IsShown() and crown.glow:GetParent():IsVisible(), class .. ": the full row glows")
	if class ~= "PALADIN" then
		assert(Warmth(n), class .. ": every Rising heat step is warm at the maximum")
		K.Store.Profile().ActionBars = { crestHeat = false }
		K.Callbacks.Fire("SettingChanged", "ActionBars", "crestHeat", false)
		assert(select(2, Warmth(1)):GetAlpha() == 0, class .. ": the Rising heat switch hides the steps")
		K.Store.Profile().ActionBars = nil
		K.Callbacks.Fire("SettingChanged", "ActionBars", "crestHeat", true)
		assert(select(2, Warmth(1)):GetAlpha() > 0, class .. ": and brings them back")
	end
	assert(tostring(W.LastCall(crown.glow, "SetTexture")[1]):find("Glow", 1, true) and W.LastCall(crown.glow, "SetBlendMode")[1] == "ADD", class .. ": a soft added glow, as under the combo row")
	K.Options.Write("Medallions", "motion", "off")
	aura.count = 2
	Slots.Set(env, spec.unit, { aura })
	assert(W.LastCall(crown.pips[1].blade, "SetValue")[2] == 0, class .. ": Motion Off shows the end state")
	K.Options.Write("Medallions", "motion", "full")
	Slots.Set(env, spec.unit, nil)
	assert(not Lit(env, crown.pips[1]) and crown.pips[1].frame:IsShown(), class .. ": a lost aura leaves the dormant row")

	local target = Listening(env, "PLAYER_TARGET_CHANGED")
	K.Options.Write("UnitFrames", "resource.classPips", false)
	assert(not R.fed and not crown.holder:IsShown() and crown.container._enabled == false, class .. ": Class-themed pips off hides the row and stops the feed")
	assert(spec.unit ~= "target" or Listening(env, "PLAYER_TARGET_CHANGED") == target - 1, class .. ": off stops following the target")
	assert(class == "DRUID" or not K.Layout.Live("unitframes.resource"), class .. ": the empty element has no mover")
	K.Options.Write("UnitFrames", "resource.classPips", true)
	assert(R.fed and crown.holder:IsShown(), class .. ": on again")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(not R.fed and not crown.holder:IsShown(), class .. ": Medallions takes the row away")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(R.fed and crown.holder:IsShown(), class .. ": Frames brings it back")
	Clean(env, K, class)

	local menv, MK, mns = New(class, { style = "medallions" })
	assert(not mns.Resource.state.fed and next(mns.Pips.state.fed) == nil, class .. ": under Medallions the unit frames build nothing")
	Clean(menv, MK, class .. " medallions")
	local nenv, NK, nns = New(class, { known = false })
	assert(not nns.Resource.state.fed and next(nns.Pips.state.fed) == nil, class .. " without the spell has no row")
	Clean(nenv, NK, class .. " unknown")
end

-- Learning the spell brings the row on the spellbook update; secret auras put the build off until combat ends.
do
	local known, lock = false, true
	local env, K, ns = New("PRIEST", { setup = function(e)
		e.C_SpellBook.IsSpellKnown = function(id) return known and id == 15257 end
		e.C_Secrets = e.C_Secrets or {}
		e.C_Secrets.ShouldAurasBeSecret = function() return lock end
	end })
	assert(not ns.Resource.state.fed, "an untalented priest has no row")
	known = true
	env.FireEvent("SPELLS_CHANGED")
	assert(not ns.Resource.state.fed and next(ns.Pips.state.fed) == nil and Listening(env, "PLAYER_REGEN_ENABLED") > 0, "learnt in combat: the build waits for combat to end")
	lock = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(ns.Resource.state.fed and ns.Pips.state.crown.holder:IsShown(), "combat over: the candles show")
	Clean(env, K, "learn")
end

-- Other classes, a paladin with none of Vengeance, Holy Shield or Reckoning, and a caster-form druid, get no row.
for _, class in ipairs({ "WARLOCK" }) do
	local env, K, ns = New(class)
	assert(not ns.Resource.state.fed and next(ns.Pips.state.fed) == nil and not ns.Pips.state.watching, class .. " gets nothing and watches no spellbook")
	Clean(env, K, class)
end
do
	local env, K, ns = New("PALADIN", { known = false })
	assert(not ns.Resource.state.fed and next(ns.Pips.state.fed) == nil, "a paladin without the talents gets no jewels")
	Clean(env, K, "paladin without talents")
end
do
	local env, K, ns = New("DRUID", { setup = function(e) e._units.player.powerType, e._units.player.powerToken = 0, "MANA" end })
	assert(not ns.Resource.state.fed and not ns.Resource.state.content:IsShown(), "a caster-form druid has no row")
	Clean(env, K, "caster druid")
end

-- Rising heat's switch only repaints the steps: no relayout, and a step under an aura button waits until auras are readable and combat has ended.
do
	local env, K, ns = New("WARRIOR", { setup = function(e) e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end } end })
	local bar = ns.Pips.state.heat[1]
	local function Alpha() return Slots.Engine(env, function() return bar:GetAlpha() end) end
	assert(bar and bar.fed and Alpha() > 0, "the warrior's first heat step is lit by default")
	env._aurasSecret = true
	K.Store.Profile().ActionBars = { crestHeat = false }
	K.Callbacks.Fire("SettingChanged", "ActionBars", "crestHeat", false)
	assert(Alpha() > 0, "while auras are secret the step waits")
	env.SetCombat(true)
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(Alpha() > 0, "readable auras in combat still write nothing under an aura button")
	env.SetCombat(false)
	assert(Alpha() == 0, "and the step hides once combat ends")
	K.Store.Profile().ActionBars = nil
	K.Callbacks.Fire("ProfileChanged")
	assert(Alpha() > 0, "a profile change paints it back")
	Clean(env, K, "heat switch")
end

print("unitframes frames crowns ok")
