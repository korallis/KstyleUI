-- SlabTrackers.lua: the crest trackers' one lifecycle for every class (docs/medallions-effects.md#crest-trackers lists the API): a class registers its rows with Register, each row a piece built from SlabMedals (or its own builder) only while the class knows its spell and its switch is on, on the crest under Medallions and as a row of medals above the stance bar under Frames; the melee classes' rows live here: a warrior's Battle Shout, the opening and Enrage, a paladin's Seal, Judgement and its Judgement on the target, a rogue's Slice and Dice, Rupture and poison vials, and each class's major cooldowns burning round the rim.
local _, ns = ...

local K = KstyleUI
local Widgets, Effects = K.Widgets, K.Effects
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Trackers = {}
ns.SlabTrackers = Trackers

local OWNER = "ActionBars.SlabTrackers"
local GAP, VIAL, RELIQUARY, OFF_HAND = 4, 20, 28, 17
local LUA = { cooldown = true, usable = true }
local PAINT = { "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED" }
local CLASSES, HOOKS = {}, {}
Trackers.CLASSES = CLASSES

local state = { forms = {} }
Trackers.state = state

function Trackers.Register(class, rows, hooks)
	CLASSES[class] = CLASSES[class] or {}
	for _, row in ipairs(rows) do
		table.insert(CLASSES[class], row)
	end
	HOOKS[class] = hooks or HOOKS[class]
end

function Trackers.Has(key)
	for _, row in ipairs(CLASSES[ns.class] or {}) do
		if row.key == key then
			return true
		end
	end
	return false
end

function Trackers.Texture(id)
	local get = id and C_Spell and C_Spell.GetSpellTexture
	local texture = get and get(id)
	return not IsSecret(texture) and texture or nil
end

local function Form()
	if not (state.enabled and ns.running and CLASSES[ns.class]) then
		return nil
	end
	local hub = ns.Slab.hub
	if hub and hub:IsShown() then
		return "crest", hub
	end
	local stance = not ns.gamepad and K.HudStyle.Current() == "frames" and ns.bars.stance
	if stance and stance.holder then
		return "row", stance.holder
	end
end

