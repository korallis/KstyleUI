-- test-actionbars-crest-healers.lua: the priest, druid and shaman crest trackers (registered with SlabTrackers.lua: SlabVigil.lua, SlabGrove.lua, SlabStormforged.lua): other classes and characters who know none of the spells build no piece (so no aura container), row or event; a priest gets Inner Fire's four flames (five charges each from the aura's own count, the top right spent first), Penance on the left medal (Mind Blast before it and with Shadowform), Shadowfiend or Shadowform on the right and the Shadow Word: Pain gem; the last flame flickers and the halo dims only at Full, awake, with a readable count; a druid gets a full crest in every form (caster, Cat, Bear, Moonkin), every form's choice built once out of combat so a shift, even in combat, only shows one, a secret form keeping the last; seed medals hold an aura slot per effect, Clearcasting lights the leaves, the gem follows Swiftmend's cooldown or a queued Maul; a shadow priest's right medal is Shadowform and Vampiric Embrace in the form; each class's major cooldowns burn on the rim (a medal of the newest in the Frames row); a shaman's rune stones take the imbue's element colour, the off-hand stone needs an off-hand weapon, a missing imbue pulses the rim and the last five minutes gutter, the emblem sweep is the crest's own shape and the ankh turns gold only with Reincarnation ready and an Ankh; each switch hides its piece and stops its feed; a first build waits out secret auras; under Frames the pieces stand in a row above the stance bar; nothing runs OnUpdate and every part is an even number of pixels on four screens.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local PRIEST = { 10952, 1316995, 10947, 401977, 10894, 10060 }
local DRUID = { 9835, 24977, 25299, 9858, 9904, 9896, 16864, 18562, 9898, 9907, 9881, 17402, 22812 }
local SHAMAN = { 16362, 10414, 20608, 16166 }
local BUILT = { DRUID = 15 }
local KEYS = { "crestInnerFire", "crestPenance", "crestShadowfiend", "crestPain", "crestSeeds", "crestClearcasting", "crestSwiftmend", "crestImbues", "crestShock", "crestAnkh",
	"crestCooldowns" }
-- Each class's pieces by "<row>:<choice>", the key SlabTrackers keeps them under.
local NAMES = {
	PRIEST = { ["1:1"] = "innerFire", ["2:1"] = "penance", ["2:2"] = "mindBlast", ["3:1"] = "embrace", ["3:2"] = "shadowform", ["3:3"] = "shadowfiend",
		["4:1"] = "mending", ["4:2"] = "pain", ["5:1"] = "mend", ["6:1"] = "plague", ["7:1"] = "death", ["8:1"] = "silence", ["9:1"] = "oil",
		["10:1"] = "cooldowns" },
	DRUID = { ["1:1"] = "roar", ["1:2"] = "rake", ["1:3"] = "seedLeft", ["2:1"] = "faerie", ["2:2"] = "rip", ["2:3"] = "seedRight",
		["3:1"] = "third", ["3:2"] = "thirdMoonkin", ["3:3"] = "faerieGem", ["4:1"] = "growl", ["5:1"] = "charge", ["6:1"] = "bite", ["7:1"] = "bash",
		["8:1"] = "oil", ["9:1"] = "bloom", ["10:1"] = "maul", ["10:2"] = "swiftnessMoonkin", ["10:3"] = "innervateMoonkin",
		["10:4"] = "swiftmend", ["10:5"] = "swiftness", ["10:6"] = "innervate", ["11:1"] = "tankGlow", ["12:1"] = "cooldowns" },
	SHAMAN = { ["1:1"] = "mainHand", ["2:1"] = "offHand", ["3:1"] = "shock", ["4:1"] = "ankh", ["5:1"] = "flameShock", ["6:1"] = "cooldowns" },
}

