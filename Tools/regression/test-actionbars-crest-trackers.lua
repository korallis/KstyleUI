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
			Slots.Install(e)
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
	for i, p in pairs(f and f.pieces or {}) do
		if p:IsVisible() then shown[i] = p end
	end
	return shown, f
end

local function Lit(p) return p.lit:IsShown() end

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

-- Other classes: nothing at all.
for _, class in ipairs({ "HUNTER", "MAGE", "SHAMAN", "PRIEST", "WARLOCK", "DRUID" }) do
	local env, K, ns = New(class, { 6673, 25289, 7384, 20271, 20154, 5171, 1943, 2842 })
	assert(next(ns.SlabTrackers.state.forms) == nil and next(env._trackerEvents) == nil, class .. ": no tracker frame or event")
	assert(ns.SlabJewels.state.feed == nil, class .. ": no aura-fed jewels")
	Clean(env, K, class)
end

-- A level 1 warrior: Battle Shout only.
do
	local env, K, ns = New("WARRIOR", { 6673 })
	local shown = Pieces(ns)
	assert(shown[1] and not shown[2] and not shown[3], "a fresh warrior has the shout medal and nothing else")
	local x, y = Seat(ns, shown[1])
	assert(x < -40 and y > 20, "the shout sits on the left shoulder")
	assert(not Lit(shown[1]), "no shout: steel")
	Slots.Set(env, "player", { { id = 6673, count = 0, icon = 132333, start = 0, duration = 120, mine = false } })
	assert(Lit(shown[1]), "anyone's Battle Shout lights the medal")
	assert(AB.W.LastCall(shown[1].timer, "SetCooldownFromDurationObject"), "and drains its ring")
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
	assert(Lit(shown[2]) and shown[2].lit.icon._state.Texture[1] == 100000 + 11585, "Overpower usable lights it with its icon")
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(shown[2].lit.icon._state.Texture[1] == 100000 + 20662, "Execute takes priority")
	env._cooling[20662] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(shown[2].lit.icon._state.Texture[1] == 100000 + 11585, "a strike on cooldown stays dark")
	local rim = shown[3]
	local rx, ry = Seat(ns, rim)
	assert(math.abs(rx) < 1 and math.abs(ry) < 1 and rim.fire, "Enrage burns round the crest's centre")
	Slots.Set(env, "player", { { id = 29131, count = 0, start = 0, duration = 10 } })
	assert(Lit(rim) and AB.W.LastCall(rim.timer, "SetCooldownFromDurationObject"), "Bloodrage lights the rim and drains it")
	K.Store.Module("Medallions").restingCrest = true
	ns.SlabMedals.Rest()
	assert(rim.fire:GetAlpha() == (ns.Slab.Resting() and 0 or 1), "the fire follows the crest's rest")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	for _, key in ipairs({ "crestShout", "crestOpening", "crestEnrage" }) do
		K.Options.Write("ActionBars", key, false)
	end
	env.RunTimers()
	assert(next((Pieces(ns))) == nil and next(env._trackerEvents) ~= nil, "every switch off hides every piece")
	assert(not ns.SlabTrackers.state.forms.crest.frame:IsShown() and ns.SlabTrackers.state.listening == "falsenilnil", "and stops listening")
	K.Options.Write("ActionBars", "crestOpening", true)
	env.RunTimers()
	local back = Pieces(ns)
	assert(back[2] and not back[1] and not back[3], "one switch brings back its own piece")
	Clean(env, K, "warrior")
end

