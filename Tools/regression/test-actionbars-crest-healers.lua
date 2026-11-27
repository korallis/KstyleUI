-- test-actionbars-crest-healers.lua: the priest, druid and shaman crest trackers (registered with SlabTrackers.lua: SlabVigil.lua, SlabGrove.lua, SlabStormforged.lua): other classes and characters who know none of the spells build no piece (so no aura container), row or event; a priest gets Inner Fire's four flames (five charges each from the aura's own count, the top right spent first), Penance on the left medal (Mind Blast before it and with Shadowform), Shadowfiend or Shadowform on the right and the Shadow Word: Pain gem; the last flame flickers and the halo dims only at Full, awake, with a readable count; a druid gets a full crest in every form (caster, Cat, Bear, Moonkin), every form's choice built once out of combat so a shift, even in combat, only shows one, a secret form keeping the last; seed medals hold an aura slot per effect, Clearcasting lights the leaves, the gem follows Swiftmend's cooldown or a queued Maul; a shadow priest's right medal is Shadowform and Vampiric Embrace in the form; each class's major cooldowns burn on the rim, each lighting its family's sigil (the same sigils in the Frames row); a shaman's rune stones take the imbue's element colour, the off-hand stone needs an off-hand weapon, a missing imbue pulses the rim and the last five minutes gutter, the emblem sweep is the crest's own shape and the ankh turns gold only with Reincarnation ready and an Ankh; each switch hides its piece and stops its feed; a first build waits out secret auras; under Frames the pieces stand in a row above the stance bar; nothing runs OnUpdate and every part is an even number of pixels on four screens.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local PRIEST = { 10952, 1316995, 10947, 401977, 10894, 10060 }
local DRUID = { 9835, 24977, 25299, 9858, 9904, 9896, 16864, 18562, 9898, 9907, 9881, 17402, 22812 }
local SHAMAN = { 16362, 10414, 20608, 16166 }
local BUILT = { DRUID = 16 }
local KEYS = { "crestInnerFire", "crestPenance", "crestShadowfiend", "crestPain", "crestSeeds", "crestLeaves", "crestSwiftmend", "crestImbues", "crestShock", "crestAnkh",
	"crestCooldowns" }
-- Each class's pieces by "<row>:<choice>", the key SlabTrackers keeps them under.
local NAMES = {
	PRIEST = { ["1:1"] = "innerFire", ["2:1"] = "penance", ["2:2"] = "mindBlast", ["3:1"] = "embrace", ["3:2"] = "shadowform", ["3:3"] = "shadowfiend",
		["4:1"] = "flood", ["5:1"] = "mending", ["5:2"] = "pain", ["6:1"] = "mend", ["7:1"] = "renew", ["8:1"] = "mended", ["9:1"] = "plague",
		["10:1"] = "death", ["11:1"] = "silence", ["12:1"] = "oil", ["13:1"] = "cooldowns" },
	DRUID = { ["1:1"] = "roar", ["1:2"] = "rake", ["1:3"] = "seedLeft", ["2:1"] = "faerie", ["2:2"] = "rip", ["2:3"] = "seedRight",
		["3:1"] = "third", ["3:2"] = "thirdMoonkin", ["3:3"] = "faerieGem", ["4:1"] = "growl", ["5:1"] = "charge", ["6:1"] = "bite", ["7:1"] = "bash",
		["8:1"] = "oil", ["9:1"] = "bloom", ["10:1"] = "maul", ["10:2"] = "swiftnessMoonkin", ["10:3"] = "innervateMoonkin",
		["10:4"] = "swiftmend", ["10:5"] = "swiftness", ["10:6"] = "innervate", ["11:1"] = "tankGlow", ["12:1"] = "cooldownsBear",
		["12:2"] = "cooldownsCat", ["12:3"] = "cooldowns" },
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
			e._known, e._cooling, e._enchants, e._offHand, e._ankhs = known, {}, {}, opts.offHand ~= false, 1
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
					if piece.spec.key ~= "crestSwing" then built[name .. (form == "row" and "Row" or "")] = piece end
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
	return Slots.Engine(env, function()
		local low, high = bar:GetMinMaxValues()
		local v = bar:GetValue()
		v = env.issecretvalue(v) and env.Reveal(v) or v
		return (math.max(low, math.min(high, v)) - low) / (high - low)
	end)
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
	env.SetCombat(true)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 10952)
	assert(Fill(env, fire.ring[4].bar or fire.lits[5]._applicationBar[1]) == 1, "twenty charges light the top right flame")
	assert(fire.flare.play:IsPlaying() and fire.lit.flareGate:GetAlpha() == 1, "awake, a cast flares the halo")
	env.SetCombat(false)
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
	assert(AB.W.LastCall(b.seedLeft.lits[2].bar, "SetTimerDuration"), "and its bud drains over the aura's time")
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

