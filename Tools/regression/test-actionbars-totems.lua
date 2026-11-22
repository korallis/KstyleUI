-- test-actionbars-totems.lua: the shaman's Spirit Poles on the Medallions crest: a shaman who knows a totem gets KstyleUI's secure totem bar and Blizzard's MultiCastActionBarFrame goes to Safe's hidden parent, nobody else gets a frame, an event or a callback; the sockets drop their multi-cast action slots, right click fans out the element's totems as multispell buttons that set the slot and close, shift right click dismisses, Call casts Call of the Elements and right click Totemic Recall; each spire lights from the slot's own boolean and drains from its duration object, secret or not, hidden rather than alpha 0 when Lua can read it; toggling in combat waits for the end of combat with nothing blocked; turning the setting or the slab off gives Blizzard's bar and the Ghost Wolf stance bar back; Motion Off shows end states and nothing runs OnUpdate; the sockets sit on an arc above the crest with the medals on its shoulders, clear of each other, the cooldown row and the crest debuff fan, at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local KNOWN = { [1] = { 3599, 8190, 8227 }, [2] = { 8075, 8071 }, [3] = { 5394 } }

local function New(class, opts)
	opts = opts or {}
	local size = opts.size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._totems, e._known = {}, { [66842] = true, [36936] = true }
			e.C_ActionBar.GetMultiCastBarIndex = function() return 12 end
			e.GetMultiCastTotemSpells = function(slot) return unpack(KNOWN[slot] or {}) end
			e.GetTotemInfo = function(slot)
				local t = e._totems[slot]
				if not t then return false, "", 0, 0, 0 end
				return t.have, "Totem", t.start, t.duration, 135825, 1, 3599
			end
			e.GetTotemDuration = function(slot)
				local t = e._totems[slot]
				return { start = t and t.start or 0, finish = t and t.finish or 0 }
			end
			e.SetMultiCastSpell = function(action, spell)
				e._game.slots[action] = spell ~= 0 and { texture = 135826, type = "spell", id = spell } or nil
			end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e._game.forms[1] = { texture = 136095, isActive = false, spellID = 2645 }
			e._game.slots[133] = { texture = 135825, type = "spell", id = 3599 }
			e.CreateFrame("Frame", "MultiCastActionBarFrame", e.UIParent)
		end,
	})
	local register = K.Events.Register
	env._events = {}
	K.Events.Register = function(owner, event, fn)
		if owner == "ActionBars.Totems" then env._events[event] = true end
		return register(owner, event, fn)
	end
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	return env, K, ns
end

local function Drop(env, slot, start, secret)
	local t = { have = true, start = start, duration = 20, finish = start + 20 }
	if secret then t.have, t.start, t.duration = env.Secret(true), env.Secret(start), env.Secret(20) end
	env._totems[slot] = t
	env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
end

local function Expire(env, slot, secret)
	env._totems[slot] = secret and { have = env.Secret(false), start = env.Secret(0), duration = env.Secret(0), finish = 0 } or nil
	env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
end

local function Seen(env, frame)
	local alpha = frame:GetAlpha()
	if env.issecretvalue(alpha) then alpha = env.Reveal(alpha) end
	return frame:IsShown() and alpha > 0
end