-- A paladin: Seal, Judgement, the judged target and the jewels.
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20049 })
	local shown = Pieces(ns)
	assert(shown[1] and shown[2] and shown[3], "Seal, Judgement and the judged target")
	local _, sy = Seat(ns, shown[1])
	local jx = Seat(ns, shown[2])
	local tx = Seat(ns, shown[3])
	assert(sy > 80 and jx < -40 and tx > 40, "the Seal above, Judgement left, the target right")
	Slots.Set(env, "player", { { id = 20154, count = 0, icon = 135960, start = 0, duration = 30 } })
	assert(Lit(shown[1]) and shown[1].lit.icon._state.Texture[1] == 135960, "the Seal lights with its own icon")
	env._cooling[20271] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(shown[2].timer, "SetCooldownFromDurationObject"), "Judgement's cooldown sweeps")
	assert(shown[3].lit.container._unit == "target", "the judged medal watches the target")
	Slots.Set(env, "target", { { id = 20185, count = 0, harmful = true, mine = true, start = 0, duration = 10 } })
	assert(Lit(shown[3]), "your Judgement on the target lights it")
	Slots.Set(env, "target", { { id = 20185, count = 0, harmful = true, mine = false, start = 0, duration = 10 } })
	assert(not Lit(shown[3]), "another paladin's does not")
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
	assert(not Pieces(ns)[2], "no Judgement known: no Judgement medal")
	Clean(env, K, "paladin holy shield")
end

-- A rogue: Slice and Dice, Rupture and the vials.
do
	local env, K, ns = New("ROGUE", { 5171, 1943, 2842 })
	local shown = Pieces(ns)
	assert(shown[1] and shown[2] and shown[3] and not shown[4], "Slice and Dice, Rupture and the main-hand vial; no off hand, no second vial")
	local vx, vy = Seat(ns, shown[3])
	assert(vx < -30 and vy < -20, "the main-hand vial sits on the lower left of the ring")
	ns.SlabMedals.Engine({ shown[3] }, true, true)
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	assert(Lit(shown[3]) and AB.W.LastCall(shown[3].bar, "SetTimerDuration"), "a poison fills the vial and drains it")
	env._items = { [17] = 2092 }
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 17)
	assert(Pieces(ns)[4], "an off-hand item brings the second vial")
	Clean(env, K, "rogue")
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

-- Frames: a row beside the stance bar.
do
	local env, K, ns = New("WARRIOR", { 25289, 20662, 2687 }, { frames = true })
	env._game.forms[1] = { texture = 132349, isActive = true, spellID = 2457 }
	env.RunTimers()
	ns.SlabTrackers.Update()
	local shown, form = Pieces(ns, "row")
	assert(shown[1] and shown[2] and shown[3] and form.frame:IsShown(), "three medals in the row")
	assert(shown[3].fire == nil and shown[3].timer, "Enrage is a medal with a ring there")
	local x1 = shown[1]:GetCenter()
	local x3 = shown[3]:GetCenter()
	assert(x1 < x3, "in the study's order, left to right")
	assert(not (ns.SlabTrackers.state.forms.crest and ns.SlabTrackers.state.forms.crest.frame:IsShown()), "no crest pieces under Frames")
	Clean(env, K, "frames")
end

do
	local env, K, ns = New("PALADIN", { 20154, 20271 }, { frames = true })
	local form = ns.SlabTrackers.state.forms.row
	local _, relative, point = form.frame:GetPoint(1)
	assert(relative == ns.bars.stance.holder and point == "LEFT", "no stance buttons: the row starts where the stance bar does")
	Clean(env, K, "frames paladin")
end

-- Even pixels at four sizes.
for _, size in ipairs(SIZES) do
	local env, K, ns = New("ROGUE", { 5171, 1943, 2842 }, { size = size })
	local k = size[2] / 768
	for _, p in pairs(Pieces(ns)) do
		for _, part in ipairs(p.parts) do
			local w = (part:GetRight() - part:GetLeft()) * part:GetEffectiveScale() * k
			local n = math.floor(w + 0.5)
			assert(math.abs(w - n) < 1e-3 and n % 2 == 0, size[1] .. "x" .. size[2] .. ": even pixels, got " .. w)
		end
	end
	Clean(env, K, size[1] .. "x" .. size[2])
end

print("actionbars crest trackers ok")