-- Each switch's name and help name what it toggles.
do
	local env, K = New("PRIEST", PRIEST)
	local function Says(key, ...)
		local row = K.Options.Row("ActionBars", key)
		local text = row.label .. " " .. row.help
		for _, words in ipairs({ ... }) do
			if not text:find(words, 1, true) then return false end
		end
		return true
	end
	assert(Says("crestPain", "Shadow Word: Pain", "Prayer of Mending"), "the Pain switch names the healer's Prayer of Mending too")
	assert(Says("crestSwiftmend", "Swiftmend", "Nature's Swiftness", "Innervate", "Maul"), "the gem switch names Maul in Bear Form")
	assert(Says("crestShadowfiend", "Shadowfiend", "Shadowform", "Vampiric Embrace"), "the right-medal switch names Vampiric Embrace")
	assert(Says("crestThird", "Faerie Fire", "Wild Growth", "Cat Form"), "the Faerie Fire switch names its Cat Form socket")
	assert(Says("crestAnkh", "Reincarnation", "Ankh") and not Says("crestAnkh", "gold"), "the ankh switch describes the cooldown medal")
	assert(Says("crestPenance", "left shoulder") and Says("crestThird", "above the crest") and Says("crestMend", "dome", "feet"), "the switches say where each figure stands")
	for _, key in ipairs({ "crestPenance", "crestSeeds", "crestThird", "crestMend" }) do
		assert(not Says(key, "medal") and not Says(key, "shield, Renew and Prayer of Mending on your target above"), key .. "'s help still describes a removed medal")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The priest's rim knows every rank of the race spells it lists: Dark Sacrifice's five and Contingency Plan's five.
