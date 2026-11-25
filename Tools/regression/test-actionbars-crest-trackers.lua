-- test-actionbars-crest-trackers.lua: the melee crest trackers (SlabTrackers.lua): other classes get no tracker frame, container or event; a character sees only the pieces whose spells it knows; a warrior's Battle Shout medal (anyone's shout) sits on the left shoulder, the opening on the right lights for the first usable strike, and Enrage burns round the inner rim and holds still at rest; a paladin's Seal sits above the crest, Judgement's cooldown sweeps on the left shoulder and its Judgement on the target lights the right one; the jewels light from Vengeance stacks, else Holy Shield charges; a rogue's Slice and Dice and Rupture take the shoulders and a vial per weapon (the off hand only with an off-hand item) drains on the lower ring; each switch hides its piece and with every switch off nothing shows or listens; nothing is built while auras are secret until combat ends; under Frames the pieces stand as medals in a row beside the stance bar; every part is an even number of pixels at four screen sizes and nothing runs OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

local function New(class, known, opts)
	opts = opts or {}
	local size = opts.size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._known = {}
			for _, id in ipairs(known or {}) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e._aurasSecret = opts.secret
			e._usable, e._cooling = {}, {}
			e.C_Spell.IsSpellUsable = function(id) return e._usable[id] == true, false end
			e.C_Spell.GetSpellCooldown = function(id) return { isActive = e._cooling[id] == true, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function(id) return { start = 0, finish = e._cooling[id] and 10 or 0 } end
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e.GetInventoryItemID = function(_, slot) return e._items and e._items[slot] end
			e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
			e._slotGroups = true
		Slots.Install(e)
		e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
			if opts.setup then opts.setup(e) end
		end,
	})
	local register = K.Events.Register
	env._trackerEvents = {}
	K.Events.Register = function(owner, event, fn)
		if owner:find("SlabTrackers", 1, true) or owner:find("SlabMedals", 1, true) then env._trackerEvents[event] = true end
		return register(owner, event, fn)
	end
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

local function Pieces(ns, form)
	local f = ns.SlabTrackers.state.forms[form or "crest"]
	local shown = {}
	for key, p in pairs(f and f.pieces or {}) do
		if p:IsVisible() then shown[tonumber(key:match("^(%d+)"))] = p end
	end
	return shown, f
end

local function Lit(p)
	for _, lit in ipairs(p.lits or { p.lit }) do
		if lit:IsShown() then return true end
	end
	return false
end

local function Seat(ns, p)
	local hub = ns.Slab.hub
	local x, y = p:GetCenter()
	local hx, hy = hub:GetCenter()
	local s = p:GetEffectiveScale() / hub:GetEffectiveScale()
	return x * s - hx, y * s - hy
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do n = n + Updating(child) end
	return n
end

-- A level 1 warrior: Battle Shout only.
do
	local env, K, ns = New("WARRIOR", { 6673 })
	local shown = Pieces(ns)
	assert(shown[1] and not shown[2] and not shown[3], "a fresh warrior has the shout medal and nothing else")
	local x, y = Seat(ns, shown[1])
	assert(x < -40 and y > 0 and y < 10, "the horn hangs on the ring's inner left side")
	assert(not Lit(shown[1]), "no shout: steel")
	Slots.Set(env, "player", { { id = 6673, count = 0, icon = 132333, start = 0, duration = 120, mine = false } })
	assert(Lit(shown[1]), "anyone's Battle Shout lights the medal")
	assert(AB.W.LastCall(shown[1].lit.bar, "SetTimerDuration"), "and drains its horn")
	Clean(env, K, "fresh warrior")
end

-- A warrior with everything: the opening and Enrage.
do
	local env, K, ns = New("WARRIOR", { 25289, 20662, 11585, 2687, 18499 })
	local shown = Pieces(ns)
	assert(shown[1] and shown[2] and shown[3], "shout, opening and Enrage")
	local x = Seat(ns, shown[2])
	assert(x > 40, "the opening sits on the right shoulder")
	assert(not Lit(shown[2]), "no strike usable: steel")
	env._usable[11585] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local function Drawn() return AB.W.LastCall(shown[2].lit.mask, "SetTexture")[1]:match("(%a+)%.png$") end
	assert(Lit(shown[2]) and Drawn() == "Sword", "Overpower usable draws a sword")
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(Drawn() == "Axe", "Execute takes priority with its axe")
	env._cooling[20662] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(Drawn() == "Sword", "a strike on cooldown stays dark")
	local rim = shown[3]
	local rx, ry = Seat(ns, rim)
	assert(math.abs(rx) < 1 and math.abs(ry) < 1 and rim.fire, "Enrage burns round the crest's centre")
	Slots.Set(env, "player", { { id = 29131, count = 0, start = 0, duration = 10 } })
	assert(Lit(rim) and AB.W.LastCall(rim.timer, "SetCooldownFromDurationObject"), "Bloodrage lights the rim and drains it")
	K.Store.Module("Medallions").restingCrest = true
	ns.SlabMedals.Rest()
	assert(rim.fire:GetAlpha() == (ns.Slab.Resting() and 0 or 1), "the fire follows the crest's rest")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	for _, key in ipairs({ "crestShout", "crestOpening", "crestEnrage", "crestCooldowns", "crestThreat", "crestHipLeft", "crestHipRight", "crestFootLeft", "crestFootRight", "crestTankGlow", "crestKill", "crestSwing" }) do
		K.Options.Write("ActionBars", key, false)
	end
	env.RunTimers()
	assert(next((Pieces(ns))) == nil and next(env._trackerEvents) ~= nil, "every switch off hides every piece")
	assert(not ns.SlabTrackers.state.forms.crest.frame:IsShown() and ns.SlabTrackers.state.listening == "falsenil", "and stops listening")
	K.Options.Write("ActionBars", "crestOpening", true)
	env.RunTimers()
	local back = Pieces(ns)
	assert(back[2] and not back[1] and not back[3], "one switch brings back its own piece")
	Clean(env, K, "warrior")
end

