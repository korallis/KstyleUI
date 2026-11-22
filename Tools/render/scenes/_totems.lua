-- _totems.lua: under Medallions, RENDER_TOTEMS=story plays a shaman's Spirit Poles story through the action bars' own secure buttons and events, RENDER_TOTEMS_T seconds in (the end when unset): the four chosen totems at rest, Fire's fan unfolding and open, Magma Totem chosen and dropped, its spire burning down, Call of the Elements dropping all four and the ring breathing, Ghost Wolf, Magma's last fifth flickering, and expiry, each drop following the action its secure button took; RENDER_TOTEM_BAR=off turns the Shaman totem bar setting off first.
local Totems = {}

-- The shaman's known totems by totem slot (fire 1, earth 2, water 3, air 4), spell ID and icon file ID.
local KNOWN = {
	[1] = { { 3599, 135825, "Searing Totem" }, { 8190, 135826, "Magma Totem" }, { 8227, 136040, "Flametongue Totem" }, { 8181, 135866, "Frost Resistance Totem" }, { 8184, 135832, "Fire Resistance Totem" } },
	[2] = { { 8075, 136023, "Strength of Earth Totem" }, { 8071, 136098, "Stoneskin Totem" }, { 2484, 136102, "Earthbind Totem" }, { 5730, 136097, "Stoneclaw Totem" }, { 8143, 136108, "Tremor Totem" } },
	[3] = { { 5394, 135127, "Healing Stream Totem" }, { 5675, 136053, "Mana Spring Totem" }, { 8166, 136070, "Poison Cleansing Totem" }, { 8170, 136019, "Disease Cleansing Totem" } },
	[4] = { { 8512, 136114, "Windfury Totem" }, { 8835, 136046, "Grace of Air Totem" }, { 8177, 136039, "Grounding Totem" }, { 10595, 136061, "Nature Resistance Totem" }, { 15107, 136022, "Windwall Totem" } },
}
local CHOSEN = { [1] = 3599, [2] = 8075, [3] = 5394, [4] = 8512 }
local LIFE = { [1] = 20, [2] = 120, [3] = 60, [4] = 120 }
local CALL, RECALL, WOLF = { 66842, 310730, "Call of the Elements" }, { 36936, 310733, "Totemic Recall" }, { 2645, 136095, "Ghost Wolf" }
local BAR = 12

-- The story's beats, in seconds: Fire's fan opens, Magma Totem is chosen and dropped, Call drops all four, the
-- shaman takes Ghost Wolf, and Magma (20 s from Call) expires; the other three outlast the story.
Totems.FAN, Totems.PICK, Totems.DROP, Totems.CALL, Totems.WOLF, Totems.END = 0.5, 1.5, 2, 6, 9, 28

function Totems.Story()
	local story = os.getenv("RENDER_TOTEMS")
	if not story or story == "" then return nil end
	return story, tonumber(os.getenv("RENDER_TOTEMS_T") or "") or Totems.END
end

-- Install(env) gives the stub game a shaman's multi-cast bar, totem slots, Ghost Wolf and the spells' icons and names.
function Totems.Install(env)
	local g = env._game
	local totems, spells, icons, names = {}, {}, {}, {}
	env._totems = totems
	for slot, list in pairs(KNOWN) do
		spells[slot] = {}
		for i, s in ipairs(list) do
			spells[slot][i] = s[1]
			icons[s[1]], names[s[1]] = s[2], s[3]
		end
	end
	for _, s in ipairs({ CALL, RECALL, WOLF }) do icons[s[1]], names[s[1]] = s[2], s[3] end
	env.C_ActionBar.GetMultiCastBarIndex = function() return BAR end
	env.GetMultiCastTotemSpells = function(slot) return unpack(spells[slot] or {}) end
	env.GetTotemInfo = function(slot)
		local t = totems[slot]
		if not t then return false, "", 0, 0, 0 end
		return true, names[t.spell], t.start, t.life, icons[t.spell], 1, t.spell
	end
	env.GetTotemDuration = function(slot)
		local t = totems[slot]
		return { start = t and t.start or 0, finish = t and t.start + t.life or 0 }
	end
	env.SetMultiCastSpell = function(action, spell)
		g.slots[action] = spell ~= 0 and { texture = icons[spell], type = "spell", id = spell } or nil
	end
	local spell = env.C_Spell or {}
	env.C_Spell = spell
	local texture, name = spell.GetSpellTexture, spell.GetSpellName
	spell.GetSpellTexture = function(id) return icons[id] or texture and texture(id) end
	spell.GetSpellName = function(id) return names[id] or name and name(id) end
	env.C_SpellBook = env.C_SpellBook or {}
	env.C_SpellBook.IsSpellKnown = function(id) return id == CALL[1] or id == RECALL[1] end
	g.forms[1] = { texture = WOLF[2], isActive = false, spellID = WOLF[1] }
	for slot, id in pairs(CHOSEN) do
		g.slots[(BAR - 1) * 12 + slot] = { texture = icons[id], type = "spell", id = id }
	end
	env.CreateFrame("Frame", "MultiCastActionBarFrame", env.UIParent)