for _, rank in ipairs({ 1277328, 1277640 }) do
	local env, K, ns = New("PRIEST", { rank, 10947 })
	local rim = Tracker(ns, "PRIEST").built.cooldowns
	assert(rim and rim.lit.container._slots.lit.candidates.includeSpellIDs[rank], "a priest knowing only rank " .. rank .. " gets the rim watching it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Clearcasting's leaves unfurl when it lights: a group the engine plays as the aura shows, seen at Full only. The leaves exist twice, each in a slot under a layer
-- of the addon's own: one copy unfurls and one stands still, so a motion level takes effect by lighting one layer, in combat too. (Forever has no hidden-aura
-- animation, so the leaves cannot scatter as it is spent.)
do
	local env, K, ns = New("DRUID", DRUID)
	local bloom = Tracker(ns, "DRUID").built.bloom
	local moving, calm = bloom.moving.lit, bloom.calm.lit
	local function Registered(slot)
		for _, group in ipairs(slot._shownAnimations or {}) do
			if group == bloom.unfurl then return true end
		end
		return false
	end
	assert(bloom.unfurl and Registered(moving) and not Registered(calm), "the engine unfurls one copy of the leaves as Clearcasting shows, and never the other")
	assert(moving.container ~= calm.container and moving.container ~= bloom.lit.container, "each copy has an aura feed of its own")
	assert(bloom.moving:GetAlpha() == 1 and bloom.calm:GetAlpha() == 0, "at Full the unfurling copy shows")
	-- Both copies stand on the same ring: a still leaf with no anchor would draw nothing at Calm and Off.
	Slots.Set(env, "player", { { id = 16870, count = 1, start = 0, duration = 15 } })
	local placed = {}
	for k, leaf in ipairs(bloom.ring) do
		local a, b = { leaf:GetPoint(1) }, { assert(leaf.twin, "leaf " .. k .. " has a still copy"):GetPoint(1) }
		assert(a[1] == "CENTER" and b[1] == "CENTER" and a[2] == b[2] and a[4] == b[4] and a[5] == b[5], "still leaf " .. k .. " stands where its unfurling copy stands")
		assert(leaf.twin:GetParent() == calm and leaf:GetParent() ~= calm, "leaf " .. k .. ": one copy in each slot")
		placed[a[4] .. ":" .. a[5]] = true
	end
	local seats = 0
	for _ in pairs(placed) do seats = seats + 1 end
	assert(#bloom.ring == 8 and seats == 8, "eight leaves at eight places round the ring, not " .. seats)
	Slots.Set(env, "player", nil)
	K.Options.Write("Medallions", "motion", "calm")
	assert(bloom.moving:GetAlpha() == 0 and bloom.calm:GetAlpha() == 1, "Calm shows the still copy")
	K.Options.Write("Medallions", "motion", "full")
	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("Medallions", "motion", "off")
	assert(Registered(moving) and bloom.moving:GetAlpha() == 0 and bloom.calm:GetAlpha() == 1, "a level chosen under hidden values shows at once: the copy the engine still unfurls is dark")
	-- An unfurl that began unseen is not shown half grown: Full inside its time keeps the still leaves, and the moving copy takes over when it has ended.
	env.GetTime = function() return env._now end
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	Slots.Set(env, "player", { { id = 16870, count = 1, start = 0, duration = 15 } })
	env._engine = true
	assert(bloom.unfurl:IsPlaying(), "the engine unfurls the dark copy as Clearcasting shows")
	env._engine = nil
	K.Options.Write("Medallions", "motion", "full")
	assert(bloom.moving:GetAlpha() == 0 and bloom.calm:GetAlpha() == 1, "Off to Full inside the unfurl: the still leaves stay and the half-grown copy stays dark")
	env._now = env._now + 1
	for _, fn in ipairs(armed) do fn() end
	assert(bloom.moving:GetAlpha() == 1 and bloom.calm:GetAlpha() == 0, "and the moving copy takes over once the unfurl is over")
	K.Options.Write("Medallions", "motion", "off")
	K.Options.Write("Medallions", "motion", "full")
	assert(bloom.moving:GetAlpha() == 1 and bloom.calm:GetAlpha() == 0, "an unfurl whose time is over delays nothing")
	env.C_Timer.After = after
	env._aurasSecret = false
	env.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The druid's plaque and rim follow the form: the five-second rule only as a caster or moonkin; the rim watches
-- Innervate, Nature's Swiftness, Barkskin, Dash and Nature's Grasp as a caster, Dash and Barkskin in Cat Form, and
-- Frenzied Regeneration, Enrage, Barkskin and Dash in Bear Form; under Frames the bear's threat is a medal.
do
	local env, K, ns = New("DRUID", { 9898, 9907, 9881, 22812, 22842, 5229, 1850, 29166, 17116, 9634 }, { forms = { 132276 } })
	local b = Tracker(ns, "DRUID").built
	local function Rim()
		for name, piece in pairs(b) do
			if name:find("^cooldowns") and piece:IsShown() then return piece.lit.container._slots.lit.candidates.includeSpellIDs end
		end
		return {}
	end
	for _, case in ipairs({ { nil, true, { 29166, 17116, 22812, 1850 }, { 5229, 22842 } }, { 1, false, { 1850, 22812 }, { 5229, 29166, 17116 } },
		{ 8, false, { 22842, 5229, 22812, 1850 }, { 29166, 17116 } } }) do
		env._form = case[1]
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		local form = tostring(case[1] or 0)
		assert(b.fiveSecond:IsShown() == case[2], "form " .. form .. ": the five-second plaque " .. (case[2] and "shows" or "hides"))
		local ids = Rim()
		for _, id in ipairs(case[3]) do assert(ids[id], "form " .. form .. ": the rim watches " .. id) end
		for _, id in ipairs(case[4]) do assert(not ids[id], "form " .. form .. ": the rim leaves " .. id .. " out") end
	end
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local glow = Tracker(ns, "DRUID").built.tankGlowRow
	assert(glow and glow:IsShown() and glow.bar, "under Frames the bear's threat is a gem in the row")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Hot paths: an unrelated aura event reads Inner Fire once and no cooldown, a cooldown event reads no aura, and
-- another class loads no healer registration at all.
do
	local env, K = New("PRIEST", PRIEST)
	local reads, cds = 0, 0
	local read, cd = env.C_UnitAuras.GetPlayerAuraBySpellID, env.C_Spell.GetSpellCooldownDuration
	env.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
		reads = reads + 1
		return read(id)
	end
	env.C_Spell.GetSpellCooldownDuration = function(...)
		cds = cds + 1
		return cd(...)
	end
	env.FireEvent("UNIT_AURA", "player", {})
	assert(reads <= 1 and cds == 0, "an unrelated aura event: " .. reads .. " aura reads, " .. cds .. " cooldown lookups")
	reads = 0
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(reads == 0, "a cooldown event reads no aura: " .. reads)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
do
	local env, K, ns = New("WARRIOR", {})
	local classes = ns.SlabTrackers.CLASSES
	assert(not classes.PRIEST and not classes.DRUID and not classes.SHAMAN, "a warrior loads no healer registration")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Inner Fire's halo leaves the last band's dimming when the charges come back, and an unreadable count drops the
-- last-flame state instead of keeping the old one.
do
	local env, K, ns = New("PRIEST", PRIEST)
	local fire = Tracker(ns, "PRIEST").built.innerFire
	local function Charges(n)
		Slots.Set(env, "player", { { id = 10952, count = n, start = 0, duration = 600 } })
		env.FireEvent("UNIT_AURA", "player", {})
	end
	Charges(4)
	assert(fire.still:GetAlpha() == 0.5, "the last band dims the halo at rest")
	Charges(20)
	assert(fire.still:GetAlpha() == 1 and fire.fire:GetAlpha() == 0, "a fresh Inner Fire restores the halo")
	Charges(4)
	env.SetCombat(true)
	assert(fire.flicker:IsPlaying() and fire.fire:GetAlpha() == 0.5, "awake, the last flame flickers")
	env._aurasSecret = true
	Charges(16)
	assert(not fire.flicker:IsPlaying() and fire.fire:GetAlpha() == 1, "an unreadable count drops the flicker and the dimming, in combat too")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Each seat follows the spec and form it is in: a shadow priest before Shadowform casts Mind Blast, not Penance; in
-- Shadowform without Vampiric Embrace the right medal is Shadowfiend, not Shadowform again; a druid in Cat or Bear
-- Form without that form's own effects shows no caster seed.
do
	local env, K, ns = New("PRIEST", { 10952, 10947, 1316995, 15334 })
	local b = Tracker(ns, "PRIEST").built
	assert(b.mindBlast:IsShown() and not (b.penance and b.penance:IsShown()), "Shadow Weaving without Shadowform: Mind Blast, not Penance")
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
	assert(t.built.ankh.spec.seat[1] == 30 and t.built.ankh.spec.seat[2] == -60, "the ankh stands at the right foot, clear of the level badge")
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
	assert(not off.gutter:IsPlaying() and off.gutter.still and off.gutter.still:IsPlaying() and not (main.gutter.still and main.gutter.still:IsPlaying()),
		"Calm does not gutter: the stone in its last five minutes holds its light still, at the flicker's low alpha")
	K.Options.Write("Medallions", "motion", "off")
	assert(not off.gutter:IsPlaying() and not off.gutter.still:IsPlaying(), "Off shows neither")
	K.Options.Write("Medallions", "motion", "full")
	env._offHand = false
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED")
	assert(not off:IsShown() and main:IsShown(), "no off-hand weapon, no off-hand stone")
	assert(shock.timer._state.SwipeTexture[1] == ns.Slab.hub.crestPath, "the sweep takes the crest's own shape")
	env._cooling[10414] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(shock.timer, "SetCooldownFromDurationObject"), "a shock sweeps the emblem")
	assert(ankh.lit.bar:GetAlpha() == 1, "Reincarnation ready with an Ankh: the ankh is gold")
	env._ankhs = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(ankh.lit.bar:GetAlpha() < 1, "no Ankh in the bags: the ankh greys")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The ankh is a foot figure like the left foot's, charging over Reincarnation's own cooldown even when no