-- A paladin: Seal, Judgement, the judged target and the jewels.
do
	local env, K, ns = New("PALADIN", { 20154, 20165, 20271, 20049 })
	local shown = Pieces(ns)
	assert(shown[2] and shown[3] and shown[4], "Seal, Judgement and the judged target")
	local _, sy = Seat(ns, shown[2])
	local jx = Seat(ns, shown[3])
	local tx = Seat(ns, shown[4])
	assert(sy > 80 and jx < -40 and tx > 40, "the Seal above, Judgement left, the target right")
	Slots.Set(env, "player", { { id = 20154, count = 0, icon = 135960, start = 0, duration = 30 } })
	assert(#shown[2].lits == 2 and shown[2].lits[1]:IsShown() and not shown[2].lits[2]:IsShown(), "the Seal of Righteousness lights its own colour, not Light's; only the schools it knows are built")
	env._cooling[20271] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(shown[3].timer, "SetCooldownFromDurationObject") and AB.W.LastCall(shown[3].bar, "SetTimerDuration"), "Judgement's hammer charges over its cooldown")
	env._cooling[20271] = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(shown[3].timer, "SetCooldownFromDurationObject")[1].finish == 0, "a reset the client reports on SPELL_UPDATE_COOLDOWN, such as Cold Snap's or Preparation's, ends the timer at once")
	assert(shown[4].lit.container._unit == "target", "the judged medal watches the target")
	Slots.Set(env, "target", { { id = 20185, count = 0, harmful = true, mine = true, start = 0, duration = 10 } })
	assert(Lit(shown[4]), "your Judgement on the target lights it")
	Slots.Set(env, "target", { { id = 20185, count = 0, harmful = true, mine = false, start = 0, duration = 10 } })
	assert(not Lit(shown[4]), "another paladin's does not")
	local jewels = ns.SlabJewels.state
	assert(jewels.feed and #jewels.jewels == 5, "Vengeance feeds five jewels")
	Slots.Set(env, "player", { { id = 20050, count = 3 } })
	local lit = 0
	for _, j in ipairs(jewels.jewels) do
		local low, high = j.gem:GetMinMaxValues()
		local v = env.issecretvalue(j.gem:GetValue()) and env.Reveal(j.gem:GetValue()) or j.gem:GetValue()
		lit = lit + (v >= high and low < high and 1 or 0)
	end
	assert(lit == 3, "three Vengeance stacks light three jewels, got " .. lit)
	K.Options.Write("ActionBars", "crestVengeance", false)
	env.RunTimers()
	assert(jewels.feed == nil and jewels.jewels == jewels.sets.power, "the switch off restores the holy power jewels")
	Clean(env, K, "paladin")
end

do
	local env, K, ns = New("PALADIN", { 20154, 20925 })
	assert(ns.SlabJewels.state.feed and ns.SlabJewels.state.feed.spells[1] == 20925, "without Vengeance, Holy Shield feeds the jewels")
	assert(not Pieces(ns)[3], "no Judgement known: no Judgement medal")
	Clean(env, K, "paladin holy shield")
end

-- A rogue: Slice and Dice, Rupture and the vials.
do
	local env, K, ns = New("ROGUE", { 5171, 1943, 2842 }, { setup = function(e) e._items = { [16] = 2092 } end })
	local shown = Pieces(ns)
	assert(shown[1] and shown[2] and shown[3] and not shown[4], "Slice and Dice, Rupture and the main-hand vial; no off hand, no second vial")
	local vx, vy = Seat(ns, shown[3])
	assert(vx < -30 and vy < -20, "the main-hand vial sits on the lower left of the ring")
	ns.SlabMedals.Engine({ shown[3] }, true, true)
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	assert(Lit(shown[3]) and AB.W.LastCall(shown[3].lit.bar, "SetTimerDuration"), "a poison fills the vial and drains it")
	env._items = { [16] = 2092, [17] = 2092 }
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 17)
	assert(Pieces(ns)[4], "an off-hand item brings the second vial")
	Clean(env, K, "rogue")
end

