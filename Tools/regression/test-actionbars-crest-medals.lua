-- test-actionbars-crest-medals.lua: the crest's shared medals and sockets (SlabMedals.lua): Engine hands the engine every lit layer's flare, with or without a fire loop, and changes nothing while auras are secret; a rim builds its fire only with an ambient flipbook and its ring only with a colour; a two-feed medal keeps one icon and ring per aura slot; target slots refresh on a new target through one registration; a cooldown socket refills over the cooldown and stands full when ready; a usable medal lights the first usable strike off cooldown and keeps its state on a secret answer.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local env, K, ns = AB.New({
	class = "WARRIOR",
	setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		Slots.Install(e)
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

local function Shown(button, group)
	for _, g in ipairs(button._shownAnimations) do
		if g == group then return true end
	end
	return false
end

do
	local m = Medals.Medal(parent, { feed = "aura", unit = "player", filter = "HELPFUL", spells = { 6673 }, color = "gilt" }, 5)
	local socket = Medals.Socket(parent, { feed = "enchant", slot = "MainHand", color = "schoolNature" }, 5)
	local rim = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, ambient = "medAmbientWarrior", color = "jewelCombo" }, 5)
	env._aurasSecret = true
	assert(Medals.Engine({ m }, true, true) == false and not m.lit.fed, "nothing changes while auras are secret")
	env._aurasSecret = false
	assert(Medals.Engine({ m, socket, rim }, true, true), "Engine runs while auras are readable")
	assert(Shown(m.lit, m.lit.flare.play), "a medal with no fire loop still gives the engine its flare")
	assert(Shown(socket.lit, socket.lit.flare.play), "so does a socket")
	assert(Shown(rim.lit, rim.lit.loop) and Shown(rim.lit, rim.lit.flare.play), "a rim gives its fire and its flare")
	Slots.Set(env, "player", { { id = 6673, count = 0, icon = 132333, start = 0, duration = 120 } })
	assert(m.lit:IsShown() and m.lit.icon._state.Texture[1] == 132333, "the aura lights the medal with its own icon")
	assert(AB.W.LastCall(m.timer, "SetCooldownFromDurationObject"), "and drains the ring from its duration")
	Medals.Engine({ m, socket, rim }, true, false)
	assert(not Shown(m.lit, m.lit.flare.play) and not Shown(rim.lit, rim.lit.loop), "below Full the engine plays no flare or fire")
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	assert(socket.lit:IsShown() and AB.W.LastCall(socket.bar, "SetTimerDuration"), "an enchant fills the socket and drains it")
end

do
	local plain = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, color = "jewelCombo" }, 5)
	assert(plain.fire == nil and plain.lit.loop == nil and plain.timer, "a rim with a colour and no flipbook is a ring alone")
	local moment = Medals.Rim(parent, { feed = "aura", spells = { 2687 }, ambient = "medAmbientWarrior", burst = "medBurstWarrior" }, 5)
	assert(moment.fire and moment.lit.loop and moment.timer == nil, "a rim with a flipbook and no colour has no ring")
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
	Medals.Refresh(socket)
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
	local rim = Medals.CooldownRim(parent, { spells = { 1719, 871, 12328, 20230 }, color = "gilt", burst = "medBurstWarrior" }, 5)
	Medals.Engine({ rim }, true, true)
	assert(#rim.stack == 3, "three stack buttons made up front")
	Slots.Set(env, "player", { { id = 1719, count = 0, icon = 1, start = 0, duration = 15 }, { id = 871, count = 0, icon = 2, start = 0, duration = 10 } })
	assert(rim.lit:IsShown() and rim.lit:GetParent() and AB.W.LastCall(rim.timer, "SetCooldownFromDurationObject")[1].finish == 10, "the newest cooldown burns on the rim")
	assert(rim.stack[1]:IsShown() and rim.stack[1].icon._state.Texture[1] == 2 and rim.stack[2].icon._state.Texture[1] == 1 and not rim.stack[3]:IsShown(), "the stack shows each, newest first")
	Slots.Set(env, "player", { { id = 1719, count = 0, icon = 1, start = 0, duration = 15 }, { id = 871, count = 0, icon = 2, start = 0, duration = 10 }, { id = 12328, count = 0, icon = 3, start = 0, duration = 30 }, { id = 20230, count = 0, icon = 4, start = 0, duration = 15 } })
	assert(rim.stack[1].icon._state.Texture[1] == 4 and rim.stack[3]:IsShown(), "four up: the three newest show")
	Slots.Set(env, "player", nil)
	assert(not rim.lit:IsShown() and not rim.stack[1]:IsShown(), "none up: nothing shows")
end

assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("actionbars crest medals ok")