-- other piece watches cooldowns, and it greys without an Ankh in the bags.
do
	local env, K, ns = New("SHAMAN", { 20608 })
	local ankh = Tracker(ns, "SHAMAN").built.ankh
	assert(ankh.bar and ankh.spec.figure == "figureAnkh" and ankh.spec.size == 22, "the ankh is a figure the size of the left foot's")
	env._cooling[20608] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(ankh.timer and AB.W.LastCall(ankh.bar, "SetTimerDuration"), "Reincarnation's cooldown charges it from the base")
	assert(ankh.lit.bar:GetAlpha() == 1, "an Ankh in the bags keeps it bright")
	env._ankhs = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(ankh.lit.bar:GetAlpha() < 1, "no Ankh in the bags: it greys")
	assert(not ankh.lit.bloom:IsShown(), "and its gilt bloom goes out, so nothing gold says it is ready")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The off-hand stone is built whenever an imbue is known and shows while an off-hand weapon is equipped, so
-- equipping one in combat shows it with nothing built in combat lockdown.
do
	local env, K, ns = New("SHAMAN", SHAMAN, { offHand = false })
	env.SetCombat(true)
	env._offHand = true
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED")
	local off = Tracker(ns, "SHAMAN").built.offHand
	assert(off and off:IsShown(), "an off hand equipped in combat shows its stone")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Under Frames the oil is the crest's jewel at medal size, never an icon.
do
	local env, K, ns = New("PRIEST", PRIEST)
	env._oils = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local oil = Tracker(ns, "PRIEST").built.oilRow
	assert(oil and oil:IsShown() and oil.bar and not oil.steel, "the row's oil is a jewel whose liquid drains with the enchant")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Imbues are imbues: another temporary enchant is no imbue, and under Frames each weapon's stone is the crest's own