-- Major cooldowns: the newest burns on the rim and each running family the character has lights its sigil, each in
-- its own place below the emblem; a family it lacks (another race's racial, an unlearned talent) takes no place.
do
	local env, K, ns = New("ROGUE", { 13877, 5277 })
	local rim = Pieces(ns)[5]
	assert(rim and rim.sigils and #rim.sigils == 17, "a rogue with Blade Flurry gets the cooldown rim: one slot for each of its seven families, the racials and the potions")
	local placed = {}
	for _, b in ipairs(rim.sigils) do placed[#placed + 1] = b.at and b.family.sigil or nil end
	assert(table.concat(placed, ",") == "Flurry,Evade,Potion", "only Blade Flurry, Evasion and the potions take places: " .. table.concat(placed, ","))
	Slots.Set(env, "player", { { id = 13877, count = 0, icon = 132350, start = 0, duration = 15 }, { id = 5277, count = 0, icon = 136205, start = 0, duration = 15 } })
	assert(rim.lit:IsShown() and rim.sigils[1]:IsShown() and rim.sigils[3]:IsShown() and not rim.sigils[2]:IsShown(), "Blade Flurry's and Evasion's sigils light, Adrenaline Rush's stays dark")
	K.Options.Write("ActionBars", "crestCooldowns", false)
	env.RunTimers()
	assert(not Pieces(ns)[5], "its switch hides it")
	Clean(env, K, "cooldowns")
end

-- Eureka!, the gnome racial, has its own spell for each class that has it on Forever (the 71091 cooldown sets: rogue
-- 1259812, warrior 1259813, mage 1259817, warlock 1259821, priest 1259823); each one places and lights the shared Gear
-- sigil on its class's cooldown rim.
for _, case in ipairs({ { "ROGUE", 1259812 }, { "WARRIOR", 1259813 }, { "MAGE", 1259817 }, { "WARLOCK", 1259821 }, { "PRIEST", 1259823 } }) do
	local class, eureka = case[1], case[2]
	local env, K, ns = New(class, { eureka })
	local gear
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		for _, b in ipairs(p.sigils or {}) do
			if b.at and b.family.sigil == "Gear" then gear = b end
		end
	end
	assert(gear, class .. ": Eureka! " .. eureka .. " places the Gear sigil on the cooldown rim")
	Slots.Set(env, "player", { { id = eureka, count = 0, icon = 136243, start = 0, duration = 8 } })
	assert(gear:IsShown(), class .. ": its Eureka! lights the Gear sigil")
	Clean(env, K, class .. " Eureka!")
end

-- Stances and stealth: every known choice is built out of combat, the form picks which shows, in combat too.
do
	local env, K, ns = New("WARRIOR", { 25289, 20662, 11585, 25288 })
	env.GetShapeshiftFormID = function() return env._form end
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local crest = ns.SlabTrackers.state.forms.crest
	assert(crest.pieces["2:1"]:IsVisible() and crest.pieces["2:2"] and crest.pieces["2:3"] and not crest.pieces["2:3"]:IsVisible(), "Defensive Stance shows its own opening; the others are built and hidden")
	env._aurasSecret = true
	env._form = 17
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(crest.pieces["2:3"]:IsVisible() and not crest.pieces["2:1"]:IsVisible(), "Battle Stance in combat swaps the seat without the engine")
	env._form = env.Secret(18)
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(crest.pieces["2:3"]:IsVisible(), "a secret form keeps the last")
	env._aurasSecret = false
	Clean(env, K, "stances")
end

do
	local env, K, ns = New("ROGUE", { 5171, 1943, 1833, 1856 })
	env.GetShapeshiftFormID = function() return env._form end
	env._form = 30
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local crest = ns.SlabTrackers.state.forms.crest
	assert(crest.pieces["1:1"]:IsVisible() and crest.pieces["2:1"]:IsVisible() and not crest.pieces["1:2"]:IsVisible(), "Stealth: the opener and Vanish take the shoulders")
	env._form = nil
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(crest.pieces["1:2"]:IsVisible() and crest.pieces["2:2"]:IsVisible(), "out of Stealth: Slice and Dice and Rupture")
	Clean(env, K, "stealth")
end

-- Threat, items, counts and the five-second rule.
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20925 })
	env.GetShapeshiftFormID = function() return nil end
	local tanking, scaled = env.Secret(true), env.Secret(80)
	env.UnitDetailedThreatSituation = function() return tanking, 3, scaled end
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
	local crest = ns.SlabTrackers.state.forms.crest
	local gem, glow
	for _, piece in pairs(crest.pieces) do
		if piece.spec.key == "crestFootRight" and piece.spec.feed == "threat" and piece:IsVisible() then gem = piece end
		if piece.spec.key == "crestTankGlow" then glow = piece end
	end
	assert(gem and AB.W.LastCall(gem.bar, "SetValue")[1] == scaled and AB.W.LastCall(gem.lit, "SetAlphaFromBoolean")[1] == tanking, "a Protection paladin's threat foot takes the secrets as they are")
	assert(glow and glow:IsVisible() and AB.W.LastCall(glow.lit, "SetAlphaFromBoolean")[1] == tanking, "and the crest glows gold while tanking")
	local plaque
	for _, piece in pairs(crest.pieces) do
		if piece.spec.feed == "fiveSecond" then plaque = piece end
	end
	env.C_Spell.GetSpellPowerCost = function() return { { type = 0, cost = 50 } } end
	env.GetTime = function() return 100 end
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 20154)
	assert(plaque and AB.W.LastCall(plaque.timer, "SetCooldown")[2] == 5, "a mana spell starts the five-second ring round the level badge")
	Clean(env, K, "threat and five seconds")
end

do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20473 })
	env.C_Item = { GetItemCount = function(id) return id == 13444 and 2 or 0 end, GetItemCooldown = function() return 10, 120, true end,
		GetItemIconByID = function(id) return 200000 + id end }
	env.FireEvent("BAG_UPDATE_DELAYED")
	local potion
	for key, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if key:match("^9:") and piece:IsVisible() then potion = piece end
	end
	assert(potion and potion.lit:IsShown() and not potion.lit.icon and AB.W.LastCall(potion.timer, "SetCooldown")[2] == 120, "a Holy paladin's right foot fills a vial for the mana potion in the bags and rings its cooldown")
	assert(ns.SlabJewels.state.count == 0, "and a Holy paladin draws no jewels")
	Clean(env, K, "holy items")
end

-- An item vial empties and refills while it cools under a draining rim, and with no item it is an empty vial (#778 6).
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20473 })
	local cooling = { 10, 120 }
	env.C_Item = { GetItemCount = function(id) return id == 13444 and 2 or 0 end, GetItemCooldown = function() return cooling[1], cooling[2], true end,
		GetItemIconByID = function(id) return 200000 + id end }
	env.FireEvent("BAG_UPDATE_DELAYED")
	local feet = {}
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece:IsVisible() and piece.spec.feed == "item" then feet[piece.spec.key] = piece end
	end
	local stone, potion = feet.crestFootLeft, feet.crestFootRight
	assert(stone and not stone.lit:IsShown() and stone.ghost:IsShown(), "no healthstone: an empty vial, not a spell's icon")
	assert(AB.W.LastCall(potion.bar, "SetTimerDuration"), "a cooling potion's vial refills")
	assert(AB.W.LastCall(potion.timer, "SetSwipeTexture")[1] == (K.Tokens.Texture("orbRing")), "under a draining rim, not a dark pie")
	cooling = { 0, 0 }
	potion.timer:GetScript("OnCooldownDone")(potion.timer)
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(potion.bar, "SetValue")[1] == 1, "ready, it is full")
	Clean(env, K, "item cooling")
end

