-- SlabTrackers.lua: the melee classes' crest trackers, one table row per piece, each built from SlabMedals only for a warrior, paladin or rogue who knows its spell and has its switch on: a warrior's Battle Shout on the left shoulder, the opening (Execute, Overpower or Revenge, Victory Rush) on the right and Enrage burning round the inner rim; a paladin's Seal above the crest, Judgement's cooldown on the left shoulder and its Judgement on the target on the right; a rogue's Slice and Dice on the left shoulder, Rupture or Garrote on the target on the right and a poison vial per weapon on the lower ring. Under Frames the same pieces stand as medals in a row beside the stance bar. Calm crest at rest holds Enrage's fire still.
local _, ns = ...

local K = KstyleUI
local Widgets, Effects = K.Widgets, K.Effects
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Trackers = {}
ns.SlabTrackers = Trackers

local OWNER = "ActionBars.SlabTrackers"
local GAP, VIAL, RELIQUARY, OFF_HAND = 4, 20, 28, 17
local SHOUTS = { 25289, 11551, 11550, 11549, 6192, 5242, 6673, 403215 }
local EXECUTE, OVERPOWER = { 20662, 20661, 20660, 20658, 5308 }, { 11585, 11584, 7887, 7384 }
local REVENGE, VICTORY = { 25288, 11601, 11600, 7379, 6574, 6572 }, { 402927 }
local JUDGEMENT, POISONS = { 20271, 1310994 }, { 2842 }
local CLASSES = {
	WARRIOR = {
		{ key = "crestShout", seat = "left", feed = "aura", spells = SHOUTS, color = "gilt" },
		{ key = "crestOpening", seat = "right", feed = "usable", groups = { EXECUTE, OVERPOWER, REVENGE, VICTORY } },
		{ key = "crestEnrage", seat = "rim", feed = "aura", spells = { 12880, 14201, 14202, 14203, 14204, 29131, 18499 },
			known = { 2687, 18499, 12317, 13045, 13046, 13047, 13048 }, color = "jewelCombo", ambient = "medAmbientWarrior" },
	},
	PALADIN = {
		{ key = "crestSeal", seat = "top", feed = "aura", color = "jewelHoly", spells = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293,
			21084, 20375, 20915, 20918, 20919, 20920, 20162, 20305, 20306, 20307, 20308, 21082, 20165, 20347, 20348, 20349, 20166, 20356,
			20357, 20164, 20163, 1311656, 407798 } },
		{ key = "crestJudgement", seat = "left", feed = "cooldown", known = JUDGEMENT },
		{ key = "crestJudged", seat = "right", feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", known = JUDGEMENT, color = "jewelHoly",
			spells = { 20188, 20300, 20301, 20302, 20303, 21183, 20185, 20344, 20345, 20346, 20186, 20354, 20355, 20184 } },
	},
	ROGUE = {
		{ key = "crestSlice", seat = "left", feed = "aura", spells = { 6774, 5171, 400012 }, color = "pipPriestGlow" },
		{ key = "crestRupture", seat = "right", feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", color = "plateHostile",
			spells = { 11275, 11274, 11273, 8640, 8639, 1943, 11290, 11289, 8633, 8632, 8631, 703 } },
		{ key = "crestPoisons", seat = "lowerLeft", feed = "enchant", slot = "MainHand", known = POISONS, color = "schoolNature" },
		{ key = "crestPoisons", seat = "lowerRight", feed = "enchant", slot = "OffHand", known = POISONS, color = "schoolNature", offHand = true },
	},
}
local BURSTS = { WARRIOR = "medBurstWarrior", PALADIN = "medBurstPaladin", ROGUE = "medBurstRogue" }
Trackers.CLASSES = CLASSES

local state = { forms = {} }
Trackers.state = state

local function Texture(id)
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

