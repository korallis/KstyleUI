-- test-actionbars-crest-medals.lua: the crest's shared medals and sockets (SlabMedals.lua): Engine hands the engine every lit layer's flare, with or without a fire loop, each on a second slot under the piece's own gate, and changes nothing while auras are secret; a rim builds its fire only with an ambient flipbook and its ring only with a colour; a two-feed medal keeps one icon and ring per aura slot; target slots refresh on a new target through one registration; a cooldown socket refills over the cooldown and stands full when ready; a usable medal lights the first usable strike off cooldown and keeps its state on a secret answer.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local env, K, ns = AB.New({
	class = "WARRIOR",
	setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		e._slotGroups = true
		Slots.Install(e)
		e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
	end,
})
AB.Enable(env, K)
local Medals = ns.SlabMedals
local parent = env.CreateFrame("Frame", nil, env.UIParent)
local registered = {}
local register = K.Events.Register
K.Events.Register = function(owner, event, fn)
	if owner == "ActionBars.SlabMedals" then registered[#registered + 1] = event end
	return register(owner, event, fn)
end

local function Played(list, group)
	for _, g in ipairs(list) do
		if g == group then return true end
	end
	return false
end

local function Shown(button, group)
	return Played(button._shownAnimations, group)
end

local function Assigned(lit)
	local mirror = lit.flareGate.lit
	return Played(mirror._assignedAnimations, mirror.flare.play)
end

do
	local m = Medals.Medal(parent, { feed = "aura", unit = "player", filter = "HELPFUL", spells = { 6673 }, color = "gilt" }, 5)
	local socket = Medals.Socket(parent, { feed = "enchant", slot = "MainHand", color = "schoolNature" }, 5)
	local rim = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, ambient = "medAmbientWarrior", color = "jewelCombo" }, 5)
	env._aurasSecret = true
	assert(Medals.Engine({ m }, true, true) == false and not m.lit.fed, "nothing changes while auras are secret")
	env._aurasSecret = false
	assert(Medals.Engine({ m, socket, rim }, true, true), "Engine runs while auras are readable")
	assert(Assigned(m.lit), "a medal with no fire loop still gives the engine its flare, played on each new aura")
	assert(Assigned(socket.lit), "so does a socket")
	assert(Shown(rim.fire.lit, rim.fire.lit.loop) and Assigned(rim.lit), "a rim gives its fire and its flare")
	assert(rim.lit.awake == rim.fire and m.lit.flareGate:GetParent() == m and rim.still:GetParent() == rim, "flare and fire gates are the piece's own frames, above a second slot the engine drives")
	Slots.Set(env, "player", { { id = 6673, count = 0, icon = 132333, start = 0, duration = 120 } })
	assert(m.lit:IsShown() and m.lit.icon._state.Texture[1] == 132333, "the aura lights the medal with its own icon")
	assert(AB.W.LastCall(m.timer, "SetCooldownFromDurationObject"), "and drains the ring from its duration")
	Medals.Engine({ m, socket, rim }, true, false)
	assert(not Shown(rim.fire.lit, rim.fire.lit.loop), "below Full the engine plays no fire")
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	assert(socket.lit:IsShown() and AB.W.LastCall(socket.bar, "SetTimerDuration"), "an enchant fills the socket and drains it")
end

do
	local probe = Medals.Medal(parent, { feed = "aura", spells = { 6673 }, color = "gilt" }, 5)
	env._aurasSecret = true
	assert(not pcall(Slots.Engine, env, function() error("boom") end) and not pcall(probe.lit.icon.SetAlpha, probe.lit.icon, 1), "a failing engine call leaves the restriction in force")
	env._aurasSecret = false
end

