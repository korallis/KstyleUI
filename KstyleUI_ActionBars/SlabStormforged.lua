-- SlabStormforged.lua: the shaman's crest trackers beside the Spirit Poles and storm orbs, registered with SlabTrackers, each on its own switch: a rune stone set into the ring's lower left for the main hand's imbue and its lower right for the off hand's (only with an off-hand weapon), its rune lit in the imbue's element colour while the enchant's own frame shows, guttering through the last five minutes and dark under a pulsing gilt rim when there is none or another temporary enchant (under Frames a medal with the imbue's icon, colour and timer, guttering too); the shock cooldown, the shaman's interrupt, as a sweep that dims the class emblem until it is ready, then sparks, a cooldown medal under Frames; on the left foot perch your Flame Shock on an enemy, Stormstrike's debuff drawn over it, or Riptide on a friend; Reincarnation's cooldown medal on the right foot perch, greyed without an Ankh in the bags; and the major cooldowns burning on the rim. The weapon enchant's frame and the cooldown's duration object draw the timers; the enchant, the cooldown state and the item count are values the client never makes secret.
local _, ns = ...
if not (UnitClass and select(2, UnitClass("player")) == "SHAMAN") then
	return
end

local K = KstyleUI
local Widgets, Tokens, Effects, Medals = K.Widgets, K.Tokens, K.Effects, ns.SlabMedals
local IsSecret = Widgets.IsSecret

local IMBUES = {
	16316, 16315, 16314, 10399, 8019, 8018, 8017, 16342, 16341, 16339, 8030, 8027, 8024,
	16356, 16355, 10456, 8038, 8033, 16362, 10486, 8235, 8232,
}
local SHOCKS = { 10414, 10413, 10412, 8046, 8045, 8044, 8042, 29228, 10448, 10447, 8053, 8052, 8050, 10473, 10472, 8058, 8056 }
local REINCARNATION, ANKH = { 20608 }, 17030
local FLAME, STORMSTRIKE, RIPTIDE = { 29228, 10448, 10447, 8053, 8052, 8050 }, { 17364 }, { 1239243, 1239242, 408521 }
local ELEMENTS, ICONS = {}, { totemEarth = 8017, totemFire = 8024, totemWater = 8033, totemAir = 8232 }
for token, ids in pairs({
	totemEarth = { 29, 6, 1, 503, 1663, 683, 1664, 7568 },
	totemFire = { 5, 4, 3, 523, 1665, 1666, 7567 },
	totemWater = { 2, 12, 524, 1667, 1668, 7566 },
	totemAir = { 283, 284, 525, 1669, 7569 },
}) do
	for _, id in ipairs(ids) do ELEMENTS[id] = token end
end
local STONE, SETTING, RIM, LAST, GLOW = 14, 18, 22, 300, 0.55
local SLOTS = { MainHand = 16, OffHand = 17 }
local GUTTER = { { 1, 0.4, 0.07 }, { 0.4, 0.85, 0.06 }, { 0.85, 0.3, 0.08 }, { 0.3, 1, 0.1 } }
local PULSE = { { 0.25, 1, 0.6 }, { 1, 0.25, 0.6 } }

local stones, ankhs = {}, {}

local function Stone(parent, spec, level, form)
	local s
	if form == "row" then
		s = Medals.Medal(parent, setmetatable({ color = "gilt" }, { __index = spec }), level)
		s.light = s.lit.icon
	else
		s = Medals.Piece(parent, level, SETTING)
		s.add(Medals.Texture(s, "BACKGROUND", 0, "glow", "black", SETTING * 1.6)):SetAlpha(0.6)
		s.add(Medals.Texture(s, "BORDER", 0, "ring", "gilt", SETTING))
		s.add(Medals.Texture(s, "ARTWORK", 0, "trackerStone", "white", STONE))
		local lit = Medals.Feed(s, spec, level + 1)
		s.lit, s.lits[1] = lit, lit
		s.light = Medals.Layer(lit, level + 1)
		s.glow = s.add(Medals.Texture(s.light, "ARTWORK", 0, "glow", "white", SETTING * 1.6, "ADD"))
		s.rune = s.add(Medals.Texture(s.light, "OVERLAY", 0, "trackerRune", "white", STONE, "ADD"))
		s.rim = Medals.Layer(s, level + 2)
		s.add(Medals.Texture(s.rim, "OVERLAY", 0, "ring", "gilt", RIM, "ADD"))
		s.pulse = Medals.Steps(s.rim, PULSE, true)
		Medals.Flare(s, lit, level + 3, spec.burst, SETTING * 3)
	end
	s.slot = SLOTS[spec.slot]
	s.gutter = Medals.Steps(s.light, GUTTER, true)
	stones[#stones + 1] = s
	return s
end

local function Shock(parent, spec, level, form)
	local hub = ns.Slab.hub
	if form == "row" then
		return Medals.Medal(parent, spec, level)
	end
	local s = Medals.Piece(parent, level, 2)
	s.timer = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
	s.timer:SetAllPoints(hub.crest)
	s.timer:SetSwipeTexture(hub.crestPath or (Tokens.Texture("dot")))
	s.timer:SetSwipeColor(Widgets.Rgba("black", 0.6))
	s.timer:SetDrawEdge(false)
	s.timer:SetDrawBling(false)
	s.timer:SetHideCountdownNumbers(true)
	s.timer:SetScript("OnCooldownDone", function() Medals.Fire(s) end)
	Medals.Flare(s, s, level + 1, spec.burst, ns.Slab.RING)
	s.flare:SetAllPoints(hub)
	return s
end

local function Ankh(parent, spec, level)
	local a = Medals.Medal(parent, spec, level)
	a.glyph = a.lit.icon
	ankhs[#ankhs + 1] = a
	return a
end

local function Stones()
	if Medals.Restricted() then
		return
	end
	local info = C_PaperDollInfo
	local read = info and type(info.GetTemporaryEnchantmentInfo) == "function" and info.GetTemporaryEnchantmentInfo
	local now = type(GetTime) == "function" and GetTime()
	local pulse, calm = Effects.Allows("pulse"), ns.Slab.Resting()
	for _, s in ipairs(stones) do
		local moving = pulse and not (s.rune and calm)
		if s.wake then
			s.wake:Cancel()
			s.wake = nil
		end
		s.gutter:Stop()
		local shown = s:IsVisible()
		local enchant = shown and read and read(s.slot)
		local id, left = enchant and enchant.enchantID, enchant and enchant.remainingTimeMs
		if IsSecret(id) or IsSecret(left) then
			id, left = nil, nil
		end
		local element = ELEMENTS[id]
		local r, g, b = Tokens.Color(element or "gilt")
		s.light:SetAlpha(element and 1 or 0)
		if s.rune then
			s.rune:SetVertexColor(r, g, b)
			s.glow:SetVertexColor(r, g, b, GLOW)
			s.rim:SetShown(not element)
			if shown and not element and moving then
				s.pulse:Play()
			else
				s.pulse:Stop()
			end
		elseif element then
			s.light:SetTexture(ns.SlabTrackers.Texture(ICONS[element]) or s.spec.texture)
			s.lit.timer:SetSwipeColor(r, g, b)
		end
		local due = element and type(left) == "number" and now and now + left / 1000 - LAST
		if due and moving and due <= now then
			s.gutter:Play()
		elseif due and moving and C_Timer and C_Timer.NewTicker then
			s.wake = C_Timer.NewTicker(due - now, Stones, 1)
		end
	end
end

local function Charm()
	local item = C_Item
	local count = item and type(item.GetItemCount) == "function" and item.GetItemCount(ANKH)
	local stocked = not IsSecret(count) and type(count) == "number" and count > 0
	for _, a in ipairs(ankhs) do
		a.glyph:SetDesaturated(not stocked)
		a.glyph:SetAlpha(stocked and 1 or 0.55)
	end
end

local function OffHand()
	local info = C_PaperDollInfo
	local has = info and type(info.OffhandHasWeapon) == "function" and info.OffhandHasWeapon()
	return not IsSecret(has) and has == true
end

ns.SlabTrackers.Register("SHAMAN", {
	{ key = "crestImbues", seat = "lowerLeft", feed = "enchant", slot = "MainHand", spells = IMBUES, build = Stone },
	{ key = "crestImbues", seat = "lowerRight", feed = "enchant", slot = "OffHand", spells = IMBUES, active = OffHand, build = Stone },
	{ key = "crestShock", seat = { 0, 0 }, feed = "cooldown", known = SHOCKS, build = Shock },
	{ key = "crestAnkh", seat = "footRight", size = Medals.FOOT, feed = "cooldown", known = REINCARNATION, build = Ankh },
	{ key = "crestFlameShock", seat = "footLeft", size = Medals.FOOT, color = "white", spells = FLAME, known = function() return Medals.Known(FLAME) or Medals.Known(RIPTIDE) end,
		feeds = {
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = FLAME, color = "totemFire" },
			{ feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = STORMSTRIKE, color = "totemAir" },
			{ feed = "aura", unit = "target", filter = "HELPFUL|PLAYER", spells = RIPTIDE, color = "totemWater" },
		} },
	{ key = "crestCooldowns", seat = "cooldowns", color = "pipStormGlow", families = { { spells = { 16166 } }, { spells = { 16188 } }, { spells = { 425336 } } } },
}, {
	burst = "medBurstShaman",
	events = { "WEAPON_ENCHANT_CHANGED", "BAG_UPDATE_DELAYED" },
	update = { "PLAYER_EQUIPMENT_CHANGED" },
	paint = function(_, event)
		if event == nil or event == "WEAPON_ENCHANT_CHANGED" then
			Stones()
		end
		if event == nil or event == "BAG_UPDATE_DELAYED" then
			Charm()
		end
	end,
	motion = Stones,
})