local function Spec(p, row)
	local spec = setmetatable({ burst = BURSTS[ns.class] }, { __index = p })
	if p.groups then
		spec.candidates = {}
		for _, group in ipairs(p.groups) do
			spec.candidates[#spec.candidates + 1] = Medals.Known(group)
		end
		if #spec.candidates == 0 then
			return nil
		end
		spec.texture = Texture(spec.candidates[1])
		return spec
	end
	local id = Medals.Known(p.known or p.spells)
	if not id then
		return nil
	end
	spec.spell, spec.texture = id, Texture(id)
	if p.offHand then
		local item = GetInventoryItemID and GetInventoryItemID("player", OFF_HAND)
		if IsSecret(item) or not item then
			return nil
		end
	end
	spec.size = row and p.feed == "enchant" and VIAL or not row and p.seat == "top" and RELIQUARY or nil
	return spec
end

local function Build(form, name, i, spec)
	if form.failed[i] then
		return nil
	end
	local make = name == "crest" and (spec.seat == "rim" and Medals.Rim or spec.feed == "enchant" and Medals.Socket) or Medals.Medal
	local ok, piece = pcall(make, form.frame, spec, form.frame:GetFrameLevel() + 1)
	if not ok then
		form.failed[i] = true
		K.DevTest.Log("ActionBars", spec.key .. " on the crest unavailable: " .. tostring(piece))
		return nil
	end
	form.pieces[i] = piece
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
		local button = bar.buttons[1]
		local own = form.frame:GetParent():GetEffectiveScale()
		form.frame:SetScale(own > 0 and seat:GetEffectiveScale() / own * (button and button.opts.size or Medals.SIZE) / Medals.SIZE or 1)
		form.frame:SetFrameStrata(seat:GetFrameStrata())
		form.frame:ClearAllPoints()
		form.frame:SetPoint("LEFT", bar.count and bar.count > 0 and bar.buttons[bar.count] or seat, "RIGHT", GAP, 0)
		form.frame:SetSize(Medals.SIZE, Medals.SIZE)
	end
	form.frame:Show()
	return form
end

local function Lay(form, name, seat, shown)
	local x = 0
	for i, piece in pairs(form.pieces) do
		piece:SetShown(shown[i] ~= nil)
	end
	for i, piece in pairs(form.pieces) do
		if shown[i] and name == "crest" then
			if piece.spec.seat == "rim" then
				Medals.Place(piece, seat, 0, 0)
			else
				Medals.Place(piece, seat, Medals.Seat(piece.spec.seat))
			end
		end
	end
	for i = 1, #CLASSES[ns.class] do
		local piece = shown[i] and name == "row" and form.pieces[i]
		if piece then
			Medals.Place(piece, form.frame, x, 0)
			x = x + Medals.SIZE + GAP
		end
	end
end

local function Lists(form, shown)
	local on, off = {}, {}
	for i, piece in pairs(form.pieces) do
		local list = shown and shown[i] and on or off
		list[#list + 1] = piece
	end
	return on, off
end

local function Paint()
	local form = state.form
	for _, piece in ipairs(form and form.lua or {}) do
		Medals.Refresh(piece)
	end
end

local function Listen(on, lua, offHand)
	local key = tostring(on) .. tostring(lua) .. tostring(offHand)
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
	Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Trackers.Update)
	K.Callbacks.Register("EffectsLevelChanged", OWNER, Trackers.Update)
	if lua then
		for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED" }) do
			Events.Register(OWNER, event, Paint)
		end
	end
	if offHand then
		Events.Register(OWNER, "PLAYER_EQUIPMENT_CHANGED", Trackers.Update)
	end
end

local function Stop()
	for _, form in pairs(state.forms) do
		local _, off = Lists(form)
		Medals.Engine(off, false, false)
		form.frame:Hide()
	end
	state.form = nil
	Listen(false)
end

function Trackers.Update()
	local name, seat = Form()
	local specs, any, wantsOff = {}, false, false
	for i, p in ipairs(name and CLASSES[ns.class] or {}) do
		if ns.Config(p.key) ~= false then
			specs[i] = Spec(p, name == "row")
			any = any or specs[i] ~= nil
			wantsOff = wantsOff or p.offHand == true
		end
	end
	if not any then
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
	form.lua = {}
	local shown = {}
	for i, spec in pairs(specs) do
		local piece = form.pieces[i] or not restricted and Build(form, name, i, spec)
		if piece then
			shown[i] = piece
			if spec.feed == "cooldown" or spec.feed == "usable" then
				piece.spec = spec
				form.lua[#form.lua + 1] = piece
			end
		end
	end
	state.form = form
	Lay(form, name, seat, shown)
	local on, off = Lists(form, shown)
	local full = Effects.Allows("ambient")
	Medals.Engine(off, false, full)
	Medals.Engine(on, true, full)
	Medals.Rest()
	Paint()
	Listen(true, #form.lua > 0, wantsOff)
end

function Trackers.SetEnabled(on)
	state.enabled = on
	Trackers.Update()
end
