-- SlabStormforged.lua: the shaman's crest trackers beside the Spirit Poles and storm orbs, registered with SlabTrackers, each on its own switch: a rune stone set into the ring's lower left for the main hand's imbue and its lower right for the off hand's (only with an off-hand weapon), its rune lit in the imbue's element colour while the enchant's own frame shows, guttering through the last five minutes and dark under a pulsing gilt rim when there is none (an enchant medal under Frames, as the poison vials are); the shock cooldown, the shaman's interrupt, as a sweep that dims the class emblem until it is ready, then sparks, a cooldown medal under Frames; on the left foot perch your Flame Shock on an enemy, Stormstrike's debuff drawn over it, or Riptide on a friend; a small ankh on the right foot perch, gold while Reincarnation is ready and an Ankh is in the bags; and the major cooldowns burning on the rim. The weapon enchant's frame and the cooldown's duration object draw the timers; the enchant, the cooldown state and the item count are values the client never makes secret.
local _, ns = ...

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
local ELEMENTS = {}
for token, ids in pairs({
	totemEarth = { 29, 6, 1, 503, 1663, 683, 1664, 7568 },
	totemFire = { 5, 4, 3, 523, 1665, 1666, 7567 },
	totemWater = { 2, 12, 524, 1667, 1668, 7566 },
	totemAir = { 283, 284, 525, 1669, 7569 },
}) do
	for _, id in ipairs(ids) do ELEMENTS[id] = token end
end
local STONE, SETTING, RIM, CHARM, LAST, GLOW = 14, 18, 22, 12, 300, 0.55
local SLOTS = { MainHand = 16, OffHand = 17 }
local FLARE = { { 0, 1, 0.05 }, { 1, 0, 0.4 } }
local GUTTER = { { 1, 0.4, 0.07 }, { 0.4, 0.85, 0.06 }, { 0.85, 0.3, 0.08 }, { 0.3, 1, 0.1 } }
local PULSE = { { 0.25, 1, 0.6 }, { 1, 0.25, 0.6 } }

local stones, ankhs = {}, {}
local Stones