-- A class file registers its own rows and hooks.
do
	local env, K, ns = New("PRIEST", { 10060 })
	local painted, moved = 0, 0
	ns.SlabTrackers.CLASSES.PRIEST = nil
	ns.SlabTrackers.Register("PRIEST", {
		{ key = "crestCooldowns", seat = "cooldowns", color = "gilt", families = { { spells = { 10060 }, sigil = "Infusion" } } },
		{ key = "crestTest", seat = { 0, 100 }, build = function(parent, spec, level)
			local m = ns.SlabMedals.Medal(parent, { feed = "usable", candidates = { 10060 }, texture = spec.texture }, level)
			m.custom = true
			return m
		end, place = function(piece, anchor, form, x, n)
			if form == "crest" then ns.SlabMedals.Place(piece, anchor, 0, 100) else ns.SlabMedals.Place(piece, anchor, x, 0) end
			return n + 3
		end, known = function() return 10060 end },
		{ key = "crestChoice", seat = "left", choices = { { feed = "aura", spells = { 999 } }, { feed = "aura", spells = { 10060 }, color = "gilt" } } },
	}, { events = { "BAG_UPDATE_DELAYED" }, paint = function() painted = painted + 1 end, motion = function() moved = moved + 1 end })
	ns.SlabTrackers.Update()
	local shown = Pieces(ns)
	assert(shown[1] and shown[1].spec.feed == "fiveSecond", "a mana class gets the five-second ring first")
	assert(shown[2] and shown[3] and shown[3].custom and shown[4], "registered rows build, a custom builder among them")
	assert(ns.SlabTrackers.state.forms.crest.pieces["4:2"], "the first choice the priest knows takes the seat")
	assert(moved > 0, "the motion hook runs")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(painted > 0, "a class event reaches its paint hook")
	Clean(env, K, "register")
end

-- Learned while auras are secret: nothing until combat ends.
do
	local env, K, ns = New("ROGUE", { 5171 }, { secret = true })
	assert(next((Pieces(ns))) == nil and env._trackerEvents.PLAYER_REGEN_ENABLED, "nothing is built while auras are secret")
	env._aurasSecret = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(Pieces(ns)[1], "combat over: the medal is built")
	Clean(env, K, "secret")
end

-- While auras are secret the engine's aura buttons and everything made under them refuse addon calls
-- (DenyTaintedAccessWhenAurasAreSecret), so every choice is sized out of combat and all the crest changes in combat is
-- its own: a pull from rest opens the bursts and lights Remorseless fire, a spell change raises nothing (the owner's
-- SlabMedals.lua:58 SetSize on SPELLS_CHANGED), a sharpening stone empties the vial at once, the first Stealth shows
-- sized Ambush and Vanish medals, and a motion change the engine must take waits for the restriction to end.
do
	local env, K, ns = New("ROGUE", { 5171, 1943, 2842, 8676, 1856, 14144 }, { setup = function(e) e._items = { [16] = 2092 } end })
	local enchant = {}
	env.C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return enchant[slot] end }
	env.GetShapeshiftFormID = function() return env._form end
	env._usable[8676] = true
	local crest = ns.SlabTrackers.state.forms.crest
	local slice, vial, fire = Pieces(ns)[1], Pieces(ns)[3], crest.pieces["8:1"]
	assert(fire.fire:GetAlpha() == 0 and slice.lit.flareGate:GetAlpha() == 0, "at rest the fire and the bursts hold back")
	env._aurasSecret = true
	env.SetCombat(true)
	assert(fire.fire:GetAlpha() == 1 and fire.still:GetAlpha() == 0 and slice.lit.flareGate:GetAlpha() == 1 and vial.lit.flareGate:GetAlpha() == 1, "a pull with auras secret wakes the fire and opens every burst")
	env.FireEvent("SPELLS_CHANGED")
	enchant[16] = { enchantID = 40 }
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	assert(vial.lit.gate:GetAlpha() == 0, "a sharpening stone empties the vial in combat")
	enchant[16].enchantID = 323
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	assert(vial.lit.gate:GetAlpha() == 1, "a poison fills it again")
	env._form = 30
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env.FireEvent("SPELL_UPDATE_USABLE")
	local ambush, vanish = Pieces(ns)[1], Pieces(ns)[2]
	assert(ambush.spec.feed == "usable" and ambush.lit:IsShown() and vanish.spec.feed == "cooldown", "the first Stealth swaps both shoulders")
	for _, p in ipairs({ ambush, vanish }) do
		assert((p:GetWidth() or 0) > 0 and (p.lit.bar:GetWidth() or 0) > 0 and ((p.ghost or p.lit.glow):GetWidth() or 0) > 0, "and each is sized, its object too")
	end
	local mirror = Pieces(ns)[8].lit.awake.lit
	K.Options.Write("Medallions", "motion", "calm")
	assert(mirror.full == true, "the engine keeps its fire while auras are secret")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(mirror.full == "calm", "and takes the change once the restriction ends, still in combat: Calm keeps the flares and drops the fire")
	Clean(env, K, "auras secret")
end

-- Frames: a row beside the stance bar.
do
	local env, K, ns = New("WARRIOR", { 25289, 20662, 2687 }, { frames = true })
	env._game.forms[1] = { texture = 132349, isActive = true, spellID = 2457 }
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	env.RunTimers()
	env._resolveRects = true
	assert(ns.bars.stance.count == 1, "the stance bar shows its button")
	local shown, form = Pieces(ns, "row")
	assert(shown[1] and shown[2] and shown[3] and form.frame:IsShown(), "three medals in the row")
	assert(shown[3].fire == nil and shown[3].spec.look == "flame" and shown[3].lit.bar, "Enrage is a flame burning down there")
	local x1 = shown[1]:GetCenter()
	local x3 = shown[3]:GetCenter()
	assert(x1 < x3, "in the study's order, left to right")
	local _, bottom = shown[1]:GetCenter()
	local stance = ns.bars.stance.buttons[1]
	assert(select(2, shown[1]:GetRect()) * shown[1]:GetEffectiveScale() >= (select(2, stance:GetRect()) + stance:GetHeight()) * stance:GetEffectiveScale() - 0.01 and bottom, "the row stands above the stance bar")
	assert(not (ns.SlabTrackers.state.forms.crest and ns.SlabTrackers.state.forms.crest.frame:IsShown()), "no crest pieces under Frames")
	Clean(env, K, "frames")
end