local function Updating(state)
	local n = 0
	for _, b in ipairs(state.sockets) do
		for _, frame in ipairs({ b, b.fan, b.spire, b.spire.gate, b.spire.lit, b.spire.core, b.spire.glow, b.spire.flare }) do
			n = n + (frame:GetScript("OnUpdate") and 1 or 0)
		end
	end
	return n
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
	assert(#env._blocked == 0, what .. ": blocked " .. table.concat(env._blocked, ", "))
end

-- Nobody but a shaman gets anything.
for _, class in ipairs({ "WARRIOR", "HUNTER", "DRUID" }) do
	local env, K, ns = New(class)
	local state = ns.Totems.state
	assert(state.header == nil and not state.shown and next(env._events) == nil, class .. ": no totem frame or event for another class")
	assert(env.MultiCastActionBarFrame:GetParent() == env.UIParent, class .. ": Blizzard's totem bar is untouched")
	assert(not ns.Totems.TakesStance(), class .. ": the stance bar stays")
	Drop(env, 1, 10)
	assert(state.header == nil, class .. ": a totem update builds nothing")
	Clean(env, K, class)
end

-- Take-over: the bar on the crest, Blizzard's bar hidden, the stance bar hidden.
do
	local env, K, ns = New("SHAMAN")
	local state = ns.Totems.state
	assert(state.shown and state.header:IsShown(), "a shaman who knows totems gets the bar on the crest")
	assert(env.MultiCastActionBarFrame:GetParent() ~= env.UIParent and K.Safe.IsHidden(env.MultiCastActionBarFrame), "Blizzard's MultiCastActionBarFrame goes to Safe's hidden parent")
	assert(ns.bars.stance:Visibility() == "hide", "the lone Ghost Wolf stance bar hides; Ghost Wolf rides on the crest")
	local earth, fire, water, air = unpack(state.sockets)
	assert(earth.element.slot == 2 and fire.element.slot == 1 and water.element.slot == 3 and air.element.slot == 4, "the sockets keep the game's bar order: earth, fire, water, air")
	assert(fire:GetAttribute("type") == "action" and fire:GetAttribute("action") == 133 and earth:GetAttribute("action") == 134, "each socket drops its multi-cast action slot on page 12")
	assert(fire:IsShown() and earth:IsShown() and water:IsShown() and not air:IsShown(), "an element with no known totem has no socket")
	assert(fire.hasAction and not earth.hasAction and earth.rune:IsShown() and not fire.rune:IsShown(), "a chosen totem shows its icon; an empty slot shows the element's rune")
	assert(state.wolf:IsShown() and state.wolf:GetAttribute("spell") == 2645 and state.call:GetAttribute("spell") == 66842, "Ghost Wolf and Call of the Elements are medals")

	-- Drop a totem: the socket casts its action.
	AB.Click(env, fire, "LeftButton", false)
	assert(AB.Used(env) == 133, "left click drops the chosen totem")

	-- Choose from the fan: right click opens it, a pick sets the slot through multispell and closes it.
	assert(not fire.fan:IsShown(), "the fan starts shut")
	AB.Click(env, fire, "RightButton", false)
	assert(fire.fan:IsShown() and fire.fan._autoHide, "right click opens the fan, which hides itself when the mouse leaves")
	local first, magma = fire.fan.buttons[1], fire.fan.buttons[3]
	assert(first:GetAttribute("spell") == 0 and first:IsShown() and first.rune, "the first choice clears the slot and shows the element's rune")
	assert(fire.fan.buttons[4]:IsShown() and not fire.fan.buttons[5]:IsShown(), "the fan holds none and every known totem of the element")
	assert(fire.fan.buttons[2].selected and not magma.selected, "the chosen totem is selected in the fan")
	assert(magma:GetAttribute("type") == "multispell" and magma:GetAttribute("action") == 133 and magma:GetAttribute("spell") == 8190, "each choice is a secure multispell button")
	AB.Click(env, magma, "LeftButton", false)
	assert(AB.Used(env) == "multispell133:8190" and not fire.fan:IsShown(), "a pick sets the slot and closes the fan")
	env.FireEvent("ACTIONBAR_SLOT_CHANGED", 133)
	assert(magma.selected and fire.icon:GetTexture() == 135826, "the socket and the fan show the new choice")
	AB.Click(env, fire, "RightButton", false)
	AB.Click(env, fire, "RightButton", false)
	assert(not fire.fan:IsShown(), "right click again shuts the fan")

	-- Dismiss, Call and Recall.
	env._game.shift = true
	AB.Click(env, fire, "RightButton", false)
	env._game.shift = false
	assert(AB.Used(env) == "destroytotem1" and not fire.fan:IsShown(), "shift right click dismisses the element's totem")
	AB.Click(env, state.call, "LeftButton", false)
	assert(AB.Used(env) == "spell66842", "Call casts Call of the Elements")
	AB.Click(env, state.call, "RightButton", false)
	assert(AB.Used(env) == "spell36936", "right click on Call casts Totemic Recall")
	AB.Click(env, state.wolf, "LeftButton", false)
	assert(AB.Used(env) == "spell2645", "the wolf medal casts Ghost Wolf")

	-- Keybinds: KstyleUI's own CLICK bindings drive the sockets.
	env._game.bindings["CLICK KstyleUI_TotemSlot2:LeftButton"] = { "F5" }
	assert(env["BINDING_NAME_CLICK KstyleUI_TotemSlot2:LeftButton"] and env["BINDING_NAME_CLICK KstyleUI_TotemCall:RightButton"], "each totem binding has a label")
	assert(AB.PressKey(env, "F5") and AB.Used(env) == 133, "the Fire totem binding drops the fire socket's totem")
	Clean(env, K, "take-over")
end

-- The spire: the slot's own boolean and duration object, secret or not; hidden, not alpha 0, when readable.
do
	local env, K, ns = New("SHAMAN")
	local fire = ns.Totems.state.sockets[2]
	local s = fire.spire
	assert(not s.gate:IsShown(), "no totem: the spire's lit layers are hidden, not drawn at alpha 0")
	Drop(env, 1, 100)
	assert(Seen(env, s.gate), "a totem lights its spire")
	local timer = AB.W.LastCall(s.lit, "SetTimerDuration")
	assert(timer and timer[1].start == 100 and timer[1].finish == 120 and timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "the spire drains by the totem's time left from the slot's duration object")
	assert(AB.W.LastCall(s.glow, "SetTimerDuration") and AB.W.LastCall(s.core, "SetTimerDuration"), "the glow and core drain with it")
	assert(s.flare:IsShown() and s.flare.anim:IsPlaying() and s.ignite:IsPlaying(), "a drop flares and ignites the spire at Full")
	Expire(env, 1)
	assert(not s.gate:IsShown(), "an expired totem leaves dark steel")
	Drop(env, 1, 200, true)
	assert(s.gate:IsShown() and Seen(env, s.gate), "a secret totem lights through SetAlphaFromBoolean")
	Expire(env, 1, true)
	assert(s.gate:IsShown() and not Seen(env, s.gate), "a secret expiry hides it through its alpha, with no Lua compare")
	assert(Updating(ns.Totems.state) == 0, "no totem frame runs OnUpdate")
	K.Options.Write("Medallions", "motion", "off")
	Drop(env, 1, 300)
	assert(Seen(env, s.gate) and not s.flare:IsShown() and not s.ignite:IsPlaying(), "Motion Off shows the lit end state with no animation")
	K.Options.Write("Medallions", "motion", "calm")
	Drop(env, 1, 310)
	assert(s.flare.anim:IsPlaying(), "Calm still flares a drop")
	Clean(env, K, "spire")
end

-- Combat lockdown: the setting changes in combat wait; totem updates in combat paint without a blocked call.
do
	local env, K, ns = New("SHAMAN")
	local state = ns.Totems.state
	env.SetCombat(true)
	Drop(env, 1, 50)
	AB.Click(env, state.sockets[2], "RightButton", false)
	assert(state.sockets[2].fan:IsShown(), "the fan opens in combat through the secure handler")
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	assert(state.header:IsShown() and state.shown, "turning the bar off in combat waits")
	assert(#env._blocked == 0, "nothing protected moved in combat: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	env.RunTimers()
	assert(not state.header:IsShown() and not state.shown, "the bar goes once combat ends")

	-- Give-back: Blizzard's bar returns to its parent and the stance bar to its seat.
	assert(env.MultiCastActionBarFrame:GetParent() == env.UIParent and not K.Safe.IsHidden(env.MultiCastActionBarFrame), "off gives Blizzard's totem bar back")
	assert(ns.bars.stance:Visibility() == "show", "off gives the Ghost Wolf stance bar back")
	K.Options.Write("ActionBars", "totemBar", true)
	env.RunTimers()
	assert(state.header:IsShown() and K.Safe.IsHidden(env.MultiCastActionBarFrame) and ns.bars.stance:Visibility() == "hide", "on takes it over again")
	K.Options.Write("ActionBars", "slab", false)
	env.RunTimers()
	assert(not state.header:IsShown() and not K.Safe.IsHidden(env.MultiCastActionBarFrame) and ns.bars.stance:Visibility() == "show", "without the crest Blizzard's bar and the stance bar come back")
	K.Options.Write("ActionBars", "slab", true)
	env.RunTimers()
	assert(state.header:IsShown() and K.Safe.IsHidden(env.MultiCastActionBarFrame), "the crest's return brings the bar back")
	Clean(env, K, "combat")
end

-- The crest at four screen sizes: sockets on the arc above the hub, medals on its shoulders, none overlapping
-- another, every spire under the cooldown row and the crest debuff fan.
for _, size in ipairs(SIZES) do
	local env, K, ns = New("SHAMAN", { size = size })
	env._resolveRects = true
	local state = ns.Totems.state
	assert(state.shown, "the bar sits on the crest")
	local hub = ns.Slab.hub
	local hx, hy = hub:GetCenter()
	local rects = {}
	for _, b in ipairs(state.sockets) do
		if b:IsShown() then
			local _, y = b:GetCenter()
			assert(y > hy, size[1] .. "x" .. size[2] .. ": each socket sits above the hub's centre")
			rects[#rects + 1] = { b:GetRect() }
			rects[#rects + 1] = { b.spire:GetRect() }
		end
	end
	local layouts, root = K.Setup.Layouts, K.Scale.Root():GetEffectiveScale()
	local function Place(key) return layouts.Aspect(K.Scale.Aspect(), "medallions", K.Layout.Setting("preset"), key) end
	local _, _, _, group = layouts.MedallionsGroup(K.Scale.Aspect())
	local row, fan = Place("cooldowns.essential").y, (Place("actionbars.bar1") or { y = 55 }).y + group + 163
	for _, b in ipairs(state.sockets) do
		local _, bottom, _, height = b.spire:GetRect()
		local top = bottom and (bottom + height) * b.spire:GetEffectiveScale() / root
		assert(not b:IsShown() or top < row - 2 and top < fan, size[1] .. "x" .. size[2] .. ": the " .. b.element.name .. " spire stays under the cooldown row and the crest debuff fan (" .. tostring(top) .. " against " .. row .. ")")
	end
	local wx = state.wolf:GetCenter()
	local cx = state.call:GetCenter()
	assert(wx < hx and cx > hx, size[1] .. "x" .. size[2] .. ": Ghost Wolf on the left shoulder, Call on the right")
	rects[#rects + 1] = { state.wolf:GetRect() }
	rects[#rects + 1] = { state.call:GetRect() }
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			local apart = a[1] + a[3] <= b[1] + 0.5 or b[1] + b[3] <= a[1] + 0.5 or a[2] + a[4] <= b[2] + 0.5 or b[2] + b[4] <= a[2] + 0.5
			assert(apart or i % 2 == 1 and j == i + 1, size[1] .. "x" .. size[2] .. ": totem pieces " .. i .. " and " .. j .. " overlap")
		end
	end
	Clean(env, K, "ring " .. size[1])
end