local function New(class, spells, opts)
	opts = opts or {}
	local known = {}
	for _, id in ipairs(spells or {}) do known[id] = true end
	local env, K, ns = AB.New({
		class = class,
		width = opts.size and opts.size[1],
		height = opts.size and opts.size[2],
		setup = function(e)
			e._known, e._cooling, e._enchants, e._offHand, e._ankhs = known, {}, {}, true, 1
			e.GetTime = e.GetTime or function() return 100 end
			e.GetShapeshiftFormID = function() return e._form end
			for i, form in ipairs(opts.forms or {}) do
				e._game.forms[i] = { texture = form, isActive = false, spellID = 7000 + i }
			end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.GetSpellTexture = function(id) return id end
			e.C_Spell.GetSpellCooldown = function(id) return { isActive = e._cooling[id] == true, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function(id) return e._cooling[id] and { start = 0, finish = 12 } or { start = 0, finish = 0 } end
			e.C_UnitAuras = e.C_UnitAuras or {}
			e.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
				if e._aurasSecret then return nil end
				for _, a in ipairs(e._slotAuras.player or {}) do
					if a.id == id then return { spellId = id, applications = a.count } end
				end
			end
			e.C_PaperDollInfo = {
				OffhandHasWeapon = function() return e._offHand end,
				GetTemporaryEnchantmentInfo = function(slot) return e._enchants[slot] end,
			}
			e._oils = 0
			e.C_Item = { GetItemCount = function(id) return id == 17030 and e._ankhs or id >= 20744 and id <= 20750 and e._oils or 0 end, GetItemIconByID = function(id) return id end }
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

local function Tracker(ns, class)
	local state = ns.SlabTrackers.state
	return setmetatable({}, { __index = function(_, k)
		if k == "built" then
			local built = {}
			for form, f in pairs(state.forms) do
				for key, piece in pairs(f.pieces) do
					local row, choice = key:match("^(%d+):(%d+)$")
					local name = row == "1" and "fiveSecond" or NAMES[class][(row - 1) .. ":" .. choice]
					built[name .. (form == "row" and "Row" or "")] = piece
				end
			end
			return built
		elseif k == "listening" then
			return state.listening ~= nil and state.listening:sub(1, 4) == "true"
		elseif k == "row" then
			return state.forms.row and state.forms.row.frame
		end
	end })
end

local function Count(t)
	local n = 0
	for _ in pairs(t.built) do n = n + 1 end
	return n
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do
		n = n + Updating(child)
	end
	return n
end

local function Fill(env, bar)
	local low, high = bar:GetMinMaxValues()
	local v = bar:GetValue()
	v = env.issecretvalue(v) and env.Reveal(v) or v
	return (math.max(low, math.min(high, v)) - low) / (high - low)
end

-- Other classes, and healers who know none of the spells, build nothing and listen to nothing.
for _, case in ipairs({ { "WARRIOR", PRIEST }, { "MAGE", DRUID }, { "HUNTER", SHAMAN }, { "PRIEST", {} }, { "DRUID", {} }, { "SHAMAN", {} } }) do
	local env, K, ns = New(case[1], case[2])
	local built = Tracker(ns, "PRIEST").built
	built.fiveSecond = nil
	assert(next(built) == nil and Tracker(ns, "PRIEST").row == nil, case[1] .. ": no tracker piece or row beyond the shared five-second rule")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The priest: four pieces, the flames fed from the aura's own count, the flourishes only when Lua can read it.
do
	local env, K, ns = New("PRIEST", PRIEST)
	local t = Tracker(ns, "PRIEST")
	local fire, left, right, pain = t.built.innerFire, t.built.penance, t.built.shadowfiend, t.built.pain
	local rim = t.built.cooldowns
	assert(Count(t) == 7 and fire:IsShown() and left:IsShown() and right:IsShown() and pain:IsShown() and rim:IsShown() and t.listening, "a priest who knows them gets five pieces and the five-second rule, Mind Blast prepared")
	assert(not t.built.mindBlast:IsShown(), "Penance wins the left medal; Mind Blast waits")
	assert(rim.lit.container._slots.lit.candidates.includeSpellIDs[10060] and rim.lit.container._slots.lit.candidates.includeSpellIDs[1277462], "the cooldown rim watches Power Infusion to the race spells")
	Slots.Set(env, "player", { { id = 10060, count = 0, icon = 135939, start = 0, duration = 15 } })
	assert(rim.lit:IsShown() and AB.W.LastCall(rim.timer, "SetCooldownFromDurationObject"), "Power Infusion burns on the rim")
	Slots.Set(env, "player", nil)
	assert(left.spec.spell == 1316995 and right.spec.spell == 401977, "Penance on the left, Shadowfiend on the right")
	assert(pain.lit.container._unit == "target" and pain.lit.container._slots.lit.filter == "HARMFUL|PLAYER", "the gem watches your Pain on the target")
	for k, seat in ipairs(fire.ring) do
		local o = fire.lits[k + 1]._applicationBar[2]
		assert(o.minApplications == (k - 1) * 5 and o.maxApplications == k * 5, "flame " .. k .. " holds charges " .. (k - 1) * 5 .. " to " .. k * 5)
		assert(seat.angle == ({ 315, 225, 135, 45 })[k], "flame " .. k .. " sits at its corner")
	end
	Slots.Set(env, "player", { { id = 10952, count = 20, start = 0, duration = 600 } })
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 10952)
	assert(Fill(env, fire.ring[4].bar or fire.lits[5]._applicationBar[1]) == 1, "twenty charges light the top right flame")
	assert(fire.flare.play:IsPlaying(), "a cast flares the halo")
	local aura = env._slotAuras.player[1]
	aura.count = 12
	Slots.Set(env, "player", env._slotAuras.player)
	env.FireEvent("UNIT_AURA", "player", {})
	local bars = {}
	for k = 1, 4 do bars[k] = fire.lits[k + 1]._applicationBar[1] end
	assert(Fill(env, bars[1]) == 1 and Fill(env, bars[2]) == 1 and Fill(env, bars[3]) == 0.4 and Fill(env, bars[4]) == 0, "twelve charges: two flames, a third burning down, the top right out")
	assert(not fire.flicker:IsPlaying(), "more than five charges do not flicker")
	aura.count = 4
	Slots.Set(env, "player", env._slotAuras.player)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(not fire.flicker:IsPlaying() and fire.still:GetAlpha() == 0.5, "at rest the last flame holds still under a dimmed halo")
	env.SetCombat(true)
	assert(fire.flicker:IsPlaying() and fire.fire:GetAlpha() == 0.5, "awake, the last flame flickers and the halo dims")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not fire.flicker:IsPlaying() and fire.still:GetAlpha() == 0.5, "Calm holds the last flame still, dimmed")
	K.Options.Write("Medallions", "motion", "full")
	assert(fire.flicker:IsPlaying(), "Full flickers again")
	env.SetCombat(false)
	assert(not fire.flicker:IsPlaying(), "the crest at rest calms it")
	env._aurasSecret = true
	aura.count = 9
	Slots.Set(env, "player", env._slotAuras.player)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(Fill(env, bars[2]) == 0.8, "a secret count still feeds the flames through the engine")
	env._aurasSecret = false
	env._cooling[1316995] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(left.timer, "SetCooldownFromDurationObject"), "Penance sweeps its medal from the cooldown's duration object")
	assert(left.timer:GetScript("OnCooldownDone"), "and flares when it is ready")
	Slots.Set(env, "target", { { id = 10894, harmful = true, count = 0, start = 0, duration = 18 } })
	assert(pain.lit:IsShown() and AB.W.LastCall(pain.bar, "SetTimerDuration"), "your Pain on the target fills the gem and drains it")

	-- Each switch hides its own piece and stops its feed; turning it back shows it again.
	for _, key in ipairs({ "crestInnerFire", "crestPenance", "crestShadowfiend", "crestPain", "crestCooldowns", "crestFiveSecond" }) do
		K.Options.Write("ActionBars", key, false)
		env.RunTimers()
	end
	assert(not fire:IsVisible() and not left:IsVisible() and not right:IsVisible() and not pain:IsVisible() and not rim:IsVisible() and not t.listening, "every switch off hides every piece and stops listening")
	assert(fire.lit.fed == false and pain.lit.fed == false, "and the feeds stop")
	K.Options.Write("ActionBars", "crestPain", true)
	env.RunTimers()
	assert(pain:IsVisible() and pain.lit.fed and not fire:IsVisible(), "one switch back on shows only its piece")
	assert(Updating(env.UIParent) == 0, "no tracker frame runs OnUpdate")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Low levels see only what they have; a shadow priest's right medal is Shadowform, and Vampiric Embrace in the form.