do
	local env, K, ns = New("PALADIN", { 20154, 20271, 642, 10333, 24239, 10308 }, { frames = true })
	local form = ns.SlabTrackers.state.forms.row
	local _, relative, point = form.frame:GetPoint(1)
	assert(relative == ns.bars.stance.holder and point == "BOTTOMLEFT", "no stance buttons: the row starts where the stance bar does")
	local first
	for _, piece in pairs(form.pieces) do
		if piece.spec.key == "crestSeal" then first = piece end
	end
	K.Options.Write("ActionBars", "crestSeal", false)
	env.RunTimers()
	assert(not first:IsVisible(), "under Frames a switch reaches the row without the slab")
	K.Options.Write("ActionBars", "crestSeal", true)
	env.RunTimers()
	local lines = {}
	for _, piece in pairs(form.pieces) do
		if piece:IsVisible() and piece.spec.key ~= "crestKill" then
			local _, y = piece:GetCenter()
			lines[math.floor(y + 0.5)] = (lines[math.floor(y + 0.5)] or 0) + 1
		end
	end
	local n = 0
	for _, count in pairs(lines) do
		assert(count <= 5, "the row wraps at five medals a line")
		n = n + 1
	end
	assert(n == 3, "seven medals stand in two lines and the cooldown sigils on a line of their own")
	Clean(env, K, "frames paladin")
end

-- A shaman's Spirit Poles under Frames: the row stands above the poles, not on their spires.
do
	local env, K, ns = New("SHAMAN", { 10432 }, { frames = true, setup = function(e)
		e.C_ActionBar.GetMultiCastBarIndex = function() return 12 end
		e.GetMultiCastTotemSpells = function(slot) return slot == 1 and 3599 or nil end
		e.GetTotemInfo = function() return false, "", 0, 0, 0 end
		e.GetTotemDuration = function() return { start = 0, finish = 0 } end
		e._game.forms[1] = { texture = 136095, isActive = false, spellID = 2645 }
		e.CreateFrame("Frame", "MultiCastActionBarFrame", e.UIParent)
	end })
	ns.SlabTrackers.Register("SHAMAN", { { key = "crestCooldowns", seat = "cooldowns", color = "gilt", families = { { spells = { 10432 }, sigil = "Bolt" } } } })
	env.RunTimers()
	ns.SlabTrackers.Update()
	local _, relative, point = ns.SlabTrackers.state.forms.row.frame:GetPoint(1)
	assert(ns.Totems.state.shown and relative == ns.Totems.state.header and point == "TOPLEFT", "the row stands on the Spirit Poles' top edge")
	Clean(env, K, "shaman frames")
end

-- Under Frames every medal in the row is the row's size; seat sizes are the crest's alone.
do
	local env, K, ns = New("ROGUE", { 5171, 1943, 2842, 1766, 1329283 }, { frames = true })
	env._items = { [17] = 2092 }
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 17)
	local sizes = {}
	for _, piece in pairs(ns.SlabTrackers.state.forms.row.pieces) do
		if piece:IsVisible() then sizes[piece.units] = true end
	end
	assert(sizes[ns.SlabMedals.SIZE] and next(sizes, next(sizes)) == nil, "feet and vials stand at the row's one medal size")
	Clean(env, K, "row sizes")
end

-- A custom placer under Frames takes the cells it returns; the next medal lands on the grid after them.
do
	local env, K, ns = New("ROGUE", { 5171, 1943 }, { frames = true })
	K.Options.Write("ActionBars", "crestSwing", false)
	local n = #ns.SlabTrackers.CLASSES.ROGUE
	ns.SlabTrackers.Register("ROGUE", {
		{ key = "crestPoisons", seat = "left", feed = "aura", spells = { 5171 }, place = function(piece, anchor, _, x, cell)
			ns.SlabMedals.Place(piece, anchor, x, 0)
			return cell + 3
		end },
		{ key = "crestPoisons", seat = "right", feed = "aura", spells = { 1943 } },
	})
	ns.SlabTrackers.Update()
	local pieces = ns.SlabTrackers.state.forms.row.pieces
	local after = pieces[(n + 2) .. ":1"]
	local _, _, _, x, y = after:GetPoint(1)
	local cx, cy = ns.SlabMedals.Cell(5)
	assert(pieces[(n + 1) .. ":1"]:IsVisible() and math.abs(x - cx) < 1 and math.abs(y - cy) < 1 and cy > 0, "after a three-cell piece at cell 2 the next medal starts the second line")
	Clean(env, K, "custom cells")
end