-- at medal size: its rune in the element's colour, a gilt ring the enchant's own timer drains and the last five
-- minutes' gutter. Oil is oil.
do
	local env, K, ns = New("SHAMAN", SHAMAN)
	local t, Tokens = Tracker(ns, "SHAMAN"), K.Tokens
	local main = t.built.mainHand
	env._aurasSecret = true
	env.SetCombat(true)
	env._enchants[16] = { enchantID = 9999, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 1, { start = 0, duration = 3600 })
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(main.light:GetAlpha() == 0 and main.rim:IsShown() and main.pulse:IsPlaying(), "an enchant that is no imbue leaves the stone dark under the pulsing rim")
	env._enchants[16] = { enchantID = 1669, remainingTimeMs = 200000, chargesRemaining = 0, hasExpirationTime = true }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(main.light:GetAlpha() == 1 and not main.rim:IsShown() and main.gutter:IsPlaying(), "Windfury in combat with auras secret lights the rune, drops the rim and gutters its last minutes")
	env._enchants[16].remainingTimeMs = 1800000
	env._enchants[17] = { enchantID = 1666, remainingTimeMs = 200000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 2, { start = 0, duration = 3600 })
	env._aurasSecret = false
	env.SetCombat(false)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	env._aurasSecret = true
	env.SetCombat(true)
	local mainRow, offRow = t.built.mainHandRow, t.built.offHandRow
	local function Lit(row, token)
		local r, g, b = Tokens.Color(token)
		local vr, vg, vb = row.rune:GetVertexColor()
		return row.light:GetAlpha() == 1 and math.abs(vr - r) + math.abs(vg - g) + math.abs(vb - b) < 1e-6
	end
	assert(Lit(mainRow, "totemAir") and Lit(offRow, "totemFire"), "Windfury and Flametongue each light the rune in their element's colour")
	assert(AB.W.LastCall(mainRow.lit._cooldown, "SetCooldownFromDurationObject"), "each weapon's stone drains a gilt ring with the enchant's own timer")
	env._enchants[16] = { enchantID = 1666, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(Lit(mainRow, "totemFire"), "Flametongue over Windfury in combat with auras secret turns the rune to fire at once")
	env._enchants[16] = { enchantID = 9999, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	assert(mainRow.light:GetAlpha() == 0 and mainRow.rim:IsShown(), "an enchant that is no imbue leaves the stone dark under its rim")
	env._enchants[16] = { enchantID = 1669, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
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

-- A healer priest's shield is a ward dome over the emblem and Renew and Mending stand on the feet, each burning down
-- with its aura; Mending takes the gem; a shadow priest gets the plague and Shadow Word: Death on the feet and Silence
-- instead; an oil in the bags brings the oil socket.
do
	local env, K, ns = New("PRIEST", { 10901, 25315, 1240827, 10894, 10947 })
	local b = Tracker(ns, "PRIEST").built
	assert(b.mend:IsShown() and b.renew:IsShown() and b.mended:IsShown() and b.mend.lit.container._slots.lit.filter == "HELPFUL|PLAYER", "a healer's shield, Renew and Mending on the target")
	for name, want in pairs({ mend = { "figureDome", 0, 16, 116 }, renew = { "figureRenew", -30, -60, 22 }, mended = { "figureMending", 30, -60, 22 } }) do
		local spec = b[name].spec
		assert(spec.figure == want[1] and spec.seat[1] == want[2] and spec.seat[2] == want[3] and spec.size == want[4] and b[name].lit.bar, name .. ": " .. want[1] .. " at " .. want[2] .. "," .. want[3])
	end
	Slots.Set(env, "target", { { id = 10901, count = 0, start = 0, duration = 30 } })
	assert(b.mend.lit:IsShown() and AB.W.LastCall(b.mend.lit.bar, "SetTimerDuration") and b.mend.lit.bar:GetAlpha() < 1, "the shield raises a translucent dome that burns down with it")
	Slots.Set(env, "target", nil)
	assert(not b.mend.lit:IsShown(), "and the dome goes with the shield")
	assert(b.mending:IsShown() and not b.pain:IsShown(), "from level 40 Prayer of Mending takes the gem")
	assert(not b.plague and not b.death and not b.oil, "no shadow piece and no oil socket without one")
	env._known[15473], env._known[19280], env._known[1309636], env._known[15487] = true, true, true, true
	env._oils = 1
	ns.SlabTrackers.Update()
	b = Tracker(ns, "PRIEST").built
	assert(b.plague:IsShown() and b.death:IsShown() and b.silence:IsShown() and not b.mend:IsVisible() and not b.renew:IsVisible() and b.pain:IsShown(), "a shadow priest: Devouring Plague, Shadow Word: Death and Silence, Pain on the gem, no dome")
	assert(b.plague.spec.seat[1] == -30 and b.death.spec.seat[1] == 30, "the plague and the reaper stand on the feet")
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
	assert(b.growl.spec.size == 22 and b.growl.spec.feed == "cooldown" and b.growl.bar, "the feet hold small charging figures")
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
	assert(t.built.seedLeftRow:IsShown() and t.built.bloomRow:IsShown() and t.built.bloomRow.lit.bar, "the row's Clearcasting is the crest's leaf, draining with the aura")
	local cooldowns = t.built.cooldownsRow
	assert(cooldowns:IsShown() and cooldowns.sigils[1] and not cooldowns.timer, "the row's cooldowns are the crest's sigils, with no rim")
	local point, anchor, rel = t.row:GetPoint(1)
	assert(point == "BOTTOMLEFT" and rel == "TOPLEFT" and anchor == ns.bars.stance.buttons[1], "the row stands above the forms")
	local cells, count = {}, 0
	for name, piece in pairs(t.built) do
		if name:find("Row$") and piece:IsShown() and name ~= "cooldownsRow" then
			local _, _, _, x, y = piece:GetPoint(1)
			cells[x .. "," .. y], count = name, count + 1
		end
	end
	for n = 0, count - 1 do
		local x, y = ns.SlabMedals.Cell(n)
		assert(cells[K.Widgets.Snap(t.row, x) .. "," .. K.Widgets.Snap(t.row, y)], "row cell " .. n .. " is empty or shared: a custom place() must take cell n and return n + 1")
	end
	local x, y = ns.SlabMedals.Cell(math.ceil(count / ns.SlabMedals.LINE) * ns.SlabMedals.LINE)
	local _, _, _, cx, cy = cooldowns:GetPoint(1)
	assert(cx == K.Widgets.Snap(t.row, x) and cy == K.Widgets.Snap(t.row, y), "the cooldown sigils take a line of their own above the other pieces")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(not t.row:IsShown() and t.built.seedLeft:IsShown(), "back under Medallions the crest pieces return")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Frames: Inner Fire's flame burns down with its charges, as the crest's flames do.
do
	local env, K, ns = New("PRIEST", PRIEST)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local row = Tracker(ns, "PRIEST").built.innerFireRow
	Slots.Set(env, "player", { { id = 10952, count = 4, start = 0, duration = 600 } })
	assert(math.abs(Fill(env, row.lit.bar) - 0.2) < 1e-6, "four of twenty charges: a fifth of the flame")
	Slots.Set(env, "player", { { id = 10952, count = 20, start = 0, duration = 600 } })
	assert(Fill(env, row.lit.bar) == 1, "and all of it after a fresh cast")
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
		local w = right and right - region:GetLeft() or region:GetWidth()
		for _, v in ipairs({ w * s, (right and region:GetTop() - region:GetBottom() or region:GetHeight()) * s }) do
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

-- No crest piece of these classes draws a spell or item icon, on the crest or in the Frames row, in any form or
-- spec: every texture is the crest's own art (a path, never a file ID) and no aura button is handed an icon region.
-- Only the shared cooldown sigils (#809) and the swing ring (#808) keep their forged rings.
local SOCKET, SHARED = { "Ring128", "Ring256", "Enamel128", "Enamel256" }, { crestCooldowns = true, crestSwing = true }
local function Icons(frame, found, mine)
	if frame._icon then
		found[#found + 1] = "an aura button's icon"
	end
	for _, region in ipairs(frame._regions or {}) do
		local texture = region._state and region._state.Texture and region._state.Texture[1]
		if type(texture) == "number" or type(texture) == "string" and texture:lower():find("interface\\icons\\", 1, true) then
			found[#found + 1] = "icon " .. texture
		end
		for _, name in ipairs(mine and type(texture) == "string" and SOCKET or {}) do
			if texture:find(name, 1, true) then
				found[#found + 1] = "a round medal frame (" .. name .. ")"
			end
		end
	end
	for _, child in ipairs(frame._kids or {}) do
		Icons(child, found, mine)
	end
	return found
end
local function Guard(form)
	local found = Icons(form.frame, {}, false)
	for _, piece in pairs(form.pieces) do
		if not SHARED[piece.spec.key] then
			Icons(piece, found, true)
		end
	end
	return found
end
for _, case in ipairs({
	{ "PRIEST", { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827, 15487 } },
	{ "PRIEST", { 10952, 10947, 401977, 10894, 10060, 15473, 15334, 15286, 19280, 1309636, 15487 } },
	{ "DRUID", { 9835, 24977, 25299, 9858, 9904, 9826, 9896, 16864, 18562, 17116, 29166, 9898, 9907, 9881, 1238215, 6795, 1238122, 1238070, 8983, 9634, 22812 } },
	{ "SHAMAN", { 16362, 10414, 20608, 16166, 29228, 17364, 408521 } },
}) do
	local env, K, ns = New(case[1], case[2])
	env._oils = 1
	ns.SlabTrackers.Update()
	for _, style in ipairs({ "medallions", "frames" }) do
		K.Options.Write("HudStyle", "style", style)
		env.RunTimers()
		local found = Guard(ns.SlabTrackers.state.forms[style == "frames" and "row" or "crest"])
		assert(#found == 0, case[1] .. " under " .. style .. " draws icons or round medal frames (" .. table.concat(found, ", ") .. "): give the piece a free-standing figure, a jewel or a sigil")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Break-out: the shoulders' objects stand on the ring, the feet's beside the level badge, the crown's above it; a
-- cat's Rake and Rip tear across the crest and a bear's roar rises over the crown; an aura's bloom breathes only at
-- Full; Shadowform floods the crest violet in the form, in combat too, and its switch takes it away.
do
	local known = { 6795, 1238122 }
	for _, id in ipairs(DRUID) do known[#known + 1] = id end
	local env, K, ns = New("DRUID", known)
	local b = Tracker(ns, "DRUID").built
	local function At(piece, x, y, size)
		return piece.spec.seat[1] == x and piece.spec.seat[2] == y and piece.spec.size == size
	end
	assert(At(b.seedLeft, -62, 40, 30) and At(b.seedRight, 62, 40, 30) and At(b.third, 0, 92, 30), "the moon and the swarm perch on the ring, the sparkle above the crown")
	assert(At(b.rake, -44, 6, 60) and At(b.rip, 44, 6, 56) and At(b.roar, 0, 88, 40), "the rakes and the tear cross the crest, the roar rises over the crown")
	assert(At(b.growl, -30, -60, 22) and At(b.charge, 30, -60, 22), "the fang and the chevrons stand at the feet")
	local moon = b.seedLeft.lits[1]
	local function Breathing()
		for _, group in ipairs(moon._shownAnimations or {}) do
			if group == moon.loop then return true end
		end
		return false
	end
	assert(moon.loop and Breathing(), "at Full the engine breathes the moon's bloom while Moonfire is up")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not Breathing(), "Calm holds it still")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
do
	local env, K, ns = New("PRIEST", { 10952, 10947, 15473, 15334, 15286, 401977 })
	local b = Tracker(ns, "PRIEST").built
	assert(b.flood and not b.flood:IsShown(), "out of Shadowform the crest is not flooded")
	env.SetCombat(true)
	env._aurasSecret, env._form = true, 28
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local tint
	for _, region in ipairs(b.flood._regions) do
		tint = tint or region._state.Texture and region._state.Texture[1] == ns.Slab.hub.crestPath and region
	end
	assert(b.flood:IsShown() and tint and tint:GetAlpha() > 0, "in Shadowform, even in combat, the crest floods violet")
	env._form = 0
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(not b.flood:IsShown() and b.shadowform:IsShown(), "leaving the form drains the flood and the shroud waits on the right")
	local steel
	for _, part in ipairs(b.shadowform.parts) do
		local st = part._state or {}
		steel = steel or st.Desaturated and st.Desaturated[1] and tostring(st.Texture and st.Texture[1]):find("Shroud", 1, true) and part:IsVisible()
	end
	assert(steel, "out of the form the shroud stands in steel until it is worn")
	env._aurasSecret = false
	env.SetCombat(false)
	env._form = 28
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	K.Options.Write("ActionBars", "crestShadowfiend", false)
	env.RunTimers()
	assert(not b.flood:IsVisible(), "the switch takes the flood away")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Every piece stays inside the crest's footprint at four screens: within 78 units of the centre across, from 78 below
-- to 110 above (under the cast bar), and off the level badge; blooms, sparks and flares are soft glow and may spill,
-- and the five-second ring is the badge's own.
for _, size in ipairs(SIZES) do
	for _, case in ipairs({ { "PRIEST", { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827 } }, { "PRIEST", { 10952, 10947, 15473, 15334, 15286, 19280, 1309636, 15487 }, 28 },
		{ "DRUID", DRUID }, { "DRUID", DRUID, 1 }, { "DRUID", DRUID, 8 }, { "SHAMAN", { 16362, 10414, 20608, 16166, 29228 } } }) do
		local env, K, ns = New(case[1], case[2], { size = size })
		env._form = case[3]
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		local hub = ns.Slab.hub
		local u = hub:GetWidth() / ns.Slab.RING
		local cx, cy = hub:GetCenter()
		local pl, pr, pb, pt = hub.plaque:GetLeft(), hub.plaque:GetRight(), hub.plaque:GetBottom(), hub.plaque:GetTop()
		local at = size[1] .. "x" .. size[2] .. " " .. case[1] .. " form " .. tostring(case[3] or 0) .. ": "
		local function Edges(part)
			local e = { part:GetLeft(), part:GetRight(), part:GetBottom(), part:GetTop() }
			for i = 1, 4 do
				e[i] = env.issecretvalue(e[i]) and env.Reveal(e[i]) or e[i]
			end
			return unpack(e)
		end
		for key, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			if piece:IsVisible() and not piece.sigils and piece.spec.seat ~= "plaque" then
				for n, part in ipairs(piece.parts) do
					local texture = part._state and part._state.Texture and part._state.Texture[1]
					local pl2, pr2, pb2, pt2 = Edges(part)
					if not (type(texture) == "string" and (texture:find("Glow", 1, true) or texture:find("Burst", 1, true))) and pl2 then
						local l, r, bo, t = (pl2 - cx) / u, (pr2 - cx) / u, (pb2 - cy) / u, (pt2 - cy) / u
						assert(l >= -78.5 and r <= 78.5 and bo >= -78.5 and t <= 110.5, at .. key .. " part " .. n .. " leaves the crest's footprint: " .. string.format("%.0f %.0f %.0f %.0f", l, r, bo, t))
						local clear = pr2 <= pl or pl2 >= pr or pt2 <= pb or pb2 >= pt or (r - l) >= 100
						assert(clear, at .. key .. " part " .. n .. " covers the level badge")
					end
				end
			end
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	end
end

-- The guard catches an icon path or a file ID under a sigil, and a round frame under a piece whose builder replaced
-- its spec (the Frames Inner Fire).
do
	local env, K, ns = New("PRIEST", { 10952, 10060 })
	local crest = ns.SlabTrackers.state.forms.crest
	assert(#Guard(crest) == 0, "a clean crest passes the guard")
	local sigil = Tracker(ns, "PRIEST").built.cooldowns.sigils[1]
	sigil:CreateTexture():SetTexture("Interface\\Icons\\Spell_Holy_PowerInfusion")
	assert(#Guard(crest) == 1, "an icon path under a sigil is an icon")
	sigil:CreateTexture():SetTexture(135939)
	assert(#Guard(crest) == 2, "so is a file ID under a sigil")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local row = ns.SlabTrackers.state.forms.row
	Tracker(ns, "PRIEST").built.innerFireRow:CreateTexture():SetTexture("Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Ring256.png")
	assert(#Guard(row) == 1, "a round frame under the Frames Inner Fire is caught though its builder replaced the spec")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Auras warn before they end and arrive softly, as the approved films do: a figure fades in over 0.12 s when its aura
-- appears (the engine's shown animation) and flickers inside the engine's pandemic window (its pandemic-active
-- animation; the engine hides a button the moment its aura goes, so there is no fade out). A ready cooldown's bloom
-- breathes at Full while the crest is awake. Calm holds them still.
do
	local env, K, ns = New("PRIEST", { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827 })
	local b = Tracker(ns, "PRIEST").built
	local renew, lance = b.renew.lits[1], b.penance.lit
	local function Has(list, group)
		for _, g in ipairs(list or {}) do
			if g == group then return true end
		end
		return false
	end
	assert(renew.flicker and Has(renew._pandemicAnimations, renew.flicker), "at Full the engine flickers an aura's figure in its pandemic window")
	assert(renew.loops and Has(renew._shownAnimations, renew.loops[1]), "and fades it in as the aura appears")
	assert(b.mend.lits[1].loops and not b.mend.flare, "the shield's dome fades in over the crest; no burst whites it out")
	Slots.Set(env, "target", { { id = 25315, count = 0, start = 0, duration = 15 } })
	assert(renew.loops[1]:IsPlaying() and not renew.flicker:IsPlaying(), "Renew lands: the fade plays, no warning yet")
	Slots.Set(env, "target", { { id = 25315, count = 0, start = 0, duration = 15, pandemic = true } })
	assert(renew.flicker:IsPlaying(), "inside its pandemic window the figure flickers")
	Slots.Set(env, "target", nil)
	assert(not renew.flicker:IsPlaying() and not renew:IsShown(), "and it is gone when Renew ends")
	env.SetCombat(true)
	env.RunTimers()
	assert(lance.loop and lance.loop:IsPlaying(), "a ready cooldown's bloom breathes at Full")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(not Has(renew._pandemicAnimations, renew.flicker) and not Has(renew._shownAnimations, renew.loops[1]) and not lance.loop:IsPlaying(), "Calm holds them still")
	env.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A motion change resets the shared sigil container once, not once per sigil: registering a sigil's flash never
-- toggles the container it shares (each SetEnabled refreshes every aura on it, Blizzard_AuraContainer.lua:28).
do
	local env, K, ns = New("PRIEST", { 10952, 10060, 14751, 6346, 2651 })
	local rim = Tracker(ns, "PRIEST").built.cooldowns
	local calls, set = 0, rim.lit.container.SetEnabled
	rim.lit.container.SetEnabled = function(self, on)
		calls = calls + 1
		return set(self, on)
	end
	-- The flash is a glow of its own, in a slot under a layer of the addon's own that only Full lights: the sigil's slot carries no cue, so a level chosen in combat
	-- stops the flash from showing at once.
	local sigil = rim.sigils[1]
	local flashed = sigil.flashed
	assert(sigil.flash and sigil.loop == nil and flashed._shownAnimations[1] == sigil.flash and #(sigil._shownAnimations or {}) == 0, "a healer's sigil has its flash, on a slot beside its own")
	assert(flashed.container ~= rim.lit.container and rim.lit.flash:GetAlpha() == 1, "the flash's slots have a feed of their own under a layer that shows at Full")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(calls == 2, "Full to Calm resets the shared container once (off, on), not " .. calls .. " times")
	assert(flashed._shownAnimations[1] == sigil.flash and rim.lit.flash:GetAlpha() == 0, "Calm darkens the flash's layer and leaves the engine its group")
	-- A flash that began unseen is not shown half played: Full inside its time keeps its layer dark, with the sigil still up.
	env.GetTime = function() return env._now end
	env._aurasSecret = true
	env.SetCombat(true)
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	Slots.Set(env, "player", { { id = 10060, count = 0, icon = 135939, start = 0, duration = 15 } })
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	local function Up(which)
		return Engine(function() return which:IsShown() and which:GetEffectiveAlpha() > 0 and which.flash:IsPlaying() end)
	end
	assert(Up(sigil), "the engine flashes the dark slot as the cooldown shows")
	K.Options.Write("Medallions", "motion", "full")
	assert(rim.lit.flash:GetAlpha() == 0 and Up(sigil), "Calm to Full inside the flash: its layer stays dark and the sigil stays up")
	-- The sigils share the flash's layer: a second cooldown gained while the layer is still dark for the first keeps it dark for its own whole flash.
	local second = rim.sigils[2]
	local early = armed
	armed = {}
	env._now = env._now + 0.3
	Slots.Set(env, "player", { { id = 10060, count = 0, icon = 135939, start = 0, duration = 15 }, { id = 14751, count = 0, start = 0, duration = 15 } })
	assert(Up(second), "a second cooldown shows its sigil and the engine flashes its dark slot")
	env._now = env._now + 0.2
	assert(#early > 0, "the first flash's layer waits on a timer")
	for _, fn in ipairs(early) do fn() end
	assert(rim.lit.flash:GetAlpha() == 0, "the first flash's end leaves the layer dark while the second, begun unseen, still plays")
	env._now = env._now + 1
	for _, fn in ipairs(armed) do fn() end
	assert(rim.lit.flash:GetAlpha() == 1, "and the layer shows again once the last unseen flash is over")
	K.Options.Write("Medallions", "motion", "calm")
	K.Options.Write("Medallions", "motion", "full")
	assert(rim.lit.flash:GetAlpha() == 1, "a flash whose time is over hides nothing")
	env.C_Timer.After = after
	env._aurasSecret = false
	env.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The cat's Faerie Fire jewel keeps the crest's socket size, the same as its sibling jewels, not its caster crown's.
do
	local known = { 1238070 }
	for _, id in ipairs(DRUID) do known[#known + 1] = id end
	local env, K, ns = New("DRUID", known)
	local b = Tracker(ns, "DRUID").built
	assert(b.faerieGem.units == b.bite.units and b.bite.units == 22, "the cat's Faerie Fire jewel is 22 units like Bite and Bash, not " .. b.faerieGem.units)
	assert(b.rake.flare._regions[1].units <= 72, "Rake's arrival flare stays local, no larger than a perched figure's, not " .. b.rake.flare._regions[1].units)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Every figure's spark is a part the crest snaps to whole pixels.
do
	local env, K, ns = New("PRIEST", { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827 })
	for key, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		for _, lit in ipairs(piece.lits or {}) do
			local spark
			for _, region in ipairs(lit.bar and lit.bar._regions or {}) do
				spark = spark or region ~= lit.bar:GetStatusBarTexture() and region
			end
			local listed = false
			for _, part in ipairs(piece.parts) do
				listed = listed or part == spark
			end
			assert(not lit.bar or spark and listed, key .. "'s spark is not a part, so it is never snapped")
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Prayer of Mending's bloom is gold, so its white ring and star keep their shape at 1080.
do
	local env, K, ns = New("PRIEST", { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827 })
	local r, g, bl = Tracker(ns, "PRIEST").built.mended.lits[1].bloom:GetVertexColor()
	assert(not (r > 0.9 and g > 0.9 and bl > 0.9), "Prayer of Mending's bloom is not white")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Stormstrike alone builds the left foot: its bolt burns down there.
do
	local env, K, ns = New("SHAMAN", { 17364 })
	local foot = Tracker(ns, "SHAMAN").built.flameShock
	assert(foot, "a shaman who knows only Stormstrike gets the left foot")
	Slots.Set(env, "target", { { id = 17364, count = 0, harmful = true, start = 0, duration = 12 } })
	assert(foot.lits[2]:IsShown() and foot.lits[2].spec.figure == "figureStrike", "Stormstrike's bolt shows there")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars crest healers ok")