do
	local env, K, ns = New("PRIEST", { 589, 8092 })
	local t = Tracker(ns, "PRIEST")
	assert(Count(t) == 3 and t.built.pain and t.built.mindBlast and t.built.fiveSecond and t.built.mindBlast.spec.spell == 8092, "a level 10 priest sees the Pain gem and the Mind Blast medal only")
	env._known[15473], env._known[1316995], env._known[15286], env._known[401977] = true, true, true, true
	ns.SlabTrackers.Update()
	assert(t.built.mindBlast:IsShown() and not t.built.penance and t.built.shadowform:IsShown() and not t.built.shadowfiend:IsShown(), "a shadow priest: Mind Blast left, Shadowform right")
	assert(t.built.shadowform.lit.container._slots.lit.candidates.includeSpellIDs[15473], "the form lights from its own aura")
	assert(t.built.embrace and not t.built.embrace:IsShown(), "Vampiric Embrace is built and waits for the form")
	env.SetCombat(true)
	env._aurasSecret, env._form = true, 28
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(t.built.embrace:IsShown() and not t.built.shadowform:IsShown(), "in Shadowform, even in combat, the right medal is your Vampiric Embrace on the target")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The druid: a full crest in every form, every choice built once, a shift only showing one.
do
	local env, K, ns = New("DRUID", DRUID)
	local b = Tracker(ns, "DRUID").built
	local function Shown(...)
		for _, name in ipairs({ ... }) do
			if not b[name]:IsShown() then return false end
		end
		return true
	end
	assert(Count(Tracker(ns, "DRUID")) == BUILT.DRUID, "every form's choice is built: " .. Count(Tracker(ns, "DRUID")))
	assert(Shown("seedLeft", "seedRight", "bloom", "swiftmend") and not b.rake:IsShown() and not b.roar:IsShown() and not b.maul:IsShown(), "as a caster: the seed medals, the bloom and the Swiftmend gem")
	assert(#b.seedLeft.lits == 2 and b.seedLeft.lits[2].container._slots.lit.filter == "HELPFUL|PLAYER" and b.seedLeft.lits[1].container._slots.lit.filter == "HARMFUL|PLAYER", "a seed medal holds your harmful and helpful effect")
	Slots.Set(env, "target", { { id = 25299, count = 0, start = 0, duration = 12, icon = 136081 } })
	assert(b.seedLeft.lits[2]:IsShown() and not b.seedLeft.lits[1]:IsShown(), "Rejuvenation on a friend lights the helpful slot")
	assert(AB.W.LastCall(b.seedLeft.lits[2].timer, "SetCooldownFromDurationObject"), "and drains its ring")
	Slots.Set(env, "player", { { id = 16870, count = 1, start = 0, duration = 15 } })
	assert(b.bloom.lit:IsShown() and #b.bloom.ring == 8, "Clearcasting blooms the leaves")
	env._cooling[18562] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(b.swiftmend.bar, "SetTimerDuration"), "the gem refills over Swiftmend's cooldown")
	env.SetCombat(true)
	env._aurasSecret, env._form = true, 1
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown("rake", "rip", "faerieGem", "bloom") and not b.seedLeft:IsShown() and not b.swiftmend:IsShown(), "Cat Form, in combat: Rake, Rip and your Faerie Fire on the target")
	for name, piece in pairs(b) do
		assert(not (piece:IsShown() and piece.spec.seat == "topGem"), name .. " covers the combo crown's middle jewel in Cat Form")
	end
	env._form = 8
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown("roar", "faerie", "maul") and not b.rake:IsShown(), "Bear Form: Demoralizing Roar, Faerie Fire and Maul")
	assert(not b.maul.lit:IsShown(), "Maul waits dark until it is queued")
	env.C_Spell.IsCurrentSpell = function(id) return id == 9881 end
	env.FireEvent("CURRENT_SPELL_CAST_CHANGED")
	assert(b.maul.lit:IsShown(), "a queued Maul lights the gem")
	env._form = 31
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(Shown("seedLeft", "seedRight", "thirdMoonkin") and not b.maul:IsShown() and not b.third:IsShown() and not b.swiftmend:IsShown(), "Moonkin: the seed medals and your Faerie Fire on top, no caster Swiftmend gem")
	env._form = env.Secret(8)
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(b.thirdMoonkin:IsShown(), "a secret form keeps the last crest")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Each seat follows the spec and form it is in: a shadow priest before Shadowform casts Mind Blast, not Penance; in
-- Shadowform without Vampiric Embrace the right medal is Shadowfiend, not Shadowform again; a druid in Cat or Bear
-- Form without that form's own effects shows no caster seed.
do
	local env, K, ns = New("PRIEST", { 10952, 10947, 1316995, 15334 })
	local b = Tracker(ns, "PRIEST").built
	assert(b.mindBlast:IsShown() and not b.penance:IsShown(), "Shadow Weaving without Shadowform: Mind Blast, not Penance")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