do
	local plain = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, color = "jewelCombo" }, 5)
	assert(plain.fire == nil and plain.lit.loop == nil and plain.timer, "a rim with a colour and no flipbook is a ring alone")
	local moment = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, ambient = "medAmbientWarrior", burst = "medBurstWarrior" }, 5)
	assert(moment.fire and moment.fire.lit.loop and moment.timer == nil, "a rim with a flipbook and no colour has no ring")
	K.Store.Module("Medallions").restingCrest = true
	Medals.Rest()
	assert(moment.fire:GetAlpha() == 0 and moment.still:GetAlpha() == 1, "at rest the fire holds still")
end

do
	local two = Medals.Medal(parent, { feed = "aura", unit = "target", color = "gilt", feeds = {
		{ filter = "HARMFUL|PLAYER", spells = { 8921 } }, { filter = "HELPFUL|PLAYER", spells = { 774 } },
	} }, 5)
	assert(#two.lits == 2 and two.lits[1].icon ~= two.lits[2].icon and two.lits[1].timer ~= two.lits[2].timer, "two feeds, two icons and two rings")
	local again = Medals.Medal(parent, { feed = "aura", unit = "target", filter = "HARMFUL|PLAYER", spells = { 1943 }, color = "plateHostile" }, 5)
	local n = 0
	for _, event in ipairs(registered) do n = n + (event == "PLAYER_TARGET_CHANGED" and 1 or 0) end
	assert(n == 1, "one target registration for every target slot")
	Medals.Engine({ two, again }, true, true)
	local calls = 0
	again.lit.container.UpdateAllAuras = function() calls = calls + 1 end
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(calls == 1, "a new target refreshes an enabled target slot")
	Medals.Engine({ again }, false, true)
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(calls == 1, "a disabled one is left alone")
end

do
	local cooling = false
	env.C_Spell.GetSpellCooldown = function() return { isActive = cooling, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function(_, ignoreGCD)
		assert(ignoreGCD == true, "cooldowns ignore the global cooldown")
		return { start = 0, finish = 10 }
	end
	local socket = Medals.Socket(parent, { feed = "cooldown", spell = 20271, color = "jewelHoly" }, 5)
	Medals.Refresh(socket)
	assert(socket.bar:GetValue() == 1, "a ready cooldown socket stands full")
	cooling = true
	Medals.Refresh(socket, "SPELL_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(socket.bar, "SetTimerDuration"), "a cooling one refills over the cooldown")
	assert(socket.timer:GetScript("OnCooldownDone"), "and flares when it is ready")
end

do
	local usable, secret = { [5308] = false, [7384] = true }, false
	env.C_Spell.IsSpellUsable = function(id) return secret and env.Secret(true) or usable[id] end
	env.C_Spell.GetSpellCooldown = function() return { isActive = false } end
	env.C_Spell.GetSpellTexture = function(id) return id end
	local m = Medals.Medal(parent, { feed = "usable", candidates = { 5308, 7384 }, texture = 5308 }, 5)
	assert(not m.lit:IsShown(), "a usable medal starts steel")
	Medals.Refresh(m)
	assert(m.lit:IsShown() and m.lit.icon._state.Texture[1] == 7384, "the first usable strike lights it")
	usable[5308] = true
	Medals.Refresh(m)
	assert(m.lit.icon._state.Texture[1] == 5308, "a higher priority strike takes the medal")
	secret = true
	usable[5308], usable[7384] = false, false
	Medals.Refresh(m)
	assert(m.lit:IsShown(), "a secret answer keeps the last state")
end

do
	env._slotAuras.player = nil
	env._known = { [1719] = true, [871] = true, [12328] = true, [20230] = true, [20572] = true }
	env.C_SpellBook = { IsSpellKnown = function(id) return env._known[id] == true end }
	local families = { { spells = { 1719 }, sigil = "Crossed" }, { spells = { 871 }, sigil = "Wall" }, { spells = { 12328 }, sigil = "Skull" },
		{ spells = { 20230 }, sigil = "Thorns" }, { spells = { 20554 }, sigil = "Tusks" }, { spells = { 20572 }, sigil = "Axe" },
		{ spells = { 2379 }, known = {}, sigil = "Potion" } }
	local rim = Medals.CooldownRim(parent, { families = families, color = "gilt", burst = "medBurstWarrior" }, 5)
	Medals.Place(rim, parent, 0, 0)
	Medals.Engine({ rim }, true, true)
	local c, slots = rim.lit.container, 0
	for key in pairs(c._slots) do slots = slots + (key:find("^sigil") and 1 or 0) end
	assert(slots == #families and not c._order, "one aura button per family, never a group's batch of ten: " .. slots)
	local function Art(button)
		for _, region in ipairs(button._regions) do
			local t = region._state.Texture and region._state.Texture[1]
			if type(t) == "string" and t:find("Sigils", 1, true) then return t end
		end
	end
	-- The racial the character lacks draws its sigil once learned (test-actionbars-crest-auras owns that).
	for i, family in ipairs(families) do
		local b = rim.sigils[i]
		if family.known or env._known[family.spells[1]] then
			assert(Art(b):find(family.sigil .. ".png", 1, true) and not b._icon, family.sigil .. ": the family's own sigil, never the aura's icon")
		end
	end
	assert(c._slots.sigil5.disabled and not rim.sigils[5].at, "a racial the character does not have takes no place and reads no aura")
	local at = {}
	for i, b in ipairs(rim.sigils) do at[i] = b.at and b.at[1] .. "," .. b.at[2] end
	assert(at[1] == "-20,-36" and at[2] == "0,-36" and at[3] == "20,-36" and at[4] == "-20,-16" and at[6] == "0,-16" and at[7] == "20,-16",
		"three to a line below the centre, the next line above: " .. table.concat(at, " ", 1, 4))
	for i, b in ipairs(rim.sigils) do
		assert(not b.at or math.abs(b.at[1]) + b.units / 2 <= 28 and b.at[2] - b.units / 2 >= -44, i .. ": clear of the lower Inner Fire flames (x 32.5 and out) and the feet")
	end
	assert(not rim.sigils[1].loop and rim.sigils[1]._regions[1]._state.VertexColor[1] == 0, "a sigil keeps #809's dark shade: the healers' bloom and flash are theirs alone")
	Slots.Set(env, "player", { { id = 1719, count = 0, icon = 1, start = 0, duration = 15 }, { id = 871, count = 0, icon = 2, start = 0, duration = 10 } })
	assert(rim.lit:IsShown() and AB.W.LastCall(rim.timer, "SetCooldownFromDurationObject")[1].finish == 10, "the newest cooldown burns on the rim")
	assert(rim.sigils[1]:IsShown() and rim.sigils[2]:IsShown() and not rim.sigils[3]:IsShown(), "each running family lights its sigil")
	assert(AB.W.LastCall(rim.sigils[2].timer, "SetCooldownFromDurationObject")[1].finish == 10, "each sigil's ring drains with its own aura")
	Slots.Set(env, "player", { { id = 20554, count = 0, start = 0, duration = 10 } })
	assert(not rim.sigils[5]:IsShown(), "the disabled racial never lights")
	Slots.Set(env, "player", nil)
	assert(not rim.lit:IsShown() and not rim.sigils[1]:IsShown(), "none up: nothing shows")
	local shock = env.CreateFrame("Frame", nil, parent)
	shock:SetFrameLevel(5 + 16 + 1)
	assert(rim.sigils[1]:GetFrameLevel() > shock:GetFrameLevel(), "the row draws over a medal-level piece's sweep (the shaman's Shock covers the emblem there)")
end

-- Under Frames a hunter's sigils and the pet's share one strip, a line of their own: anchored to the piece, never to
-- an aura container (Forever forbids anchoring to one that has groups), ten to a line.
do
	env._known[3045], env._known[19574], env._known[19263] = true, true, true
	local families = { { spells = { 3045 }, sigil = "Volley" }, { spells = { 19263 }, sigil = "Deflect" }, { spells = { 20572 }, sigil = "Axe" },
		{ spells = { 2379 }, known = {}, sigil = "Potion" }, { spells = { 19574 }, unit = "pet", sigil = "Paw" } }
	local ok, rim = pcall(Medals.CooldownRim, parent, { families = families, color = "jewelHawk" }, 5, "row")
	assert(ok, "a hunter's cooldowns build under Frames: " .. tostring(rim))
	Medals.Place(rim, parent, 0, 0)
	Medals.Engine({ rim }, true, true)
	assert(#rim.lits == 2 and rim.lits[2].container._unit == "pet" and not rim.timer, "the pet's family has its own container, and the row has no rim")
	for i, b in ipairs(rim.sigils) do
		assert(b.at and b.at[1] == (b.units + 2) * (i - 1) and b.at[2] == 0, i .. ": its own place along the strip, the pet's after the player's four")
		local ring = false
		for _, region in ipairs(b._regions) do
			local t = region._state.Texture and region._state.Texture[1]
			ring = ring or type(t) == "string" and t:find("Ring", 1, true) ~= nil
		end
		assert(ring, i .. ": each sigil wears the medals' forged ring")
	end
	Slots.Set(env, "pet", { { id = 19574, count = 0, icon = 9, start = 0, duration = 18 } })
	Slots.Set(env, "player", { { id = 3045, count = 0, icon = 8, start = 0, duration = 15 } })
	assert(rim.sigils[5]:IsShown() and rim.sigils[1]:IsShown(), "the pet's Bestial Wrath and Rapid Fire light together")
	local calls = 0
	rim.lits[2].container.UpdateAllAuras = function() calls = calls + 1 end
	env.FireEvent("UNIT_PET", "player")
	assert(calls == 1, "a new pet refreshes the pet slot")
	Slots.Set(env, "pet", nil)
	Slots.Set(env, "player", nil)
end

do
	local rim = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, color = "jewelCombo" }, 5)
	local cooldowns = Medals.CooldownRim(parent, { families = { { spells = { 1719 }, sigil = "Crossed" } }, color = "gilt" }, 5)
	local emblem, band, outer = 53, 3.5, 75.6
	assert(rim.timer.units / 2 - band >= emblem - 1 and cooldowns.timer.units / 2 <= 60, "the rings run in the dark between the emblem and the rune band, clear of the emblem's edge")
	assert(AB.W.LastCall(rim.timer, "SetSwipeTexture")[1]:find("RingLine16", 1, true), "a thin ring band, not a wide arc")
	Medals.Place(cooldowns, parent, 0, 0)
	assert(cooldowns.sigils[1].units == 16, "a crest sigil is 16 units, 20 apart: a clear gap at every size")
	local foot = Medals.Medal(parent, { feed = "aura", spells = { 1 }, color = "gilt", size = Medals.FOOT }, 5)
	local timed = foot.timer.units
	for _, seat in ipairs({ "footLeft", "footRight" }) do
		local x, y = Medals.Seat(seat)
		local r = math.sqrt(x * x + y * y)
		assert(r - timed / 2 >= cooldowns.timer.units / 2 - 0.01 and r + timed / 2 <= outer + 1, seat .. ": a timed foot clears the cooldown band and stays at the rim")
	end
	assert(timed == Medals.FOOT + 2, "a foot's timer hugs the medal")
end

-- The shoulders sit where the study measured them (65 px out, 30 up at 1080, 0.943 px a unit) with a 28 px timed medal;
-- the reliquary (96 out, clear of the cast bar) and the rings (clear of the emblem) are deliberate revisions (review dd9bddac #11).
do
	local x, y = Medals.Seat("right")
	assert(math.abs(x * 0.943 - 65) <= 1 and math.abs(y * 0.943 - 30) <= 1, "the shoulders sit at the study's fit, below the slab's connectors")
	local timed = Medals.Medal(parent, { feed = "aura", spells = { 1 }, color = "gilt" }, 5)
	assert(math.abs(timed.timer.units * 0.943 - 28) <= 1.5, "a timed shoulder medal is 28 px across at 1080")
end

assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("actionbars crest medals ok")
