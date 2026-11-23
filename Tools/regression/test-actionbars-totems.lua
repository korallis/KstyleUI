-- test-actionbars-totems.lua: the shaman's Spirit Poles on the Medallions crest: a shaman who knows a totem gets KstyleUI's secure totem bar and Blizzard's MultiCastActionBarFrame goes to Safe's hidden parent, nobody else gets a frame, an event or a callback; the sockets drop their multi-cast action slots, right click fans out the element's totems as multispell buttons that set the slot and close, shift right click dismisses, Call casts Call of the Elements and right click Totemic Recall; each spire lights from the slot's own boolean and drains from its duration object, secret or not, hidden rather than alpha 0 when Lua can read it; toggling in combat waits for the end of combat with nothing blocked; turning the setting or the slab off gives Blizzard's bar and the Ghost Wolf stance bar back; Motion Off shows end states and nothing runs OnUpdate; the sockets sit on an arc above the crest with the medals on its shoulders, clear of each other, the cooldown row and the crest debuff fan, at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local KNOWN = { [1] = { 3599, 8190, 8227 }, [2] = { 8075, 8071 }, [3] = { 5394 }, [4] = { 8512 } }

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
				return t.have, "Totem", t.start, t.duration, 135825, 1, t.spell or 3599
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
	assert(not ns.Totems.state.shown, class .. ": the stance bar stays")
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
	assert(fire:IsShown() and earth:IsShown() and water:IsShown() and air:IsShown(), "each element with a known totem has a socket")
	KNOWN[4] = nil
	ns.Totems.Update()
	env.RunTimers()
	assert(not air:IsShown() and not air.spire:IsShown(), "an element with no known totem has no socket")
	KNOWN[4] = { 8512 }
	ns.Totems.Update()
	env.RunTimers()
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
	assert(fire.fan.buttons[4]:IsShown() and not (fire.fan.buttons[5] and fire.fan.buttons[5]:IsShown()), "the fan holds none and every known totem of the element")
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