end

local function Drop(env, slot, spell, at, now)
	env._totems[slot] = { spell = spell, start = env._time - (now - at), life = LIFE[slot] }
	if now >= at + LIFE[slot] then env._totems[slot] = nil end
	env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
end

-- Sample(env, group, ago) has the scene draw an animation group as it stands ago seconds after it started.
local function Sample(env, group, ago)
	if group and group._playedAt then group._playedAt = env._time - ago end
end

-- Play(env, K, ns, AB, notes) runs the story to RENDER_TOTEMS_T through the bar's own buttons and events.
function Totems.Play(env, K, ns, AB, notes)
	local story, now = Totems.Story()
	if not ns.Totems then
		notes[#notes + 1] = "totems: this build has no totem bar"
		return
	end
	if os.getenv("RENDER_TOTEM_BAR") == "off" then
		K.Options.Write("ActionBars", "totemBar", false)
	end
	env.RunTimers()
	local state = ns.Totems.state
	if not state.shown then
		notes[#notes + 1] = "totems: the bar is off"
		return
	end
	local fire, earth = state.sockets[2], state.sockets[1]
	if now >= Totems.FAN then
		AB.Click(env, fire, "RightButton", false)
		for _, f in ipairs(fire.fan.buttons) do Sample(env, f.anim, now - Totems.FAN) end
		if now >= Totems.PICK then
			local magma
			for _, f in ipairs(fire.fan.buttons) do
				if f:GetAttribute("spell") == 8190 then magma = f end
			end
			AB.Click(env, magma, "LeftButton", false)
			env.FireEvent("ACTIONBAR_SLOT_CHANGED", fire.slot)
		end
	end
	local drops, chosen = {}, env._game.slots[fire.slot]
	if now >= Totems.DROP then
		AB.Click(env, fire, "LeftButton", false)
		if AB.Used(env) == fire.slot then drops[1] = { chosen.id, Totems.DROP } end
	end
	if now >= Totems.CALL then
		AB.Click(env, state.call, "LeftButton", false)
		if AB.Used(env) == "spell" .. CALL[1] then
			for slot = 1, 4 do drops[slot] = { slot == 1 and chosen.id or CHOSEN[slot], Totems.CALL } end
		end
	end
	for slot, d in pairs(drops) do
		Drop(env, slot, d[1], d[2], now)
		local s = state.sockets[slot == 1 and 2 or slot == 2 and 1 or slot].spire
		Sample(env, s.flare.anim, now - d[2])
		Sample(env, s.ignite, now - d[2])
		Sample(env, s.flicker and s.flicker.anim, now - d[2] - 0.8 * LIFE[slot])
	end
	-- The ring breathes back and forth; the scene folds the time since all four went up into one breath.
	local breath, t = ns.SlabEffects.CAP_BREATH, now - Totems.CALL
	t = t % (2 * breath)
	Sample(env, state.ring.breath, t <= breath and t or 2 * breath - t)
	if now >= Totems.WOLF then
		AB.Click(env, state.wolf, "LeftButton", false)
		env._game.forms[1].isActive = true
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	end
	notes[#notes + 1] = string.format("totems: %s, %.2f s in; fan %s; earth %s", story, now, fire.fan:IsShown() and "open" or "shut", earth:IsShown() and "shown" or "hidden")
end

return Totems
