-- SlabTrackers.lua: the crest trackers' one lifecycle for every class (docs/medallions-effects.md#crest-trackers lists the API): a class registers its rows with Register, each row a piece built from SlabMedals (or its own builder) only while the class knows its spell and its switch is on, on the crest under Medallions and as a row of medals above the stance bar under Frames; the melee classes' rows live here: a warrior's Battle Shout, the opening and Enrage, a paladin's Seal, Judgement and its Judgement on the target, a rogue's Slice and Dice, Rupture and poison vials, and each class's major cooldowns burning round the rim.
local _, ns = ...

local K = KstyleUI
local Widgets, Effects = K.Widgets, K.Effects
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Trackers = {}
ns.SlabTrackers = Trackers

local OWNER = "ActionBars.SlabTrackers"
local RELIQUARY, MAIN_HAND, OFF_HAND, TRINKET, ARMORY_TRINKET = 30, 16, 17, { 44, 0 }, { 33, -24 }
local LUA = {
	cooldown = { "SPELL_UPDATE_COOLDOWN" },
	usable = { "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED" },
	item = { "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" },
	threat = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED" },
	fiveSecond = { { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
	enchant = { { "UNIT_INVENTORY_CHANGED", "player" } },
}
local MANA = { PALADIN = true, PRIEST = true, DRUID = true, SHAMAN = true, MAGE = true, WARLOCK = true, HUNTER = true }
local ROUTE = {}
for kind, events in pairs(LUA) do
	ROUTE[kind] = {}
	for _, event in ipairs(events) do
		ROUTE[kind][type(event) == "table" and event[1] or event] = true
	end
end
local SHARED = {
	{ spells = { 20572 }, sigil = "Axe", major = true }, { spells = { 20554 }, sigil = "Tusks", major = true }, { spells = { 20594 }, sigil = "Stone", major = true },
	{ spells = { 20600 }, sigil = "Eye" }, { spells = { 7744 }, sigil = "Grave" }, { spells = { 1299026 }, sigil = "Shatter" },
	{ spells = { 1259799 }, sigil = "Star" }, { spells = { 1259812, 1259813, 1259817, 1259821, 1259823 }, sigil = "Gear" }, { spells = { 1260270 }, sigil = "Regen" },
	{ spells = { 17528, 6615, 3169, 17540, 2379, 11359, 16323 }, known = {}, sigil = "Potion" },
}
local CLASSES, HOOKS, JOINED = {}, {}, {}
local GATES = { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
Trackers.CLASSES = CLASSES

local state = { forms = {} }
Trackers.state = state

local function Always()
	return true
end

local function PlacePlaque(piece, anchor, form, _, n)
	if form == "row" then
		Medals.Place(piece, anchor, Medals.Cell(n))
		return n + 1
	end
	piece:ClearAllPoints()
	piece:SetPoint("CENTER", ns.Slab.hub.plaque, "CENTER", 0, 0)
	piece.units = ns.Slab.hub.plaque:GetWidth() + 4
	for _, part in ipairs(piece.parts) do
		part.units = piece.units
		Medals.Even(part)
	end
	return n
end

local function FiveSecondPiece(parent, spec, level, form)
	return (form == "crest" and Medals.Plaque or Medals.Medal)(parent, spec, level)
end

local function Trinket(p)
	local item = type(GetInventoryItemID) == "function" and GetInventoryItemID("player", p.slot)
	local get = C_Item and C_Item.GetItemSpell
	if IsSecret(item) or not item or type(get) ~= "function" then
		return nil
	end
	local _, spell = get(item)
	return not IsSecret(spell) and spell or nil
end

local function Trinkets(event, arg)
	if ns.Config("crestTrinkets") == false or IsSecret(arg) then
		return
	end
	for slot = 13, 14 do
		local id = event == "PLAYER_EQUIPMENT_CHANGED" and slot or type(GetInventoryItemID) == "function" and GetInventoryItemID("player", slot)
		if not IsSecret(id) and id == arg then
			return Trackers.Update()
		end
	end
end

function Trackers.Register(class, rows, hooks)
	if not CLASSES[class] and MANA[class] then
		CLASSES[class] = { { key = "crestFiveSecond", seat = "plaque", feed = "fiveSecond", known = Always, color = "hudMana", texture = 136053,
			build = hooks and (hooks.figures or hooks.armory) and Medals.Plaque or FiveSecondPiece, place = PlacePlaque, choices = { { forms = hooks and hooks.fiveSecondForms } } } }
	end
	CLASSES[class] = CLASSES[class] or {}
	local cooldowns
	for _, row in ipairs(rows) do
		table.insert(CLASSES[class], row)
		cooldowns = row.seat == "cooldowns" and row or cooldowns
	end
	HOOKS[class] = hooks or HOOKS[class]
	local at = hooks and (hooks.armory or hooks.lowTrinkets) and ARMORY_TRINKET or TRINKET
	for slot = 13, cooldowns and 14 or 0 do
		table.insert(CLASSES[class], { key = "crestTrinkets", seat = { slot == 13 and -at[1] or at[1], at[2] }, slot = slot, feed = "item", known = Trinket, color = cooldowns.color,
			build = hooks and (hooks.figures or hooks.armory) and Medals.Socket or nil })
	end
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
	local get = type(id) == "number" and C_Spell and C_Spell.GetSpellTexture
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
	if row and p.crestOnly then
		return nil
	end
	local spec = setmetatable({ burst = HOOKS[ns.class] and HOOKS[ns.class].burst }, { __index = p })
	spec.size = row and Medals.SIZE or p.seat == "top" and RELIQUARY or p.size
	if p.feeds and ns.SlabArmory.LOOKS[p.look or ""] then
		spec.feeds = {}
		for _, feed in ipairs(p.feeds) do
			local need = rawget(feed, "known") or rawget(feed, "spells")
			if not need or Medals.Known(need) then
				spec.feeds[#spec.feeds + 1] = feed
			end
		end
		spec.feeds[1] = spec.feeds[1] or p.feeds[1]
	end
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
		JOINED[p.families] = JOINED[p.families] or Trackers.Joined(p.families, SHARED)
		spec.families = JOINED[p.families]
		for _, family in ipairs(spec.families) do
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
	if not id then return nil end
	spec.spell, spec.texture = id, p.texture or Trackers.Texture(id)
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
	local make = spec.build or spec.feed == "threat" and Medals.Threat or spec.seat == "cooldowns" and Medals.CooldownRim
		or name == "crest" and (spec.seat == "rim" and Medals.Rim or spec.slot and not spec.perch and Medals.Socket) or spec.look and ns.SlabArmory.Build or Medals.Medal
	local under = spec.seat == "rim" or spec.seat == "cooldowns" or spec.seat == "plaque"
	local function Make()
		local ok, piece = pcall(make, form.frame, spec, form.frame:GetFrameLevel() + (under and 1 or 16), name)
		if not ok or not piece then
			K.DevTest.Log("ActionBars", tostring(spec.key) .. " on the crest unavailable: " .. tostring(piece))
			return nil
		end
		return piece
	end
	local piece = Make()
	if not piece then
		form.failed[key] = true
		return nil
	end
	piece.spec = piece.spec or spec
	if spec.families then
		ns.SlabUnleashed.Dress(piece, spec, name)
	elseif Medals.Cued(piece) then
		Medals.Twins(piece, Make)
	end
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
		local bar, totems = ns.bars.stance, ns.Totems.state
		local first = bar.count and bar.count > 0 and bar.buttons[1]
		local over = totems.shown and totems.header or seat:IsShown() and first
		local own = form.frame:GetParent():GetEffectiveScale()
		form.frame:SetScale(own > 0 and seat:GetEffectiveScale() / own * (first and first.opts.size or Medals.SIZE) / Medals.SIZE or 1)
		form.frame:SetFrameStrata(seat:GetFrameStrata())
		form.frame:ClearAllPoints()
		form.frame:SetPoint("BOTTOMLEFT", over or seat, over and "TOPLEFT" or "BOTTOMLEFT", 0, over and Medals.GAP or 0)
		form.frame:SetSize(Medals.SIZE, Medals.SIZE)
	end
	form.frame:Show()
	return form
end

local function Lay(form, name, seat, shown, order, specs)
	order, form.claims, form.refused = ns.SlabSeats.Claim(order, specs, name == "crest")
	for _, line in ipairs(form.refused) do
		K.DevTest.Log("ActionBars", line)
	end
	local kept = {}
	for _, key in ipairs(order) do
		kept[key] = shown[key]
	end
	shown = kept
	for key, piece in pairs(form.pieces) do
		piece:SetShown(shown[key] ~= nil)
		for _, twin in ipairs(piece.twins or {}) do
			twin:SetShown(shown[key] ~= nil)
		end
	end
	local n, strip, over = 0, nil, 0
	for _, key in ipairs(order) do
		local piece, spec = shown[key], specs[key]
		over = piece.spires and Medals.LINE or over
		if name == "row" and spec.seat == "cooldowns" then
			strip = piece
		elseif spec.place then
			n = spec.place(piece, name == "crest" and seat or form.frame, name, Medals.Cell(n), n) or n
		elseif name == "row" then
			Medals.Place(piece, form.frame, Medals.Cell(n))
			n = n + 1
		elseif type(spec.seat) == "table" then
			Medals.Place(piece, seat, spec.seat[1], spec.seat[2])
		elseif spec.seat == "rim" or spec.seat == "cooldowns" then
			Medals.Place(piece, seat, 0, 0)
		else
			Medals.Place(piece, seat, Medals.Seat(spec.seat))
		end
	end
	if strip then
		Medals.Place(strip, form.frame, Medals.Cell(math.ceil(n / Medals.LINE) * Medals.LINE + over))
	end
	ns.SlabTarget.Seat()
end

local function Lists(form, shown)
	local on, off = {}, {}
	for key, piece in pairs(form.pieces) do
		local list = shown and shown[key] and on or off
		list[#list + 1] = piece
	end
	return on, off
end

local function FiveSecond(form, unit, _, spell)
	if unit ~= "player" or IsSecret(spell) or not (C_Spell and C_Spell.GetSpellPowerCost) or type(GetTime) ~= "function" then
		return
	end
	for _, cost in ipairs(C_Spell.GetSpellPowerCost(spell) or {}) do
		if not (IsSecret(cost.type) or IsSecret(cost.cost)) and cost.type == 0 and type(cost.cost) == "number" and cost.cost > 0 then
			for _, piece in pairs(form.pieces) do
				if piece.spec.feed == "fiveSecond" and piece:IsShown() then
					piece.timer:SetCooldown(GetTime(), 5)
				end
			end
			return
		end
	end
end

local function Paint(event, ...)
	local form = state.form
	if form and event == "UNIT_SPELLCAST_SUCCEEDED" then
		FiveSecond(form, ...)
	end
	for _, piece in ipairs(form and form.lua or {}) do
		local kind = piece.spec.feed
		if kind ~= "fiveSecond" and piece:IsShown() and (not event or ROUTE[kind][event]) then
			Medals.Refresh(piece, event)
		end
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
	local key = tostring(on) .. table.concat(lua or {}, ",") .. tostring(forms)
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
	Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", Trackers.Update)
	K.Callbacks.Register("EffectsLevelChanged", OWNER, Trackers.Update)
	local updating = {}
	for _, event in ipairs(hooks.update or {}) do
		Events.Register(OWNER, event, Trackers.Update)
		updating[event] = true
	end
	if forms then
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Trackers.Swap)
	end
	local events = {}
	for _, kind in ipairs(lua or {}) do
		for _, event in ipairs(LUA[kind]) do
			if type(event) == "table" then
				events[event[1]] = event[2]
			else
				events[event] = events[event] or false
			end
		end
	end
	for _, event in ipairs(hooks.events or {}) do
		if type(event) == "table" then
			events[event[1]] = event[2]
		else
			events[event] = events[event] or false
		end
	end
	for event in pairs(updating) do
		events[event] = nil
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
	local done = true
	for _, form in pairs(state.forms) do
		done = Medals.Engine(select(2, Lists(form)), false, false) and done
		form.frame:Hide()
	end
	state.form = nil
	Listen(false)
	ns.SlabUnleashed.Paint()
	for _, event in ipairs(HOOKS[ns.class] and HOOKS[ns.class].update or {}) do
		if state.enabled then
			K.Events.Register(OWNER, event, Trackers.Update)
		else
			K.Events.Unregister(OWNER, event)
		end
	end
	local listen = done and K.Events.Unregister or K.Events.Register
	for _, event in ipairs(GATES) do
		listen(OWNER, event, Trackers.Update)
	end
end

local function Pick(row, pieces, stance)
	local first, want
	for _, entry in ipairs(row) do
		local key, choice = entry[1], entry[2]
		first = first or pieces[key] and key
		if not want and InForm(choice, stance) and (not choice.active or choice.active(choice)) then
			want = key
		end
	end
	return want and (pieces[want] and want or first)
end

function Trackers.Swap()
	local form, name, seat = state.form, Form()
	if not (form and name) then
		return
	end
	local stance, shown, kept = Stance(), {}, {}
	for _, row in ipairs(state.rows) do
		local key = Pick(row, form.pieces, stance)
		if key then
			shown[key] = form.pieces[key]
			kept[#kept + 1] = key
		end
	end
	Lay(form, name, seat, shown, kept, state.specs)
	Paint()
end

function Trackers.Update()
	local name, seat = Form()
	local specs, order, rows, forms = {}, {}, {}, false
	for i, p in ipairs(name and CLASSES[ns.class] or {}) do
		if ns.Config(p.key) ~= false then
			local row = {}
			for c, choice in ipairs(p.choices or { p }) do
				local spec = Resolve(choice == p and p or setmetatable(choice, { __index = p }), name == "row")
				if spec then
					forms = forms or choice.forms ~= nil
					local key = i .. ":" .. c .. (rawget(spec, "feeds") and "/" .. #spec.feeds or "")
					specs[key] = spec
					order[#order + 1] = key
					row[#row + 1] = { key, choice }
				end
			end
			rows[#rows + 1] = row
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
	local restricted = Medals.Locked()
	local prepared = {}
	form.lua = {}
	for _, key in ipairs(order) do
		local spec = specs[key]
		local piece = form.pieces[key] or not restricted and Build(form, name, key, spec)
		if piece then
			Medals.Retexture(piece, spec.texture)
			Medals.Size(piece)
			prepared[key] = piece
			if LUA[spec.feed] then
				piece.spec = spec
				form.lua[#form.lua + 1] = piece
			end
		end
	end
	state.form, state.rows, state.specs = form, rows, specs
	local stance, shown, kept = Stance(), {}, {}
	for _, row in ipairs(rows) do
		local key = Pick(row, prepared, stance)
		if key then
			shown[key] = prepared[key]
			kept[#kept + 1] = key
		end
	end
	Lay(form, name, seat, shown, kept, specs)
	local on, off = Lists(form, prepared)
	local full = Effects.Allows("ambient") or Effects.Allows("flare") and "calm"
	Medals.Engine(off, false, full)
	Medals.Engine(on, true, full)
	Medals.Rest()
	Motion()
	Paint()
	local kinds, seen = {}, {}
	for _, piece in ipairs(form.lua) do
		local kind = piece.spec.feed
		if not seen[kind] then
			seen[kind] = true
			kinds[#kinds + 1] = kind
		end
	end
	table.sort(kinds)
	Listen(true, kinds, forms)
end

local function OnSetting(_, module, key)
	if module == "ActionBars" and type(key) == "string" and key:find("^crest") then
		Trackers.Update()
	end
end

function Trackers.SetEnabled(on)
	state.enabled = on
	if on and CLASSES[ns.class] and not state.resting then
		state.resting = true
		Medals.OnRest(Motion)
	end
	if on and CLASSES[ns.class] then
		K.Callbacks.Register("SettingChanged", OWNER, OnSetting)
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
	end
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
		if on and Trackers.Has("crestTrinkets") then
			K.Events.Register(OWNER .. ".Trinkets", event, Trinkets)
		else
			K.Events.Unregister(OWNER .. ".Trinkets", event)
		end
	end
	Trackers.Update()
end

local function Weapon(row)
	local item = GetInventoryItemID and GetInventoryItemID("player", row.slot == "OffHand" and OFF_HAND or MAIN_HAND)
	return not IsSecret(item) and item and Medals.Known(row.spells)
end

local function Talent(talents, spells)
	return function()
		return Medals.Known(talents) and Medals.Known(spells)
	end
end

function Trackers.Joined(...)
	local list = {}
	for _, part in ipairs({ ... }) do
		for _, id in ipairs(part) do
			list[#list + 1] = id
		end
	end
	return list
end

local SHOUTS = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local EXECUTE, OVERPOWER = { 20662, 20661, 20660, 20658, 5308 }, { 11585, 11584, 7887, 7384 }
local REVENGE, VICTORY = { 25288, 11601, 11600, 7379, 6574, 6572 }, { 402927 }
local MORTAL, BLOODTHIRST, SLAM = { 21553, 21552, 21551, 12294 }, { 23894, 23893, 23892, 23881 }, { 11605, 11604, 8820, 1464, 1240193 }
local THUNDER = { 11581, 11580, 8205, 8204, 8198, 6343 }
local DEFENSIVE, BERSERKER = { 18 }, { 19 }
local EXECUTE_ART, REVENGE_ART, VICTORY_ART = { "axe", "plateHostile" }, { "sword", "pipStormGlow" }, { "sword", "schoolNature" }
local ARM_L, ARM_R, LL, LR, BL, BR, CENTRE = { -48, 6 }, { 48, 6 }, { -47, -36.5 }, { 47, -36.5 }, { -21.3, -58.9 }, { 21.3, -58.9 }, { 0, 0 }

local function Along(mid, n)
	local at, step = {}, 2 * math.asin((Medals.PIP + 2) / (2 * 63))
	for k = 1, n do
		local a = math.rad(mid) + (k - (n + 1) / 2) * step
		at[k] = { 63 * math.cos(a), 63 * math.sin(a) }
	end
	return at
end

local function Tank(spec)
	return { key = "crestTankGlow", seat = "rim", feed = "threat", crestOnly = true, build = Medals.Emblem, color = "gilt", choices = { spec } }
end

local CLASS = UnitClass and select(2, UnitClass("player"))

if CLASS == "WARRIOR" then
	Trackers.Register("WARRIOR", {
		{ key = "crestShout", seat = ARM_L, size = 42, feed = "aura", spells = SHOUTS, color = "gilt", look = "horn" },
		{ key = "crestOpening", seat = ARM_R, size = 42, feed = "usable", look = "sword", flash = "right", choices = {
			{ forms = DEFENSIVE, groups = { REVENGE, { 2565 }, { 23925, 23924, 23923, 23922 } }, arts = { REVENGE_ART, { "shield", "pipStormGlow" }, { "shield", "gilt" } } },
			{ forms = BERSERKER, groups = { EXECUTE, BLOODTHIRST, { 1680 }, VICTORY }, arts = { EXECUTE_ART, { "sword", "jewelCombo" }, { "axe", "pipWarriorGlow" }, VICTORY_ART } },
			{ groups = { EXECUTE, OVERPOWER, REVENGE, VICTORY }, arts = { EXECUTE_ART, { "sword", "gilt" }, REVENGE_ART, VICTORY_ART } },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "plateHostile", loop = "drip", spells = { 11574, 11573, 11572, 6548, 6547, 6546, 772 } },
		} },
		{ key = "crestEnrage", seat = "rim", feed = "aura", spells = { 12880, 29131, 18499 }, known = { 2687, 18499, 12317, 13045, 13046, 13047, 13048 },
			color = "pipWarriorGlow", ambient = "medAmbientWarrior", ring = ns.SlabArmory.ART .. "Cracks.png", ringSize = 150, look = "flame" },
		{ key = "crestCooldowns", seat = "cooldowns", color = "gilt", families = { { spells = { 1719 }, sigil = "Crossed", major = true }, { spells = { 12328 }, sigil = "Skull", major = true },
			{ spells = { 871 }, sigil = "Wall", major = true }, { spells = { 12976 }, known = { 12975 }, sigil = "Heart", major = true }, { spells = { 12292 }, sigil = "Sweep" },
			{ spells = { 20230 }, sigil = "Thorns", major = true } } },
		{ key = "crestThreat", seat = "topGem", feed = "threat", known = SHOUTS, choices = { { forms = DEFENSIVE, color = "gilt" }, { color = "plateHostile" } } },
		{ key = "crestHipLeft", seat = LL, size = 50, feed = "cooldown", look = "grooveLL", color = "pipWarriorGlow", choices = {
			{ forms = DEFENSIVE, feed = "aura", unit = "target", filter = "HARMFUL", spells = THUNDER, color = "pipStormGlow", loop = "crackle" },
			{ forms = BERSERKER, known = Trackers.Joined(BLOODTHIRST, { 1680 }, SLAM) },
			{ known = Trackers.Joined(MORTAL, SLAM, THUNDER) },
		} },
		{ key = "crestHipRight", seat = LR, size = 50, feed = "aura", look = "grooveLR", choices = {
			{ forms = DEFENSIVE, spells = { 2565 }, look = "ward", seat = CENTRE, size = 120, color = "pipStormGlow", pips = 2, pipsAt = { { -18, -36 }, { 18, -36 } } },
			{ spells = { 12966 }, known = { 12319, 12971, 12972, 12973, 12974 }, color = "pipWarriorGlow", pips = 3, pipsAt = Along(322, 3) },
			{ spells = { 12292 }, color = "gilt", pips = 5, pipsAt = Along(322, 5) },
			{ spells = { 1329555 }, color = "plateHostile", pips = 4, pipsAt = Along(322, 4) },
		} },
		{ key = "crestFootLeft", seat = BL, size = 27, feed = "cooldown", look = "grooveBL", color = "schoolFrost",
			choices = { { forms = BERSERKER, known = { 6554, 6552 } }, { known = { 1672, 1671, 72 } } } },
		{ key = "crestFootRight", seat = BR, size = 27, feed = "cooldown", look = "grooveBR", color = "gilt", choices = {
			{ forms = DEFENSIVE, known = { 355 }, feeds = { {}, { feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "plateHostile",
				spells = { 355, 694, 7400, 7402, 20559, 20560, 1161 } } } },
			{ forms = BERSERKER, known = { 20617, 20616, 20252 } },
			{ known = { 11578, 6178, 100 } },
		} },
		Tank({ forms = DEFENSIVE, known = SHOUTS }),
	}, { burst = "medBurstWarrior", armory = true })
end

local SEALS = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 21084, 20375, 20915, 20918, 20919, 20920, 20162, 20305, 20306,
	20307, 20308, 21082, 20165, 20347, 20348, 20349, 20166, 20356, 20357, 20164, 20163, 1311649, 20419, 20421, 20422, 20423, 1311656 }
local JUDGEMENT, HOLY_STRIKE = { 20271, 1310994 }, { 10333, 10332, 5569, 2495, 680, 1866, 678, 679 }
local PROT, HOLY = { 20925, 20177, 20179, 20180, 20181, 20182 }, { 20473, 20929, 20930, 1311606, 20216 }
local VENGEANCE = { 20049, 20056, 20057, 20058, 20059 }
local STONES = { 9421, 5510, 5509, 5511, 5512, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013, 12662, 20520, 11951 }
local MANA_POTIONS = { 13444, 13443, 6149, 3827, 3385, 2455 }
local SEAL_SCHOOLS = {
	{ color = "jewelHoly", spells = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 21084 } },
	{ color = "pipWarriorGlow", spells = { 20375, 20915, 20918, 20919, 20920 } }, { color = "white", spells = { 20162, 20305, 20306, 20307, 20308, 21082 } },
	{ color = "schoolNature", spells = { 20165, 20347, 20348, 20349 } }, { color = "schoolFrost", spells = { 20166, 20356, 20357 } },
	{ color = "schoolArcane", spells = { 20164 } }, { color = "plateHostile", spells = { 20163, 1311649, 20419, 20421, 20422, 20423, 1311656 } },
}
local JUDGED_SCHOOLS = {
	{ color = "white", spells = { 20188, 20300, 20301, 20302, 20303, 21183 }, known = SEAL_SCHOOLS[3].spells },
	{ color = "schoolNature", spells = { 20185, 20344, 20345, 20346 }, known = SEAL_SCHOOLS[4].spells },
	{ color = "schoolFrost", spells = { 20186, 20354, 20355 }, known = SEAL_SCHOOLS[5].spells }, { color = "schoolArcane", spells = { 20184 }, known = SEAL_SCHOOLS[6].spells },
	{ color = "plateHostile", spells = { 20232 }, known = SEAL_SCHOOLS[7].spells },
}

if CLASS == "PALADIN" then
	Trackers.Register("PALADIN", {
		{ key = "crestSeal", seat = { 0, 80 }, size = 24, feed = "aura", color = "jewelHoly", spells = SEALS, look = "seal", feeds = SEAL_SCHOOLS },
		{ key = "crestJudgement", seat = ARM_L, size = 36, feed = "cooldown", known = JUDGEMENT, look = "hammer", color = "jewelHoly", flash = "left" },
		{ key = "crestJudged", seat = ARM_R, size = 30, feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", known = JUDGEMENT,
			color = "jewelHoly", look = "brand", flash = "right", feeds = JUDGED_SCHOOLS },
		{ key = "crestCooldowns", seat = "cooldowns", color = "white", families = { { spells = { 642, 1020 }, sigil = "Bubble", major = true },
				{ spells = { 498, 5573 }, sigil = "Aegis", major = true }, { spells = { 20216 }, sigil = "Sun", major = true }, { spells = { 1022, 5599, 10278 }, sigil = "Hand", major = true },
				{ spells = { 1044 }, sigil = "Wing" }, { spells = { 1311015 }, sigil = "Bulwark", major = true }, { spells = { 1310897 }, sigil = "Voice", major = true } } },
		{ key = "crestHipLeft", seat = LL, size = 50, feed = "cooldown", look = "grooveLL", color = "schoolHoly", choices = {
			{ known = Talent(PROT, Trackers.Joined({ 407632 }, HOLY_STRIKE)) },
			{ known = Talent(HOLY, Trackers.Joined({ 20930, 20929, 20473, 1311606, 20216 }, HOLY_STRIKE)) },
			{ known = HOLY_STRIKE },
		} },
		{ key = "crestHipRight", seat = LR, size = 50, choices = {
			{ known = Talent(PROT, { 25780 }), feed = "aura", spells = { 25780 }, color = "gilt", look = "flames" },
			{ known = Talent(HOLY, { 1328548, 1310911, 1311590, 1311595 }), feed = "aura", filter = "HELPFUL|PLAYER", color = "jewelHoly", look = "oath",
				seat = CENTRE, size = 120, feeds = { { unit = "focus", spells = { 1328548 } }, { unit = "target", spells = { 1328548, 1310909 }, color = "white", look = "oathInner" } } },
			{ feed = "usable", groups = { { 24239, 24274, 24275 } }, look = "grooveLR", color = "plateHostile" },
			{ feed = "cooldown", known = { 10314, 10313, 10312, 5615, 5614, 879 }, look = "grooveLR", color = "schoolHoly" },
		} },
		{ key = "crestFootLeft", seat = BL, size = 27, choices = {
			{ known = Talent(HOLY, JUDGEMENT), feed = "item", items = STONES, look = "vial", size = 16, color = "schoolNature" },
			{ feed = "cooldown", known = { 10308, 5589, 5588, 853 }, look = "grooveBL", color = "jewelHoly" },
		} },
		{ key = "crestFootRight", seat = "footRight", size = Medals.FOOT, choices = {
			{ known = Talent(HOLY, JUDGEMENT), feed = "item", items = MANA_POTIONS, look = "vial", seat = BR, size = 16, color = "schoolFrost" },
			{ known = Talent(PROT, JUDGEMENT), feed = "threat", size = Medals.SETTING, color = "gilt" },
			{ known = JUDGEMENT, feed = "threat", size = Medals.SETTING, color = "plateHostile" },
		} },
		{ key = "crestRing", seat = "rim", choices = {
			{ known = PROT, feed = "aura", spells = { 20925, 20927, 20928, 1239570 }, color = "gilt", look = "ward", seat = CENTRE, size = 120, pips = 4,
				pipsAt = { { -42, 22 }, { -14, 46 }, { 14, 46 }, { 42, 22 } } },
			{ known = VENGEANCE, feed = "aura", spells = { 20050 }, color = "jewelHoly", ambient = "medAmbientPaladin", look = "flame" },
		} },
		Tank({ known = Talent(PROT, JUDGEMENT) }),
	}, { burst = "medBurstPaladin", armory = true })
end

local VANISH, POISONS = { 1857, 1856 }, { 2842 }
local NOT_POISON = {}
for _, id in ipairs({ 13, 14, 19, 20, 21, 25, 26, 40, 483, 484, 1643, 1703, 2506, 2623, 2624, 2625, 2626, 2627, 2628, 2629, 2684, 2685, 7098, 7327, 7896 }) do
	NOT_POISON[id] = true
end
local POISON_STACKS = { 2818, 2819, 11353, 11354, 25349, 434312, 434313, 434314, 434315, 434316, 458820, 462286, 1214170 }

if CLASS == "ROGUE" then
	Trackers.Register("ROGUE", {
		{ key = "crestSlice", seat = "rim", look = "dagger", choices = {
			{ forms = { 30 }, feed = "usable", seat = ARM_L, size = 42, veil = "schoolShadow", groups = { { 11269, 11268, 11267, 8725, 8724, 8676 }, { 1833 },
				{ 11290, 11289, 8633, 8632, 8631, 703 } }, arts = { { "dagger", "gilt" }, { "hammer", "schoolFrost" }, { "drop", "plateHostile" } } },
			{ feed = "aura", spells = { 6774, 5171 }, color = "pipPriestGlow", ring = ns.SlabArmory.ART .. "Fuse.png", spark = ns.SlabArmory.ART .. "Spark.png", ringSize = 150 },
		} },
		{ key = "crestRupture", seat = { 44.3, 0 }, size = 92, look = "stain", choices = {
			{ forms = { 30 }, feed = "cooldown", known = VANISH, color = "schoolShadow" },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "plateHostile",
				spells = { 11275, 11274, 11273, 8640, 8639, 1943, 11290, 11289, 8633, 8632, 8631, 703 } },
		} },
		{ key = "crestPoisons", seat = { -47, -32 }, size = 23, perch = true, feed = "enchant", slot = "MainHand", known = Weapon, spells = POISONS, reject = NOT_POISON,
			color = "schoolNature", look = "vial" },
		{ key = "crestPoisons", seat = { 47, -32 }, size = 23, perch = true, feed = "enchant", slot = "OffHand", known = Weapon, spells = POISONS, reject = NOT_POISON,
			color = "schoolNature", look = "vial" },
		{ key = "crestCooldowns", seat = "cooldowns", color = "pipPriestGlow", families = { { spells = { 13877 }, sigil = "Flurry", major = true },
				{ spells = { 13750 }, sigil = "Rush", major = true }, { spells = { 5277 }, sigil = "Evade", major = true }, { spells = { 2983, 8696, 11305 }, sigil = "Dash" },
				{ spells = { 14177 }, sigil = "Drop", major = true }, { spells = { 11327, 11329 }, known = VANISH, sigil = "Smoke", major = true }, { spells = { 14278 }, sigil = "Ghost" } } },
		{ key = "crestFootLeft", seat = BL, size = 27, feed = "cooldown", known = { 1769, 1768, 1767, 1766, 11286, 11285, 8629, 1777, 1776 },
			look = "grooveBL", color = "schoolFrost" },
		{ key = "crestFootRight", seat = BR, size = 27, look = "grooveBR", choices = {
			{ known = Talent({ 16513, 14113, 14186, 14177 }, POISONS), feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = POISON_STACKS,
				color = "schoolNature", pips = 5, pipsAt = Along(289.5, 5) },
			{ feed = "usable", groups = { { 14251 } }, color = "white" },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 16511 }, color = "plateHostile", look = "drop", size = 16 },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 1316709, 1325756, 1325757, 1325758 }, color = "plateHostile", look = "brand", size = 16 },
			{ feed = "cooldown", known = { 1329549, 1329283 }, color = "gilt" },
		} },
		{ key = "crestFire", seat = "rim", feed = "aura", spells = { 14143, 1329326, 1328826 }, known = { 14144, 14148, 14278, 1328825 },
			ambient = "medAmbientRogue", look = "flame", tint = "pipPriestGlow" },
		{ key = "crestRing", seat = "rim", feed = "aura", spells = { 1310703 }, known = { 1329328 }, color = "jewelCombo", look = "vial" },
	}, { burst = "medBurstRogue", update = { "PLAYER_EQUIPMENT_CHANGED" }, armory = true })
end