-- The approved forged look, also for a shaman who knows only Earth and Fire: each fan choice wears its element's
-- edge and tab, a socket keeps its closed look (its tab, no edge), and an open fan sits on a dark band rimmed in the
-- element's colour with a steel lip at the token's own alpha.
do
	KNOWN[3], KNOWN[4] = nil, nil
	local env, K, ns = New("SHAMAN")
	local state, root = ns.Totems.state, K.Scale.Root():GetEffectiveScale()
	local function Atom(b, e, what)
		local name = "totem" .. e.name
		assert(b.edge and b.edge:IsShown() and AB.Tinted(K, b.edge, "SetVertexColor", name), what .. " wears its element's edge")
		assert(b.tab and b.tab:IsShown() and AB.Tinted(K, b.tab, "SetVertexColor", name), what .. " carries its element's tab")
	end
	for i, b in ipairs(state.sockets) do
		assert(b:IsShown() == (i <= 2), "only Earth and Fire have sockets")
		if i <= 2 then
			local name = "totem" .. b.element.name
			assert(not (b.edge and b.edge:IsShown()) and AB.Tinted(K, b.tab, "SetVertexColor", name), b.element.name .. " socket keeps its closed look: its tab and no edge")
			AB.Click(env, b, "RightButton", false)
			local fill, rim, lip = false, false, false
			for _, q in ipairs(AB.Band(b.fan, root)) do
				fill = fill or AB.Tinted(K, q.line, "SetColorTexture", "medSocket")
				rim = rim or AB.Tinted(K, q.line, "SetColorTexture", name)
				lip = lip or AB.Tinted(K, q.line, "SetColorTexture", "medSocketLip")
			end
			assert(fill and rim, b.element.name .. ": the open fan sits on a dark forged band rimmed in the element's colour")
			assert(lip, b.element.name .. ": the band's steel lip keeps medSocketLip's alpha")
			for n, f in ipairs(b.fan.buttons) do
				if f:IsShown() then Atom(f, b.element, b.element.name .. " choice " .. n) end
			end
			AB.Click(env, b, "RightButton", false)
		end
	end
	KNOWN[3], KNOWN[4] = { 5394 }, { 8512 }
	Clean(env, K, "forged look")
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
	assert(not s.flare.anim:IsPlaying() and not s.ignite:IsPlaying(), "a readable expiry plays no flare or ignite")
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
-- another, every spire under the cooldown row and the crest debuff fan; each open fan, Earth's with all six earth
-- totems, clear of the cooldown row, the debuff fan, the ring and the unit frames.
local EARTH = KNOWN[2]
KNOWN[2] = { 8075, 8071, 2484, 5730, 8143, 2062 }
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
	local ring = hub:GetWidth() * hub:GetEffectiveScale() / root / 2
	local units = {}
	for _, key in ipairs({ "unitframes.player", "unitframes.target" }) do
		local p = Place(key) or layouts.Style(K.Layout.Setting("preset"), key)
		units[#units + 1] = { hx + p.x - p.width / 2, p.y, p.width, p.height }
	end
	for _, b in ipairs(state.sockets) do
		AB.Click(env, b, "RightButton", false)
		local choices = {}
		for _, f in ipairs(b.fan.buttons) do
			if f:IsShown() then
				local l, bottom, w, h = f:GetRect()
				local s = f:GetEffectiveScale() / root
				l, bottom, w, h = l * s, bottom * s, w * s, h * s
				local label = size[1] .. "x" .. size[2] .. ": " .. b.element.name .. " fan choice " .. #choices + 1
				assert(bottom + h < row - 2 and bottom + h < fan, label .. " stays under the cooldown row and the crest debuff fan (" .. bottom + h .. " against " .. row .. ")")
				local nx, ny = math.max(l, math.min(hx, l + w)), math.max(bottom, math.min(hy, bottom + h))
				assert((nx - hx) ^ 2 + (ny - hy) ^ 2 > ring * ring, label .. " stays out of the ring")
				for _, u in ipairs(units) do
					assert(l + w <= u[1] or u[1] + u[3] <= l or bottom + h <= u[2] or u[2] + u[4] <= bottom, label .. " stays off the unit frames")
				end
				for _, c in ipairs(choices) do
					assert(l + w <= c[1] + 0.5 or c[1] + c[3] <= l + 0.5 or bottom + h <= c[2] + 0.5 or c[2] + c[4] <= bottom + 0.5, label .. " overlaps another choice")
				end
				choices[#choices + 1] = { l, bottom, w, h }
			end
		end
		assert(#choices == #KNOWN[b.element.slot] + 1, size[1] .. "x" .. size[2] .. ": the " .. b.element.name .. " fan holds none and every known totem")
		local label, band = size[1] .. "x" .. size[2] .. ": the " .. b.element.name .. " fan's band", AB.Band(b.fan, root)
		assert(#band > 0, label .. " is drawn")
		for _, q in ipairs(band) do
			for k = 1, 4 do
				assert(q[k][2] < row - 2 and q[k][2] < fan, label .. " stays under the cooldown row and the crest debuff fan (" .. q[k][2] .. " against " .. row .. ")")
			end
			for _, u in ipairs(units) do
				assert(not AB.Crosses(q, u), label .. " stays off the unit frames")
			end
			for _, other in ipairs(state.sockets) do
				local l, bottom, w, h = other:GetRect()
				local s = other:GetEffectiveScale() / root
				assert(not AB.Crosses(q, { l * s, bottom * s, w * s, h * s }), label .. " clears the " .. other.element.name .. " socket")
			end
		end
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
KNOWN[2] = EARTH

-- Review of 5f5ee15a: the secure actions as the client resolves modified attributes, Recall's key and medal.
do
	local env, K, ns = New("SHAMAN")
	local st, used = ns.Totems.state, env._game.used
	env._game.bindings["CLICK KstyleUI_TotemCall:RightButton"] = { "F6" }
	assert(AB.PressKey(env, "F6") and AB.Used(env) == "spell36936", "the Totemic Recall key casts Recall")
	env._known[36936] = nil
	ns.Totems.Update()
	env.RunTimers()
	local n = #used
	AB.Click(env, st.call, "RightButton", false)
	env._game.shift = true
	AB.Click(env, st.call, "RightButton", false)
	env._game.shift = false
	assert(#used == n, "right click on Call without Recall does nothing, not Call of the Elements: " .. tostring(AB.Used(env)))
	env._known[66842], env._known[36936] = nil, true
	ns.Totems.Update()
	env.RunTimers()
	assert(st.call:IsShown(), "Recall alone keeps the medal")
	AB.Click(env, st.call, "LeftButton", false)
	assert(#used == n, "left click without Call of the Elements does nothing")
	AB.Click(env, st.call, "RightButton", false)
	assert(AB.Used(env) == "spell36936", "right click still casts Recall")
	Clean(env, K, "recall")
end

-- Learning the first totem brings the bar, with no reload or layout refresh.
do
	local saved = KNOWN
	KNOWN = {}
	local env, K, ns = New("SHAMAN")
	assert(not ns.Totems.state.shown, "a shaman who knows no totem has no bar")
	KNOWN = saved
	env.FireEvent("SPELLS_CHANGED")
	env.RunTimers()
	assert(ns.Totems.state.shown, "learning the first totem brings the bar")
	Clean(env, K, "learn")
end

-- Cooldown events: SPELL_UPDATE_COOLDOWN's argument is a spell, so every socket repaints its cooldown and re-reads
-- isOnGCD; ACTIONBAR_UPDATE_COOLDOWN keeps the last trusted GCD flag; neither touches the fans' selection.
do
	local env, K, ns = New("SHAMAN")
	local st = ns.Totems.state
	local fire = st.sockets[2]
	local reads, selects, gcd = 0, 0, true
	local get = env.C_ActionBar.GetActionCooldownDuration
	env.C_ActionBar.GetActionCooldownDuration = function(slot, ...)
		if slot == 133 then reads = reads + 1 end
		return get(slot, ...)
	end
	env.C_ActionBar.GetActionCooldown = function() return { isOnGCD = gcd } end
	env._game.slots[133].cooldown = { name = "cd" }
	for _, b in ipairs(st.sockets) do
		for _, f in ipairs(b.fan.buttons) do
			local set = f.SetSelected
			f.SetSelected = function(...) selects = selects + 1; return set(...) end
		end
	end
	env.FireEvent("SPELL_UPDATE_COOLDOWN", 3599)
	assert(reads > 0, "a cooldown event for the Fire socket's spell repaints its cooldown")
	assert(fire.realCooldown == false, "the spell cooldown event reads isOnGCD")
	gcd = false
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	assert(fire.realCooldown == false, "an action bar cooldown event keeps the last trusted GCD flag")
	env.FireEvent("ACTIONBAR_UPDATE_USABLE")
	assert(selects == 0, "cooldown and usable events leave the fans' selection alone (" .. selects .. " SetSelected calls)")
	Clean(env, K, "cooldowns")
end

-- The socket's icon is passed to SetIcon, never tested as a Lua condition (a file ID may be secret).
do
	local f = assert(io.open("KstyleUI_ActionBars/Totems.lua", "rb"))
	local src = f:read("*a")
	f:close()
	assert(not src:find("and [%w_%.]*GetActionTexture%b() or"), "Totems.lua tests GetActionTexture's return with and/or; pass it to SetIcon in an explicit branch")
end

-- Fans: one open at a time, shut when the bar goes, every known totem offered.
do
	local env, K, ns = New("SHAMAN")
	local st = ns.Totems.state
	local earth, fire = st.sockets[1], st.sockets[2]
	AB.Click(env, fire, "RightButton", false)
	AB.Click(env, earth, "RightButton", false)
	assert(earth.fan:IsShown() and not fire.fan:IsShown(), "opening a fan shuts the one already open")
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	K.Options.Write("ActionBars", "totemBar", true)
	env.RunTimers()
	assert(st.header:IsShown() and not earth.fan:IsShown(), "turning the bar off and on leaves every fan shut")
	local saved = KNOWN[1]
	KNOWN[1] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
	ns.Totems.Update()
	env.RunTimers()
	local offered = {}
	for _, f in ipairs(fire.fan.buttons) do
		if f:IsShown() then offered[#offered + 1] = f:GetAttribute("spell") end
	end
	assert(#offered == 12 and offered[12] == 11, "the fan offers none and every known totem (" .. #offered .. " shown)")
	KNOWN[1] = saved
	Clean(env, K, "fans")
end

-- Keys: a bound socket shows its key; with the bar off its key does nothing; a vehicle or override bar hides the bar,
-- as Blizzard's MultiCastActionBarFrame hides when the main action bar is overridden.
do
	local env, K, ns = New("SHAMAN")
	local st, used = ns.Totems.state, env._game.used
	local fire = st.sockets[2]
	env._game.bindings["CLICK KstyleUI_TotemSlot2:LeftButton"] = { "F5" }
	env.FireEvent("UPDATE_BINDINGS")
	assert(fire.hotkey:IsShown() and fire.hotkey:GetText() == "F5", "a bound socket shows its key")
	for _, flag in ipairs({ "vehicle", "override" }) do
		env._game[flag] = 1
		env.RunStateDrivers()
		assert(not st.header:IsShown(), "a " .. flag .. " hides the totem bar")
		env._game[flag] = nil
		env.RunStateDrivers()
		assert(st.header:IsShown(), "leaving the " .. flag .. " brings it back")
	end
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	local n = #used
	AB.PressKey(env, "F5")
	assert(#used == n, "with the bar off the Fire totem key does nothing: " .. tostring(AB.Used(env)))
	Clean(env, K, "keys")
end

-- Polish: a fan unfolds from its socket over 0.12 s at Full and Calm and opens at once at Off; a chosen totem's icon
-- rests at 82% until it is up; a readable spire flickers through its last fifth at Full and holds steady at Calm, Off
-- or while secret; all four up lights the rune ring in the shaman's colour, breathing at Full and still otherwise.
do
	local env, K, ns = New("SHAMAN")
	env._resolveRects = true
	local st = ns.Totems.state
	local fire, now = st.sockets[2], 100
	env.GetTime = function() return now end
	local function Near(a, b) return math.abs(a - b) < 1e-6 end
	local function Motion(level)
		K.Options.Write("Medallions", "motion", level)
		env.RunTimers()
	end

	AB.Click(env, fire, "RightButton", false)
	local choice = fire.fan.buttons[2]
	assert(choice.anim:IsPlaying() and Near(choice.to:GetDuration(), 0.12), "the fan unfolds over 0.12 s at Full")
	local fx, fy = choice:GetCenter()
	local sx, sy = fire:GetCenter()
	local ox, oy = choice.from:GetOffset()
	assert(math.abs(fx + ox - sx) < 1 and math.abs(fy + oy - sy) < 1, "each choice unfolds from its socket")
	AB.Click(env, fire, "RightButton", false)
	choice.anim:Stop()
	Motion("calm")
	AB.Click(env, fire, "RightButton", false)
	assert(choice.anim:IsPlaying(), "Calm unfolds the fan too")
	AB.Click(env, fire, "RightButton", false)
	choice.anim:Stop()
	Motion("off")
	AB.Click(env, fire, "RightButton", false)
	assert(fire.fan:IsShown() and not choice.anim:IsPlaying(), "Off opens the fan at once")
	AB.Click(env, fire, "RightButton", false)
	Motion("full")

	local s = fire.spire
	assert(Near(fire.icon:GetAlpha(), 0.82), "a chosen totem's icon rests at 82% until it is up")
	Drop(env, 1, 100)
	assert(Near(fire.icon:GetAlpha(), 1) and not s.flicker.anim:IsPlaying(), "a fresh totem lifts its icon to full and burns steady")
	env.RunTimers()
	assert(s.flicker.anim:IsPlaying(), "its last fifth flickers at Full, timed from the readable start and duration")
	now = 117
	Drop(env, 1, 100)
	assert(s.flicker.anim:IsPlaying(), "a repaint inside the last fifth flickers at once")
	Motion("calm")
	assert(not s.flicker.anim:IsPlaying(), "Calm holds the stub steady")
	Motion("full")
	assert(s.flicker.anim:IsPlaying(), "Full brings the flicker back")
	Expire(env, 1)
	assert(not s.flicker.anim:IsPlaying() and Near(fire.icon:GetAlpha(), 0.82), "an expiry stops it and rests the icon")
	Drop(env, 1, 100, true)
	env.RunTimers()
	assert(not s.flicker.anim:IsPlaying(), "a secret slot holds steady: Lua cannot read when its last fifth starts")
	assert(AB.W.LastCall(fire.icon, "SetAlphaFromBoolean"), "a secret slot lifts the icon through SetAlphaFromBoolean")
	Expire(env, 1)

	local ring = st.ring
	assert(not ring[4]:IsVisible(), "no totem, no ring")
	now = 100
	for slot = 1, 4 do Drop(env, slot, 100) end
	assert(ring[4]:IsVisible() and ring.breath:IsPlaying(), "all four up lights the ring, breathing at Full")
	local level = ns.Slab.hub:GetFrameLevel()
	assert(ring[1]:GetFrameStrata() == ns.Slab.hub:GetFrameStrata() and ring[5]:GetFrameLevel() < level and ring.glyphs:GetFrameLevel() > level, "the halo sits under the crest and the glyphs over it, as on the hawks' ring")
	Motion("calm")
	assert(ring[4]:IsVisible() and not ring.breath:IsPlaying(), "Calm: lit and still")
	Motion("full")
	Expire(env, 3)
	assert(not ring[4]:IsVisible() and not ring.breath:IsPlaying(), "three up leaves the ring dark")
	Drop(env, 3, 100, true)
	assert(Seen(env, ring[3]) and not ring.breath:IsPlaying(), "a secret slot lights the ring through its alpha and holds it still")
	assert(Updating(st) == 0, "no totem frame runs OnUpdate")
	Clean(env, K, "polish")
end

-- Review of 1d4af6de: a chosen totem rests until that totem, not another of its element, is up; one GetTotemInfo read
-- per slot update; one last-fifth deadline per spire, rechecked when it fires and dropped with the bar; the ring takes
-- a live class colour edit.
do
	local env, K, ns = New("SHAMAN")
	local st = ns.Totems.state
	local fire, s = st.sockets[2], st.sockets[2].spire
	env.GetTime = function() return 100 end
	local function Near(a, b) return math.abs(a - b) < 1e-6 end
	local pending, after, get, reads = {}, env.C_Timer.After, env.GetTotemInfo, 0
	env.C_Timer.After = function(t, fn)
		if t > 1 then pending[#pending + 1] = fn else return after(t, fn) end
	end

	Drop(env, 1, 100)
	AB.Click(env, fire, "RightButton", false)
	AB.Click(env, fire.fan.buttons[3], "LeftButton", false)
	env.FireEvent("ACTIONBAR_SLOT_CHANGED", fire.slot)
	assert(fire.chosen == 8190 and Near(fire.icon:GetAlpha(), 0.82), "Magma chosen while Searing is up rests at 82%")
	env._totems[1].spell = 8190
	env.FireEvent("PLAYER_TOTEM_UPDATE", 1)
	assert(Near(fire.icon:GetAlpha(), 1), "Magma up lifts its icon to full")
	Expire(env, 1)

	env.GetTotemInfo = function(slot) reads = reads + 1; return get(slot) end
	Drop(env, 1, 100)
	assert(reads == 1, "one slot update reads GetTotemInfo once (" .. reads .. ")")
	env.GetTotemInfo = get
	local n = #pending
	for _ = 1, 10 do ns.Totems.Update(); env.RunTimers() end
	assert(#pending == n, "refreshes reuse the spire's last-fifth deadline (" .. #pending - n .. " more)")
	local t = env._totems[1]
	t.have, t.start, t.duration = env.Secret(true), env.Secret(100), env.Secret(20)
	env.FireEvent("PLAYER_TOTEM_UPDATE", 2)
	pending[#pending]()
	assert(not s.flicker.anim:IsPlaying(), "a deadline rechecks its slot: secret by then, the spire holds steady")
	Drop(env, 1, 100)
	pending[#pending]()
	assert(s.flicker.anim:IsPlaying(), "a readable deadline flickers")
	Expire(env, 1)
	Drop(env, 1, 100)
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	pending[#pending]()
	assert(not st.listening and not s.flicker.anim:IsPlaying(), "turning the bar off drops its deadline")
	env.C_Timer.After = after
	K.Options.Write("ActionBars", "totemBar", true)
	env.RunTimers()

	K.Theme.SetPalette({ SHAMAN = { r = 0.9, g = 0.1, b = 0.2 } }, 0)
	env.RunTimers()
	local c = K.Theme.Palette("SHAMAN")
	for _, art in ipairs({ st.ring.halo, (st.ring.glyphs:GetRegions()) }) do
		local v = AB.W.LastCall(art, "SetVertexColor")
		assert(v and Near(v[1], c.r) and Near(v[2], c.g) and Near(v[3], c.b), "the ring takes a live class colour edit")
	end
	Clean(env, K, "review 1d4af6de")
end