-- Repaints go only to shown pieces of the kind an event concerns.
do
	local env, K, ns = New("WARRIOR", { 25289, 20662, 11585, 25288, 21553, 1672, 11578 })
	local seen = {}
	local refresh = ns.SlabMedals.Refresh
	ns.SlabMedals.Refresh = function(piece)
		seen[#seen + 1] = piece
		return refresh(piece)
	end
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(#seen == 1 and seen[1].spec.feed == "usable" and seen[1]:IsShown(), "SPELL_UPDATE_USABLE repaints the shown opening alone, not cooldowns or hidden stance choices")
	seen = {}
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	for _, piece in ipairs(seen) do assert(piece:IsShown(), "a hidden stance choice is not repainted") end
	assert(#seen >= 3, "SPELL_UPDATE_COOLDOWN repaints the shown cooldown and usable pieces")
	ns.SlabMedals.Refresh = refresh
	Clean(env, K, "routing")
end

-- The five-second rule: only in the forms a class names, and as a medal under Frames.
do
	local env, K, ns = New("DRUID", { 5185 })
	env.GetShapeshiftFormID = function() return env._form end
	ns.SlabTrackers.Register("DRUID", { { key = "crestCooldowns", seat = "cooldowns", color = "gilt", families = { { spells = { 22812 }, sigil = "Bark" } } } },
		{ fiveSecondForms = { 0, 31 } })
	ns.SlabTrackers.Update()
	assert(ns.SlabTrackers.state.forms.crest.pieces["1:1"]:IsVisible(), "caster form: the five-second ring shows")
	env._form = 1
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(not ns.SlabTrackers.state.forms.crest.pieces["1:1"]:IsVisible(), "cat form: it hides")
	Clean(env, K, "five-second forms")
end

do
	local env, K, ns = New("PALADIN", { 20154 }, { frames = true })
	local medal = ns.SlabTrackers.state.forms.row.pieces["1:1"]
	assert(medal and medal:IsVisible() and medal.timer and not medal.steel, "under Frames the five-second rule is a mana ring in the row, no icon")
	env.C_Spell.GetSpellPowerCost = function() return { { type = 0, cost = 50 } } end
	env.GetTime = function() return 100 end
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 20154)
	assert(AB.W.LastCall(medal.timer, "SetCooldown")[2] == 5, "and it runs on a mana spell")
	Clean(env, K, "five-second frames")
end

-- A switch turned off in combat hides everything at once and the engine stops feeding it when combat ends (review dd9bddac #2).
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20049 })
	local feed = ns.SlabJewels.state.feed
	Slots.Set(env, "player", { { id = 20050, count = 3 } })
	local function visible()
		local n = 0
		for _, slot in pairs(feed.container._slots) do n = n + (Slots.Engine(env, slot.frame.IsVisible, slot.frame) and 1 or 0) end
		return n
	end
	assert(visible() > 0, "Vengeance lights the jewels")
	env._aurasSecret = true
	K.Options.Write("ActionBars", "crestVengeance", false)
	env.RunTimers()
	assert(visible() == 0, "Vengeance jewels off in combat: no fed layer still shows")
	env._aurasSecret = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(not feed.container._enabled, "and once combat ends the engine stops feeding them")
	Clean(env, K, "jewels off in combat")
end

-- With auras secret, turning the jewels off and on shows the fed Vengeance gems again at once, still fed by the engine;
-- only their tint and geometry wait.
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20049 })
	local s = ns.SlabJewels.state
	Slots.Set(env, "player", { { id = 20050, count = 3 } })
	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestJewels", false)
	env.RunTimers()
	K.Options.Write("ActionBars", "crestJewels", true)
	env.RunTimers()
	assert(s.jewels[1].holder:IsShown() and s.count == 5 and s.jewels[3].gem._count == 3, "the Vengeance gems show again, three lit")
	Clean(env, K, "jewels back in combat")
end

do
	local env, K, ns = New("ROGUE", { 5171, 1943 })
	local target = Pieces(ns)[2].lit.container
	env._aurasSecret = true
	for _, row in ipairs(ns.SlabTrackers.CLASSES.ROGUE) do K.Options.Write("ActionBars", row.key, false) end
	env.RunTimers()
	env._aurasSecret = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	local count, update = 0, target.UpdateAllAuras
	target.UpdateAllAuras = function(self) count = count + 1 return update(self) end
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(not target._enabled and count == 0, "every switch off in combat: after combat no hidden container feeds or refreshes")
	Clean(env, K, "trackers off in combat")
end

-- A newly learned strike moves the hip's gem to its cooldown (review dd9bddac #4).
do
	local env, K, ns = New("WARRIOR", { 6673, 6343 })
	local hip = Pieces(ns)[6]
	assert(hip.spec.spell == 6343, "Thunder Clap first")
	env._known[1464] = true
	env.FireEvent("SPELLS_CHANGED")
	env.RunTimers()
	hip = Pieces(ns)[6]
	env._cooling[1464] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(hip.spec.spell == 1464 and AB.W.LastCall(hip.bar, "SetTimerDuration"), "learning Slam charges the gem over Slam's cooldown")
	Clean(env, K, "learn Slam")
end

-- isOnGCD is trusted only on SPELL_UPDATE_COOLDOWN: a strike usable during the global cooldown stays lit (review dd9bddac #5).
do
	local env, K, ns = New("WARRIOR", { 6673, 7384 })
	local opening = Pieces(ns)[2]
	env._usable[7384] = true
	local gcd = true
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = gcd } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(opening.lit:IsShown(), "on the global cooldown Overpower stays lit")
	gcd = nil
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(opening.lit:IsShown(), "a later usable event, where isOnGCD means nothing, keeps it lit")
	gcd = false
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not opening.lit:IsShown(), "a real cooldown darkens it")
	Clean(env, K, "gcd")
end

-- A free or secret-cost cast leaves the five-second rule alone, as the power bar's spark does (review dd9bddac #6).
do
	local env, K, ns = New("PALADIN", { 20154 })
	local plaque = ns.SlabTrackers.state.forms.crest.pieces["1:1"]
	local cost = 0
	env.C_Spell.GetSpellPowerCost = function() return { { type = 0, cost = cost } } end
	env.GetTime = function() return 100 end
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-free", 20154)
	assert(not AB.W.LastCall(plaque.timer, "SetCooldown"), "a free cast starts no five-second ring")
	cost = env.Secret(50)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-secret", 20154)
	assert(not AB.W.LastCall(plaque.timer, "SetCooldown"), "nor does a secret cost")
	cost = 50
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-paid", 20154)
	assert(AB.W.LastCall(plaque.timer, "SetCooldown"), "a paid cast does")
	Clean(env, K, "free cast")
end