do
	local env, K, ns = New("PRIEST", { 15473, 15334, 401977, 10947 })
	env._form = 28
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local b = Tracker(ns, "PRIEST").built
	assert(b.shadowfiend:IsShown() and not b.shadowform:IsShown(), "in Shadowform without Vampiric Embrace: Shadowfiend, not Shadowform again")
	env._form = nil
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(b.shadowform:IsShown() and not b.shadowfiend:IsShown(), "out of the form a shadow priest sees Shadowform waiting")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
do
	local env, K, ns = New("DRUID", { 8921, 774, 8936, 5570 })
	local b = Tracker(ns, "DRUID").built
	for _, form in ipairs({ 1, 8 }) do
		env._form = form
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		assert(not b.seedLeft:IsShown() and not b.seedRight:IsShown(), "form " .. form .. " without its own effects shows no caster seed")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The shaman: element colours, the off hand, the gilt pulse, the gutter, the emblem sweep and the ankh.
do
	local env, K, ns = New("SHAMAN", SHAMAN)
	local t, Tokens = Tracker(ns, "SHAMAN"), K.Tokens
	assert(t.built.shock and t.built.ankh, "the emblem sweeps the shock cooldown, the interrupt, and the ankh stands on the right foot")
	assert(t.built.ankh.spec.seat == "footRight", "the ankh sits on the right foot perch")
	local main, off, shock, ankh = t.built.mainHand, t.built.offHand, t.built.shock, t.built.ankh
	assert(main:IsShown() and off:IsShown() and shock:IsShown() and ankh:IsShown(), "a shaman gets two stones, the sweep and the ankh")
	assert(main.rim:IsShown() and not main.pulse:IsPlaying(), "no imbue: the stone's gilt rim shows, still at rest")
	env.SetCombat(true)
	assert(main.pulse:IsPlaying(), "and pulses once the crest wakes")
	env._enchants[16] = { enchantID = 1669, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	env._enchants[17] = { enchantID = 1666, remainingTimeMs = 200000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 1, { start = 0, duration = 3600 })
	Slots.Enchant(env, 2, { start = 0, duration = 3600 })
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	local r, g, b = Tokens.Color("totemAir")
	local vr, vg, vb = main.rune:GetVertexColor()
	assert(math.abs(vr - r) + math.abs(vg - g) + math.abs(vb - b) < 1e-6, "Windfury lights the rune in air's colour")
	assert(main.lit:IsShown() and not main.rim:IsShown() and not main.pulse:IsPlaying(), "an imbue lights the stone and stops the pulse")
	assert(off.gutter:IsPlaying() and not main.gutter:IsPlaying(), "the last five minutes gutter")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not off.gutter:IsPlaying(), "Calm does not gutter")
	K.Options.Write("Medallions", "motion", "full")
	env._offHand = false
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED")
	assert(not off:IsShown() and main:IsShown(), "no off-hand weapon, no off-hand stone")
	assert(shock.timer._state.SwipeTexture[1] == ns.Slab.hub.crestPath, "the sweep takes the crest's own shape")
	env._cooling[10414] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(shock.timer, "SetCooldownFromDurationObject"), "a shock sweeps the emblem")
	assert(ankh.glyph:GetAlpha() == 1, "Reincarnation ready with an Ankh: the ankh is gold")
	env._ankhs = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(ankh.glyph:GetAlpha() < 1, "no Ankh in the bags: the ankh greys")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Imbues are imbues: another temporary enchant is no imbue, and under Frames each weapon's medal keeps its