local function Piece(parent, level, units)
	local piece = CreateFrame("Frame", nil, parent)
	piece:SetFrameLevel(level)
	piece.units, piece.parts, piece.lits = units, {}, {}
	piece.add = function(part, size)
		part.units = size or part.units
		piece.parts[#piece.parts + 1] = part
		return part
	end
	piece.add(piece)
	return piece
end

local function Flare(piece, parent, level, token, size)
	local flare = Medals.Layer(parent, level)
	piece.add(Medals.Texture(flare, "ARTWORK", 0, token, "white", size, "ADD"))
	flare:SetAlpha(0)
	flare.play = Medals.Steps(flare, FLARE)
	parent.flare, piece.flare = flare, flare
end

local function Stone(parent, spec, level, form)
	if form == "row" then
		return Medals.Medal(parent, spec, level)
	end
	local s = Piece(parent, level, SETTING)
	s.slot = SLOTS[spec.slot]
	s.add(Medals.Texture(s, "BACKGROUND", 0, "glow", "black", SETTING * 1.6)):SetAlpha(0.6)
	s.add(Medals.Texture(s, "BORDER", 0, "ring", "gilt", SETTING))
	s.add(Medals.Texture(s, "ARTWORK", 0, "trackerStone", "white", STONE))
	local lit = Medals.Feed(s, spec, level + 1)
	s.lit, s.lits[1] = lit, lit
	s.light = Medals.Layer(lit, level + 1)
	s.glow = s.add(Medals.Texture(s.light, "ARTWORK", 0, "glow", "white", SETTING * 1.6, "ADD"))
	s.rune = s.add(Medals.Texture(s.light, "OVERLAY", 0, "trackerRune", "white", STONE, "ADD"))
	s.gutter = Medals.Steps(s.light, GUTTER, true)
	s.rim = Medals.Layer(s, level + 2)
	s.add(Medals.Texture(s.rim, "OVERLAY", 0, "ring", "gilt", RIM, "ADD"))
	s.pulse = Medals.Steps(s.rim, PULSE, true)
	Flare(s, lit, level + 3, spec.burst, SETTING * 3)
	stones[#stones + 1] = s
	Stones()
	return s
end

local function Shock(parent, spec, level, form)
	local hub = ns.Slab.hub
	if form == "row" then
		return Medals.Medal(parent, spec, level)
	end
	local s = Piece(parent, level, 2)
	s.timer = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
	s.timer:SetAllPoints(hub.crest)
	s.timer:SetSwipeTexture(hub.crestPath or (Tokens.Texture("dot")))
	s.timer:SetSwipeColor(0, 0, 0, 0.6)
	s.timer:SetDrawEdge(false)
	s.timer:SetDrawBling(false)
	s.timer:SetHideCountdownNumbers(true)
	s.timer:SetScript("OnCooldownDone", function() Medals.Fire(s) end)
	Flare(s, s, level + 1, spec.burst, ns.Slab.RING)
	s.flare:SetAllPoints(hub)
	return s
end

local function Ankh(parent, spec, level, form)
	local a
	if form == "row" then
		a = Medals.Medal(parent, spec, level)
		a.glyph, a.icon = a.lit.icon, true
	else
		a = Piece(parent, level, CHARM)
		a.glyph = a.add(Medals.Texture(a, "OVERLAY", 0, "trackerAnkh", "capsGold", CHARM))
	end
	ankhs[#ankhs + 1] = a
	return a
end

Stones = function()
	local info = C_PaperDollInfo
	local read = info and type(info.GetTemporaryEnchantmentInfo) == "function" and info.GetTemporaryEnchantmentInfo
	local now = type(GetTime) == "function" and GetTime()
	local moving = Effects.Allows("pulse") and not ns.Slab.Resting()
	for _, s in ipairs(stones) do
		local enchant = read and read(s.slot)
		local id, left = enchant and enchant.enchantID, enchant and enchant.remainingTimeMs
		if IsSecret(id) or IsSecret(left) then
			id, left = nil, nil
		end
		local r, g, b = Tokens.Color(ELEMENTS[id] or "gilt")
		s.rune:SetVertexColor(r, g, b)
		s.glow:SetVertexColor(r, g, b, GLOW)
		local missing = enchant == nil
		s.rim:SetShown(missing)
		if missing and moving then
			s.pulse:Play()
		else
			s.pulse:Stop()
		end
		local due = type(left) == "number" and now and now + left / 1000 - LAST
		s.gutter:Stop()
		if due and moving and due <= now then
			s.gutter:Play()
		elseif due and moving and s.due ~= due and C_Timer and C_Timer.After then
			s.due = due
			C_Timer.After(due - now, function()
				if s.due == due then
					s.due = nil
					Stones()
				end
			end)
		end
	end
end

local function Charm()
	local api, item = C_Spell, C_Item
	local cd = api and type(api.GetSpellCooldown) == "function" and api.GetSpellCooldown(REINCARNATION[1])
	local count = item and type(item.GetItemCount) == "function" and item.GetItemCount(ANKH)
	local ready = type(cd) == "table" and cd.isActive == false and not IsSecret(count) and type(count) == "number" and count > 0
	for _, a in ipairs(ankhs) do
		a.glyph:SetVertexColor(Tokens.Color(a.icon and "white" or ready and "capsGold" or "steel"))
		a.glyph:SetDesaturated(not ready)
		a.glyph:SetAlpha(ready and 1 or 0.55)
	end
end

local function OffHand(row)
	local info = C_PaperDollInfo
	local has = info and type(info.OffhandHasWeapon) == "function" and info.OffhandHasWeapon()
	return not IsSecret(has) and has == true and Medals.Known(row.spells) or nil
end

ns.SlabTrackers.Register("SHAMAN", {
	{ key = "crestImbues", seat = "lowerLeft", feed = "enchant", slot = "MainHand", spells = IMBUES, build = Stone },
	{ key = "crestImbues", seat = "lowerRight", feed = "enchant", slot = "OffHand", spells = IMBUES, known = OffHand, build = Stone },
	{ key = "crestShock", seat = { 0, 0 }, feed = "cooldown", known = SHOCKS, build = Shock },
	{ key = "crestAnkh", seat = "footRight", known = REINCARNATION, build = Ankh },
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
		if event == nil or event == "BAG_UPDATE_DELAYED" or event == "SPELL_UPDATE_COOLDOWN" then
			Charm()
		end
	end,
	motion = function() Stones() end,
})