local function Resolve(p, row)
	local spec = setmetatable({ burst = HOOKS[ns.class] and HOOKS[ns.class].burst }, { __index = p })
	if p.groups then
		spec.candidates = {}
		for _, group in ipairs(p.groups) do
			spec.candidates[#spec.candidates + 1] = Medals.Known(group)
		end
		spec.texture = Trackers.Texture(spec.candidates[1])
		return spec.candidates[1] and spec
	end
	local spells = p.known or p.spells
	if p.families then
		spells = {}
		for _, family in ipairs(p.families) do
			for _, id in ipairs(family.known or family.spells) do
				spells[#spells + 1] = id
			end
		end
	end
	local id
	if type(p.known) == "function" then
		id = p.known(p)
	else
		id = Medals.Known(spells)
	end
	if not id then
		return nil
	end
	spec.spell, spec.texture = id, p.texture or Trackers.Texture(id)
	spec.size = row and p.feed == "enchant" and VIAL or not row and p.seat == "top" and RELIQUARY or p.size
	if row and p.families then
		spec.feed, spec.newest, spec.spells = "aura", true, {}
		for _, family in ipairs(p.families) do
			for _, aura in ipairs(not family.unit and family.spells or {}) do
				spec.spells[#spec.spells + 1] = aura
			end
		end
	end
	return spec
end

local function Stance()
	local id = type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID()
	if IsSecret(id) then
		return state.stance
	end
	state.stance = id or 0
	return state.stance
end

local function InForm(choice, stance)
	for _, id in ipairs(choice.forms or { stance }) do
		if id == stance then
			return true
		end
	end
	return false
end

local function Build(form, name, key, spec)
	if form.failed[key] then
		return nil
	end
	local make = spec.build or name == "crest" and (spec.seat == "rim" and Medals.Rim or spec.seat == "cooldowns" and Medals.CooldownRim
		or spec.feed == "enchant" and Medals.Socket) or Medals.Medal
	local ok, piece = pcall(make, form.frame, spec, form.frame:GetFrameLevel() + 1, name)
	if not ok or not piece then
		form.failed[key] = true
		K.DevTest.Log("ActionBars", tostring(spec.key) .. " on the crest unavailable: " .. tostring(piece))
		return nil
	end
	piece.spec = piece.spec or spec
	form.pieces[key] = piece
	return piece
end

local function Shape(name, seat)
	local form = state.forms[name]
	if not form then
		form = { pieces = {}, failed = {}, frame = CreateFrame("Frame", nil, name == "crest" and seat.top or K.Scale.Root()) }
		state.forms[name] = form
	end
	if name == "crest" then
		form.frame:SetAllPoints(seat)
		form.frame:SetFrameLevel(seat.top:GetFrameLevel() + 1)
	else
		local bar = ns.bars.stance
		local first = bar.count and bar.count > 0 and bar.buttons[1]
		local own = form.frame:GetParent():GetEffectiveScale()
		form.frame:SetScale(own > 0 and seat:GetEffectiveScale() / own * (first and first.opts.size or Medals.SIZE) / Medals.SIZE or 1)
		form.frame:SetFrameStrata(seat:GetFrameStrata())
		form.frame:ClearAllPoints()
		form.frame:SetPoint("BOTTOMLEFT", first or seat, first and "TOPLEFT" or "BOTTOMLEFT", 0, first and GAP or 0)
		form.frame:SetSize(Medals.SIZE, Medals.SIZE)
	end
	form.frame:Show()
	return form
end

local function Lay(form, name, seat, shown, order, specs)
	for key, piece in pairs(form.pieces) do
		piece:SetShown(shown[key] ~= nil)
	end
	local x = 0
	for _, key in ipairs(order) do
		local piece, spec = shown[key], specs[key]
		if spec.place then
			x = spec.place(piece, name == "crest" and seat or form.frame, name, x) or x
		elseif name == "row" then
			Medals.Place(piece, form.frame, x, 0)
			x = x + Medals.SIZE + GAP
		elseif type(spec.seat) == "table" then
			Medals.Place(piece, seat, spec.seat[1], spec.seat[2])
		elseif spec.seat == "rim" or spec.seat == "cooldowns" then
			Medals.Place(piece, seat, 0, 0)
		else
			Medals.Place(piece, seat, Medals.Seat(spec.seat))
		end
	end
end

local function Lists(form, shown)
	local on, off = {}, {}
	for key, piece in pairs(form.pieces) do
		local list = shown and shown[key] and on or off
		list[#list + 1] = piece
	end
	return on, off
end

local function Paint(event, ...)
	local form = state.form
	for _, piece in ipairs(form and form.lua or {}) do
		Medals.Refresh(piece)
	end
	local hooks = form and HOOKS[ns.class]
	if hooks and hooks.paint then
		hooks.paint(form, event, ...)
	end
end

local function Motion()
	local hooks, form = HOOKS[ns.class], state.form
	if form and hooks and hooks.motion then
		hooks.motion(form, Effects.Allows("ambient"), not Effects.Allows("ambient") or ns.Slab.Resting())
	end
end

local function Listen(on, lua, forms)
	local key = tostring(on) .. tostring(lua) .. tostring(forms)
	if state.listening == key then
		return
	end
	state.listening = key
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	if not on then
		return
	end
	local hooks = HOOKS[ns.class] or {}
	Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Trackers.Update)
	K.Callbacks.Register("EffectsLevelChanged", OWNER, Trackers.Update)
	for _, event in ipairs(hooks.update or {}) do
		Events.Register(OWNER, event, Trackers.Update)
	end
	if forms then
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Trackers.Update)
	end
	local events = {}
	for _, event in ipairs(lua and PAINT or {}) do
		events[event] = false
	end
	for _, event in ipairs(hooks.events or {}) do
		if type(event) == "table" then
			events[event[1]] = event[2]
		else
			events[event] = events[event] or false
		end
	end
	for event, unit in pairs(events) do
		if unit then
			Events.RegisterUnit(OWNER, event, Paint, unit)
		else
			Events.Register(OWNER, event, Paint)
		end
	end
end

local function Stop()
	for _, form in pairs(state.forms) do
		Medals.Engine(select(2, Lists(form)), false, false)
		form.frame:Hide()
	end
	state.form = nil
	Listen(false)
end

function Trackers.Update()
	local name, seat = Form()
	local specs, order, active, forms = {}, {}, {}, false
	local stance = Stance()
	for i, p in ipairs(name and CLASSES[ns.class] or {}) do
		if ns.Config(p.key) ~= false then
			local chosen
			for c, choice in ipairs(p.choices or { p }) do
				local spec = Resolve(choice == p and p or setmetatable(choice, { __index = p }), name == "row")
				forms = forms or choice.forms ~= nil
				if spec then
					local key = i .. ":" .. c
					specs[key] = spec
					order[#order + 1] = key
					if not chosen and InForm(choice, stance) then
						chosen = key
						active[key] = true
					end
				end
			end
		end
	end
	if #order == 0 then
		return Stop()
	end
	local form = Shape(name, seat)
	for other, f in pairs(state.forms) do
		if other ~= name then
			Medals.Engine(select(2, Lists(f)), false, false)
			f.frame:Hide()
		end
	end
	local restricted = Medals.Restricted()
	local shown, kept, prepared = {}, {}, {}
	form.lua = {}
	for _, key in ipairs(order) do
		local spec = specs[key]
		local piece = form.pieces[key] or not restricted and Build(form, name, key, spec)
		if piece then
			prepared[key] = piece
			if active[key] then
				shown[key] = piece
				kept[#kept + 1] = key
			end
			if LUA[spec.feed] then
				piece.spec = spec
				form.lua[#form.lua + 1] = piece
			end
		end
	end
	state.form = form
	Lay(form, name, seat, shown, kept, specs)
	local on, off = Lists(form, prepared)
	local full = Effects.Allows("ambient")
	Medals.Engine(off, false, full)
	Medals.Engine(on, true, full)
	Medals.Rest()
	Motion()
	Paint()
	Listen(true, #form.lua > 0, forms)
end

function Trackers.SetEnabled(on)
	state.enabled = on
	if on and not state.resting then
		state.resting = true
		Medals.OnRest(Motion)
	end
	Trackers.Update()
end

local function OffHand(row)
	local item = GetInventoryItemID and GetInventoryItemID("player", OFF_HAND)
	return not IsSecret(item) and item and Medals.Known(row.spells)
end

local SHOUTS = { 25289, 11551, 11550, 11549, 6192, 5242, 6673, 403215 }
local EXECUTE, REVENGE, VICTORY = { 20662, 20661, 20660, 20658, 5308 }, { 25288, 11601, 11600, 7379, 6574, 6572 }, { 402927 }
local VANISH = { 1857, 1856 }
local JUDGEMENT, POISONS = { 20271, 1310994 }, { 2842 }

Trackers.Register("WARRIOR", {
	{ key = "crestShout", seat = "left", feed = "aura", spells = SHOUTS, color = "gilt" },
	{ key = "crestOpening", seat = "right", feed = "usable", choices = {
		{ forms = { 18 }, groups = { REVENGE, { 2565 }, { 23925, 23924, 23923, 23922 } } },
		{ forms = { 19 }, groups = { EXECUTE, { 23894, 23893, 23892, 23881 }, { 1680 }, VICTORY } },
		{ groups = { EXECUTE, { 11585, 11584, 7887, 7384 }, REVENGE, VICTORY } },
	} },
	{ key = "crestEnrage", seat = "rim", feed = "aura", spells = { 12880, 14201, 14202, 14203, 14204, 29131, 18499 },
		known = { 2687, 18499, 12317, 13045, 13046, 13047, 13048 }, color = "jewelCombo", ambient = "medAmbientWarrior" },
	{ key = "crestCooldowns", seat = "cooldowns", color = "gilt", families = { { spells = { 1719 } }, { spells = { 12328 } },
		{ spells = { 871 } }, { spells = { 12976 }, known = { 12975 } }, { spells = { 12292 } }, { spells = { 20230 } } } },
}, { burst = "medBurstWarrior" })

Trackers.Register("PALADIN", {
	{ key = "crestSeal", seat = "top", feed = "aura", color = "jewelHoly", spells = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293,
		21084, 20375, 20915, 20918, 20919, 20920, 20162, 20305, 20306, 20307, 20308, 21082, 20165, 20347, 20348, 20349, 20166, 20356,
		20357, 20164, 20163, 1311656, 407798 } },
	{ key = "crestJudgement", seat = "left", feed = "cooldown", known = JUDGEMENT },
	{ key = "crestJudged", seat = "right", feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", known = JUDGEMENT, color = "jewelHoly",
		spells = { 20188, 20300, 20301, 20302, 20303, 21183, 20185, 20344, 20345, 20346, 20186, 20354, 20355, 20184 } },
	{ key = "crestCooldowns", seat = "cooldowns", color = "jewelHoly", families = { { spells = { 407788 } }, { spells = { 642, 1020 } },
		{ spells = { 498, 5573 } }, { spells = { 20216 } }, { spells = { 20925, 20927, 20928, 1239570 } }, { spells = { 1022, 5599, 10278 } } } },
}, { burst = "medBurstPaladin" })

Trackers.Register("ROGUE", {
	{ key = "crestSlice", seat = "left", choices = {
		{ forms = { 30 }, feed = "usable", groups = { { 11269, 11268, 11267, 8725, 8724, 8676 }, { 1833 }, { 11290, 11289, 8633, 8632, 8631, 703 } } },
		{ feed = "aura", spells = { 6774, 5171, 400012 }, color = "pipPriestGlow" },
	} },
	{ key = "crestRupture", seat = "right", choices = {
		{ forms = { 30 }, feed = "cooldown", known = VANISH },
		{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "plateHostile",
			spells = { 11275, 11274, 11273, 8640, 8639, 1943, 11290, 11289, 8633, 8632, 8631, 703 } },
	} },
	{ key = "crestPoisons", seat = "lowerLeft", feed = "enchant", slot = "MainHand", known = POISONS, color = "schoolNature" },
	{ key = "crestPoisons", seat = "lowerRight", feed = "enchant", slot = "OffHand", known = OffHand, spells = POISONS, color = "schoolNature" },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipPriestGlow", families = { { spells = { 13877 } }, { spells = { 13750 } },
		{ spells = { 5277 } }, { spells = { 2983, 8696, 11305 } }, { spells = { 14177 } }, { spells = { 11327, 11329 }, known = { 1856, 1857 } },
		{ spells = { 14278 } } } },
}, { burst = "medBurstRogue", update = { "PLAYER_EQUIPMENT_CHANGED" } })