-- element's icon and colour, the enchant's own timer and the last five minutes' gutter. Oil is oil.
do
	local env, K, ns = New("SHAMAN", SHAMAN)
	local t, Tokens = Tracker(ns, "SHAMAN"), K.Tokens
	local main = t.built.mainHand
	env.SetCombat(true)
	env._enchants[16] = { enchantID = 9999, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 1, { start = 0, duration = 3600 })
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(main.light:GetAlpha() == 0 and main.rim:IsShown() and main.pulse:IsPlaying(), "an enchant that is no imbue leaves the stone dark under the pulsing rim")
	env._enchants[16] = { enchantID = 1669, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	env._enchants[17] = { enchantID = 1666, remainingTimeMs = 200000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 2, { start = 0, duration = 3600 })
	env.SetCombat(false)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	env.SetCombat(true)
	local mainRow, offRow = t.built.mainHandRow, t.built.offHandRow
	assert(mainRow.lit.icon:GetTexture() == 8232 and offRow.lit.icon:GetTexture() == 8024, "Windfury and Flametongue each show their own icon")
	assert(mainRow.lit.timer and offRow.lit.timer and mainRow.lit._cooldown == mainRow.lit.timer, "each weapon's medal drains with the enchant's own timer")
	local sr, sg, sb = unpack(AB.W.LastCall(offRow.lit.timer, "SetSwipeColor") or {})
	local r, g, b = Tokens.Color("totemFire")
	assert(math.abs(sr - r) + math.abs(sg - g) + math.abs(sb - b) < 1e-6, "in its element's colour")
	assert(offRow.gutter:IsPlaying() and not mainRow.gutter:IsPlaying(), "the off hand's last five minutes gutter in the row too")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
-- A stone keeps one wake-up for its last five minutes however often the enchant is re-read, and a stone that is
-- switched off reads nothing and keeps none.
do
	local env, K = New("SHAMAN", SHAMAN)
	env.SetCombat(true)
	local now, pending, reads = 100, {}, 0
	env.GetTime = function() return now end
	local after, ticker = env.C_Timer.After, env.C_Timer.NewTicker
	env.C_Timer.After = function(delay, fn)
		if delay > 10 then pending[#pending + 1] = { cancelled = false } end
		return after(delay, fn)
	end
	env.C_Timer.NewTicker = function(delay, fn, n)
		local made = ticker(delay, fn, n)
		if delay > 10 then pending[#pending + 1] = made end
		return made
	end
	local function Live()
		local n = 0
		for _, p in ipairs(pending) do n = n + (p.cancelled and 0 or 1) end
		return n
	end
	for i = 1, 25 do
		now = 100 + i * 0.01731
		env._enchants[16] = { enchantID = 1669, remainingTimeMs = math.floor((1800 - now) * 1000), hasExpirationTime = true }
		env.FireEvent("WEAPON_ENCHANT_CHANGED")
	end
	assert(Live() == 1, "25 re-reads of one enchant leave one wake-up, not " .. Live())
	K.Options.Write("ActionBars", "crestImbues", false)
	local get = env.C_PaperDollInfo.GetTemporaryEnchantmentInfo
	env.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function(...)
		reads = reads + 1
		return get(...)
	end
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(reads == 0 and Live() == 0, "switched off, the stones read no enchant and keep no wake-up: " .. reads .. " reads, " .. Live() .. " wake-ups")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
do
	local env, K, ns = New("PRIEST", PRIEST)
	env._enchants[16] = { enchantID = 1669, remainingTimeMs = 600000 }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	local oil = Tracker(ns, "PRIEST").built.oil
	assert(not (oil and oil:IsVisible()), "Windfury on a priest's weapon with no oil in the bags is no oil socket")
	env._enchants[16] = { enchantID = 2628, remainingTimeMs = 600000 }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	oil = Tracker(ns, "PRIEST").built.oil
	assert(oil and oil:IsVisible(), "Brilliant Wizard Oil on the weapon is")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A healer priest's top medal holds your shield, Renew and Mending; Mending takes the gem; a shadow priest gets the
-- plague, Shadow Word: Death and Silence instead; an oil in the bags brings the oil socket.
do
	local env, K, ns = New("PRIEST", { 10901, 25315, 1240827, 10894, 10947 })
	local b = Tracker(ns, "PRIEST").built
	assert(b.mend:IsShown() and #b.mend.lits == 3 and b.mend.lits[1].container._slots.lit.filter == "HELPFUL|PLAYER", "a healer's top medal: shield, Renew and Mending on the target")
	assert(b.mending:IsShown() and not b.pain:IsShown(), "from level 40 Prayer of Mending takes the gem")
	assert(not b.plague and not b.death and not b.oil, "no shadow piece and no oil socket without one")
	env._known[15473], env._known[19280], env._known[1309636], env._known[15487] = true, true, true, true
	env._oils = 1
	ns.SlabTrackers.Update()
	b = Tracker(ns, "PRIEST").built
	assert(b.plague:IsShown() and b.death:IsShown() and b.silence:IsShown() and not b.mend:IsVisible() and b.pain:IsShown(), "a shadow priest: Devouring Plague, Shadow Word: Death and Silence, Pain on the gem, no top medal")
	assert(b.oil:IsShown() and b.oil.lit.container, "an oil in the bags brings the main-hand socket")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A bear's tank kit: Growl and Feral Charge on the feet, Primal Bite and Bash in the sockets, hidden in other forms.
do
	local env, K, ns = New("DRUID", { 9835, 9898, 6795, 1238122, 1238070, 8983 })
	env._oils = 1
	ns.SlabTrackers.Update()
	local b = Tracker(ns, "DRUID").built
	assert(b.oil:IsShown() and not b.growl:IsShown() and not b.bash:IsShown(), "as a caster: the oil socket, no tank kit")
	env._form = 8
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(b.growl:IsShown() and b.charge:IsShown() and b.bite:IsShown() and b.bash:IsShown() and not b.oil:IsShown(), "Bear Form: Growl, Feral Charge, Primal Bite and Bash")
	assert(b.growl.spec.size == ns.SlabMedals.FOOT and b.growl.spec.feed == "cooldown", "the feet hold small cooldown medals")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A first build waits out secret auras, then builds when combat ends.
do
	local env, K, ns = New("DRUID", {})
	local t = Tracker(ns, "DRUID")
	env._aurasSecret = true
	env.SetCombat(true)
	for _, id in ipairs(DRUID) do env._known[id] = true end
	ns.SlabTrackers.Update()
	assert(Count(t) == 1 and t.built.fiveSecond and t.listening, "nothing new is built while auras are secret (the plaque came at login), and the tracker waits")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(Count(t) == BUILT.DRUID, "combat's end builds the pieces")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Frames: the pieces stand in a row above the stance bar's forms, and the crest's pieces hide.
do
	local env, K, ns = New("DRUID", DRUID, { forms = { 132276, 132115 } })
	local t = Tracker(ns, "DRUID")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(t.row and t.row:IsShown() and not t.built.seedLeft:IsVisible(), "under Frames the crest pieces hide and the row shows")
	assert(t.built.seedLeftRow:IsShown() and t.built.bloomRow:IsShown() and t.built.bloomRow.timer, "the row's Clearcasting is a medal with its ring")
	assert(t.built.cooldownsRow:IsShown() and t.built.cooldownsRow.spec.newest, "the row's cooldowns are a medal showing the newest")
	local point, anchor, rel = t.row:GetPoint(1)
	assert(point == "BOTTOMLEFT" and rel == "TOPLEFT" and anchor == ns.bars.stance.buttons[1], "the row stands above the forms")
	local cells, count = {}, 0
	for name, piece in pairs(t.built) do
		if name:find("Row$") and piece:IsShown() then
			local _, _, _, x, y = piece:GetPoint(1)
			cells[x .. "," .. y], count = name, count + 1
		end
	end
	for n = 0, count - 1 do
		local x, y = ns.SlabMedals.Cell(n)
		assert(cells[K.Widgets.Snap(t.row, x) .. "," .. K.Widgets.Snap(t.row, y)], "row cell " .. n .. " is empty or shared: a custom place() must take cell n and return n + 1")
	end
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(not t.row:IsShown() and t.built.seedLeft:IsShown(), "back under Medallions the crest pieces return")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Frames: Inner Fire's medal keeps the quantity the flames show, its charges.
do
	local env, K, ns = New("PRIEST", PRIEST)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local row = Tracker(ns, "PRIEST").built.innerFireRow
	Slots.Set(env, "player", { { id = 10952, count = 4, start = 0, duration = 600 } })
	assert(row.lit.count and row.lit._countText == row.lit.count and row.lit.count:GetText() == "4", "the row's Inner Fire shows its charges, 4")
	Slots.Set(env, "player", { { id = 10952, count = 20, start = 0, duration = 600 } })
	assert(row.lit.count:GetText() == "20", "and 20 after a fresh cast")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Every part is an even number of pixels on four screens, and every switch is on by default.
for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = New("PRIEST", PRIEST, { size = size })
	local k = size[2] / 768
	local function Even(region)
		local s, right = region:GetEffectiveScale() * k, region:GetRight()
		if env.issecretvalue(right) or env.issecretvalue(s) then
			return nil
		end
		for _, v in ipairs({ (right - region:GetLeft()) * s, (region:GetTop() - region:GetBottom()) * s }) do
			local n = math.floor(v + 0.5)
			if math.abs(v - n) > 1e-3 or n % 2 ~= 0 then return false end
		end
		return true
	end
	local checked = 0
	for name, piece in pairs(Tracker(ns, "PRIEST").built) do
		for n, part in ipairs(piece:IsShown() and piece.parts or {}) do
			local even = Even(part)
			assert(even ~= false, at .. name .. " part " .. n .. " is an even number of pixels")
			checked = checked + (even and 1 or 0)
		end
	end
	assert(checked > 20, at .. "the parts outside the engine's buttons are measured: " .. checked)
	for _, key in ipairs(KEYS) do
		assert(K.Store.Module("ActionBars")[key] == true, key .. " is on by default")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars crest healers ok")