-- A vial needs its weapon, and only a poison fills it: a sharpening stone or an oil leaves it empty (review dd9bddac #7).
do
	local env, K, ns = New("ROGUE", { 2842 })
	local enchant = {}
	env.C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return enchant[slot] end }
	assert(not Pieces(ns)[3], "no main-hand weapon: no main-hand vial")
	env._items = { [16] = 2092 }
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 16)
	local vial = Pieces(ns)[3]
	assert(vial, "a main-hand weapon brings its vial")
	enchant[16] = { enchantID = 40, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	assert(vial.lit:IsShown() and vial.lit.gate:GetAlpha() == 0, "a sharpening stone leaves the vial empty")
	enchant[16].enchantID = 323
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	assert(vial.lit.gate:GetAlpha() == 1, "a poison fills it")
	Clean(env, K, "vial identity")
end

-- Every piece has a switch of its own: one hip, foot or rim effect off leaves its partner (review dd9bddac #8).
do
	local env, K, ns = New("WARRIOR", { 6673, 21553, 12292, 1672, 11578 })
	local function seen(key)
		for _, p in pairs(Pieces(ns)) do
			if p.spec.key == key then return true end
		end
		return false
	end
	assert(seen("crestHipLeft") and seen("crestHipRight") and seen("crestFootLeft") and seen("crestFootRight"), "hips and feet show")
	for _, pair in ipairs({ { "crestHipLeft", "crestHipLeft", "crestHipRight" }, { "crestHipRight", "crestHipRight", "crestHipLeft" },
		{ "crestFootLeft", "crestFootLeft", "crestFootRight" }, { "crestFootRight", "crestFootRight", "crestFootLeft" } }) do
		K.Options.Write("ActionBars", pair[1], false)
		env.RunTimers()
		assert(not seen(pair[2]) and seen(pair[3]), pair[1] .. " off hides its own piece alone")
		K.Options.Write("ActionBars", pair[1], true)
		env.RunTimers()
	end
	Clean(env, K, "per piece warrior")
end

do
	local env, K, ns = New("ROGUE", { 5171, 14148, 1329328 })
	local function rims()
		local fire, ring = false, false
		for _, p in pairs(Pieces(ns)) do
			fire = fire or p.spec.ambient ~= nil
			ring = ring or p.spec.seat == "rim" and p.spec.ambient == nil
		end
		return fire, ring
	end
	local fire, ring = rims()
	assert(fire and ring, "the rogue's fire and Venom ring both show")
	K.Options.Write("ActionBars", "crestFire", false)
	env.RunTimers()
	fire, ring = rims()
	assert(not fire and ring, "the fire's switch leaves Venom's ring")
	Clean(env, K, "per piece rogue")
end

-- A usable-strike medal in the Frames row is the row's size too (review dd9bddac #9).
do
	local env, K, ns = New("ROGUE", { 5171, 1943, 14251, 1766 }, { frames = true })
	for _, piece in pairs(ns.SlabTrackers.state.form.pieces) do
		if piece:IsVisible() then assert(piece.units == ns.SlabMedals.SIZE, tostring(piece.spec.key) .. ": a " .. tostring(piece.units) .. "-unit medal in the row") end
	end
	Clean(env, K, "frames riposte")
end

-- Stacks show as pips along the hip's groove, under Frames too, never as a number (review dd9bddac #10).
for _, frames in ipairs({ false, true }) do
	local env, K, ns = New("WARRIOR", { 6673, 12292 }, { frames = frames })
	local hip = Pieces(ns, frames and "row")[7]
	assert(hip and not hip.lit.count and hip.spec.pips == 5, "Sweeping Strikes counts its five charges in pips")
	Slots.Set(env, "player", { { id = 12292, count = 3, start = 0, duration = 10 } })
	assert(hip.lit:IsShown(), "and its groove lights with them")
	Clean(env, K, "pips " .. tostring(frames))
end

do
	local env, K, ns = New("ROGUE", { 2842, 14177 })
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.seat == "footRight" and piece.spec.feed == "aura" and piece.spec.unit == "target" and piece.spec.spells[1] == 2818 then
			assert(not piece.lit.count and piece.spec.pips == 5, "the poison foot counts its stacks in pips")
		end
	end
	Clean(env, K, "foot pips")
end

-- A different aura in a shown medal flares again, as an Aspect-to-Aspect swap does (#778 3).
do
	local env, K, ns = New("WARRIOR", { 6673 })
	local lit = Pieces(ns)[1].lit
	local flare = lit.awake.lit.flare
	Slots.Set(env, "player", { { id = 6673, count = 0 } })
	assert(flare.play:IsPlaying(), "the first shout flares")
	flare.play:Stop()
	Slots.Set(env, "player", { { id = 5242, count = 0 } })
	assert(lit:IsShown() and flare.play:IsPlaying(), "another shout in the shown medal flares again")
	Clean(env, K, "assigned flare")
end

-- Calm crest at rest calms the trackers' bursts too, Lua's and the engine's (review dd9bddac #12, #778 4).
do
	local env, K, ns = New("WARRIOR", { 6673, 7384 })
	local shout, opening = Pieces(ns)[1], Pieces(ns)[2]
	local resting = true
	ns.Slab.Resting = function() return resting end
	ns.SlabMedals.Rest()
	opening.flare.play:Stop()
	ns.SlabMedals.Fire(opening)
	assert(not opening.flare.play:IsPlaying(), "at rest a strike becoming usable does not burst")
	assert(shout.lit.flareGate:GetAlpha() == 0, "and an aura's engine-played burst is held back")
	resting = false
	ns.SlabMedals.Rest()
	assert(shout.lit.flareGate:GetAlpha() == 1, "awake, bursts play again")
	Clean(env, K, "rest bursts")
end

-- A class with no rows does no tracker work; a stance swap reuses the prepared seats without asking the spellbook (review dd9bddac #13).
do
	local env, K, ns = New("DEATHKNIGHT", {})
	local reads = 0
	env.GetShapeshiftFormID = function() reads = reads + 1 end
	env.FireEvent("SPELLS_CHANGED")
	assert(reads == 0 and not ns.SlabTrackers.state.resting and ns.SlabTrackers.CLASSES.WARRIOR == nil, "a class with no rows reads no form, holds no rest watcher and loads no melee rows")
	Clean(env, K, "no rows")
end

do
	local env, K, ns = New("WARRIOR", { 6673, 20662, 25288, 11585, 23894, 21553, 11605, 11581, 1672, 6554, 11578, 20617, 355, 2687, 18499, 12317, 1719, 871, 12292, 2565 })
	local reads, known = 0, env.C_SpellBook.IsSpellKnown
	env.C_SpellBook.IsSpellKnown = function(...) reads = reads + 1 return known(...) end
	env._aurasSecret = true
	env.GetShapeshiftFormID = function() return 18 end
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env.C_SpellBook.IsSpellKnown = known
	assert(reads <= 8, "a stance swap reuses the prepared seats instead of asking the spellbook again, got " .. reads .. " reads")
	assert(ns.SlabTrackers.state.forms.crest.pieces["2:1"]:IsVisible(), "and shows Defensive Stance's opening")
	Clean(env, K, "stance swap")
end

-- A choice's active() decides only whether it shows: it is built when known, before it is needed (#778 5).
do
	local env, K, ns = New("PRIEST", { 10060, 586 })
	local out = false
	ns.SlabTrackers.Register("PRIEST", { { key = "crestCooldowns", seat = "left", feed = "cooldown", choices = {
		{ known = { 10060 }, active = function() return out end },
		{ known = { 586 } },
	} } })
	ns.SlabTrackers.Update()
	local pieces = ns.SlabTrackers.state.forms.crest.pieces
	local row = #ns.SlabTrackers.CLASSES.PRIEST
	assert(pieces[row .. ":1"] and not pieces[row .. ":1"]:IsVisible() and pieces[row .. ":2"]:IsVisible(), "an inactive choice is built and hidden; the next shows")
	out = true
	env._aurasSecret = true
	ns.SlabTrackers.Swap()
	assert(pieces[row .. ":1"]:IsVisible() and not pieces[row .. ":2"]:IsVisible(), "once active it shows, in combat, without a rebuild")
	env._aurasSecret = false
	Clean(env, K, "active choice")
end

-- Under Frames threat keeps its fill and its own art, and the five-second rule does not wear a potion's icon (review dd9bddac #14).
do
	local env, K, ns = New("WARRIOR", { 6673 }, { frames = true })
	local threat
	for _, piece in pairs(ns.SlabTrackers.state.form.pieces) do
		if piece:IsVisible() and piece.spec.key == "crestThreat" then threat = piece end
	end
	assert(threat and threat.bar and not threat.steel, "the Frames threat piece is a gem that fills with your threat, not a shout medal")
	Clean(env, K, "frames threat")
end

do
	local env, K, ns = New("PALADIN", { 20154 }, { frames = true })
	local medal = ns.SlabTrackers.state.form.pieces["1:1"]
	assert(medal.texture ~= 134762 and medal.texture ~= 134851, "the five-second medal wears mana regeneration's icon, not a potion's")
	Clean(env, K, "five-second icon")
end

-- In combat lockdown nothing new is built, even while auras read in the open; prepared seats still swap (review dd9bddac #15).
do
	local env, K, ns = New("ROGUE", { 5171 })
	env.SetCombat(true)
	local before = #env._slotContainers
	env._known[1943] = true
	env.FireEvent("SPELLS_CHANGED")
	assert(#env._slotContainers == before and not Pieces(ns)[2], "learning Rupture in combat builds nothing yet")
	env.SetCombat(false)
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(Pieces(ns)[2], "after combat Rupture's medal is built")
	Clean(env, K, "lockdown")
end

-- Under Frames a pet's cooldown family keeps a slot of its own in the cooldown medal (#778 2).
do
	local env, K, ns = New("HUNTER", { 3045 }, { frames = true })
	ns.SlabTrackers.Register("HUNTER", { { key = "crestCooldowns", seat = "cooldowns", color = "gilt",
		families = { { spells = { 3045 }, sigil = "Volley" }, { spells = { 19574 }, unit = "pet", sigil = "Paw" } } } })
	ns.SlabTrackers.Update()
	local medal
	for _, piece in pairs(ns.SlabTrackers.state.form.pieces) do
		if piece.spec.key == "crestCooldowns" then medal = piece end
	end
	local pet
	for _, lit in ipairs(medal and medal.lits or {}) do
		pet = pet or lit.container and lit.container._unit == "pet"
	end
	assert(pet, "Bestial Wrath's pet slot survives under Frames")
	Clean(env, K, "frames pet family")
end

-- Even pixels at four sizes, and at 1080 again after a manual UI scale for every prepared choice, the hidden Stealth ones too.
for _, size in ipairs(SIZES) do
	local env, K, ns = New("ROGUE", size[2] == 1080 and { 5171, 1943, 2842, 8676, 1856 } or { 5171, 1943, 2842 }, { size = size })
	local k = size[2] / 768
	for _, p in pairs(Pieces(ns)) do
		for _, part in ipairs(p.parts) do
			local w = (part:GetRight() - part:GetLeft()) * part:GetEffectiveScale() * k
			local n = math.floor(w + 0.5)
			assert(math.abs(w - n) < 1e-3 and n % 2 == 0, size[1] .. "x" .. size[2] .. ": even pixels, got " .. w)
		end
	end
	if size[2] == 1080 then
		K.Scale.SetAuto(false)
		K.Scale.SetUserScale(0.62)
		env.RunTimers()
		for key, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			for _, part in ipairs(p.parts) do
				local w = part:GetWidth() * part:GetEffectiveScale() * k
				local n = math.floor(w + 0.5)
				assert(math.abs(w - n) < 1e-3 and n % 2 == 0, size[1] .. "x" .. size[2] .. " at scale 0.62: " .. key .. " even pixels, got " .. w)
			end
		end
	end
	Clean(env, K, size[1] .. "x" .. size[2])
end

-- Every class's cooldown families wear a sigil that ships (the shared racials and potions are proved by the rogue's
-- seventeen above): a family with none would drop the whole cooldown row, which the build's pcall only logs.
for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN" }) do
	local env, K, ns = New(class, {})
	local families = 0
	for _, row in ipairs(ns.SlabTrackers.CLASSES[class]) do
		for _, choice in ipairs(row.choices or { row }) do
			for _, family in ipairs(choice.families or row.families or {}) do
				local name = family.sigil
				local path = name and K.Tokens.Texture("sigil" .. name):gsub("\\", "/"):gsub("^Interface/AddOns/KstyleUI/", "")
				local file = path and io.open(path, "rb")
				assert(file, class .. " family " .. tostring(family.spells[1]) .. " needs sigil = \"<Name>\" drawn by Tools/media/sigils.py and listed in Core/Tokens.lua")
				file:close()
				families = families + 1
			end
		end
	end
	assert(families > 0, class .. " registers cooldown families")
	Clean(env, K, class .. " sigils")
end

print("actionbars crest trackers ok")
