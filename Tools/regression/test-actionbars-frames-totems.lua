-- test-actionbars-frames-totems.lua: the shaman's Spirit Poles under Frames: the same secure sockets, spires, fans and medals stand upright in a row at the stance bar's place beside the tray, sized as the stance bar's buttons, in the game's bar order with Ghost Wolf and Call after them and no rune ring; Blizzard's totem bar and the lone Ghost Wolf stance bar hide; each fan is a column rising from its socket that unfolds from it; the slab setting does not matter, the Shaman totem bar setting shows and works under Frames, and switching to Medallions puts the poles back on the crest; the row stays on screen and clear of every other element of the DPS, Tank and Healer layouts, centred and spread, at four screen sizes, and an open fan clears the unit frames.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local KNOWN = { [1] = { 3599, 8190, 8227 }, [2] = { 8075, 8071, 2484, 5730, 8143, 2062 }, [3] = { 5394 }, [4] = { 8512 } }

local function New(size)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = "SHAMAN",
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
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e._game.forms[1] = { texture = 136095, isActive = false, spellID = 2645 }
			e._game.slots[133] = { texture = 135825, type = "spell", id = 3599 }
			e.CreateFrame("Frame", "MultiCastActionBarFrame", e.UIParent)
		end,
	})
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	env._resolveRects = true
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
	assert(#env._blocked == 0, what .. ": blocked " .. table.concat(env._blocked, ", "))
end

local function Near(a, b) return math.abs(a - b) < 0.01 end

local function Rect(frame, root)
	local l, b, w, h = frame:GetRect()
	local s = frame:GetEffectiveScale() / root
	return { l * s, b * s, w * s, h * s }
end

local function Apart(a, b)
	return a[1] + a[3] <= b[1] + 0.5 or b[1] + b[3] <= a[1] + 0.5 or a[2] + a[4] <= b[2] + 0.5 or b[2] + b[4] <= a[2] + 0.5
end

-- The row: at the stance bar's place, upright, in bar order, sized as the stance bar's buttons, no ring.
do
	local env, K, ns = New()
	local st = ns.Totems.state
	local root = K.Scale.Root():GetEffectiveScale()
	assert(K.HudStyle.Current() == "frames" and not ns.Slab.hub:IsShown(), "Frames: no crest")
	assert(st.shown and st.header:IsShown(), "a shaman who knows totems gets the bar under Frames")
	assert(K.Safe.IsHidden(env.MultiCastActionBarFrame) and ns.bars.stance:Visibility() == "hide", "Blizzard's totem bar and the lone Ghost Wolf stance bar hide")
	local point, seat, rel = st.header:GetPoint(1)
	assert(point == "BOTTOMLEFT" and seat == ns.bars.stance.holder and rel == "BOTTOMLEFT", "the row sits at the stance bar's place beside the tray")
	assert(not st.ring[5]:IsShown(), "no rune ring without the crest")
	local button = K.Setup.Layouts.Grid("actionbars.stance").size
	local last
	for i, b in ipairs(st.sockets) do
		local r = Rect(b, root)
		assert(Near(r[3], button) and Near(r[4], button), "socket " .. i .. " is a stance button's size (" .. r[3] .. ")")
		assert(not last or Near(r[2], last[2]) and r[1] > last[1] + last[3], "socket " .. i .. " stands in the row after the one before")
		local s = Rect(b.spire, root)
		assert(s[2] >= r[2] + r[4] - 0.5 and Near(s[1] + s[3] / 2, r[1] + r[3] / 2), "spire " .. i .. " stands upright on its socket")
		assert(tostring(AB.W.LastCall(b.spire.steel, "SetTexture")[1]):find("PipSpireSteel90.png", 1, true), "spire " .. i .. " wears the upright art")
		assert(tostring(AB.W.LastCall(b.spire.lit, "SetStatusBarTexture")[1]):find("PipSpire90.png", 1, true), "spire " .. i .. " drains the upright art")
		last = r
	end
	local wolf, call = Rect(st.wolf, root), Rect(st.call, root)
	assert(wolf[1] > last[1] + last[3] and call[1] > wolf[1] + wolf[3] and Near(wolf[2], last[2]), "Ghost Wolf then Call follow the sockets")
	assert(st.wolf:GetAttribute("spell") == 2645 and st.call:GetAttribute("spell") == 66842, "the medals still cast Ghost Wolf and Call")

	-- Drop, fan and dismiss work as on the crest; the fan is a column rising from the socket.
	local fire = st.sockets[2]
	AB.Click(env, fire, "LeftButton", false)
	assert(AB.Used(env) == 133, "left click drops the chosen totem")
	AB.Click(env, fire, "RightButton", false)
	assert(fire.fan:IsShown(), "right click opens the fan")
	local r, below = Rect(fire, root), nil
	for n, f in ipairs(fire.fan.buttons) do
		if f:IsShown() then
			local c = Rect(f, root)
			assert(Near(c[1] + c[3] / 2, r[1] + r[3] / 2) and c[2] >= r[2] + r[4] - 0.5, "choice " .. n .. " rises above its socket")
			assert(not below or c[2] >= below[2] + below[4] - 0.5, "choice " .. n .. " stacks above the one before")
			local fx, fy = f:GetCenter()
			local sx, sy = fire:GetCenter()
			local ox, oy = f.from:GetOffset()
			assert(math.abs(fx + ox - sx) < 1 and math.abs(fy + oy - sy) < 1, "choice " .. n .. " unfolds from its socket")
			below = c
		end
	end
	local magma = fire.fan.buttons[3]
	AB.Click(env, magma, "LeftButton", false)
	assert(AB.Used(env) == "multispell133:8190" and not fire.fan:IsShown(), "a pick sets the slot and closes the fan")
	env._game.shift = true
	AB.Click(env, fire, "RightButton", false)
	env._game.shift = false
	assert(AB.Used(env) == "destroytotem1", "shift right click dismisses")

	-- A totem lights its upright spire; the slab setting has no say under Frames.
	for i = 1, 4 do
		env._totems[i] = { have = true, start = 10, duration = 20, finish = 30 }
		env.FireEvent("PLAYER_TOTEM_UPDATE", i)
	end
	assert(fire.spire.gate:IsShown(), "a totem lights its spire")
	assert(not st.ring.breath:IsPlaying(), "the hidden ring does not breathe with all four up")
	K.Options.Write("ActionBars", "slab", false)
	env.RunTimers()
	assert(st.shown and st.header:IsShown(), "the slab setting does not take the row away under Frames")
	K.Options.Write("ActionBars", "slab", true)
	env.RunTimers()

	-- The setting shows under Frames and turns the row off and on.
	local row = K.Options.Row("ActionBars", "totemBar")
	assert(row and row.showWhen({}) ~= false, "Shaman totem bar shows in Options under Frames")
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	assert(not st.shown and not K.Safe.IsHidden(env.MultiCastActionBarFrame) and ns.bars.stance:Visibility() == "show", "off gives Blizzard's bar and the stance bar back")
	K.Options.Write("ActionBars", "totemBar", true)
	env.RunTimers()
	assert(st.shown and st.header:IsShown(), "on again")

	-- Medallions puts the poles back on the crest with their own art; Frames brings the row back.
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(st.shown and st.header:GetPoint(1) ~= "BOTTOMLEFT" and st.ring[5]:IsShown() and st.ring.breath:IsPlaying(), "Medallions: the poles on the crest, the ring back and breathing")
	assert(tostring(AB.W.LastCall(fire.spire.steel, "SetTexture")[1]):find("PipSpireSteel102.png", 1, true), "the crest's fire spire leans at its own angle")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(st.shown and st.header:GetPoint(1) == "BOTTOMLEFT" and not st.ring[5]:IsShown() and not st.ring.breath:IsPlaying(), "Frames: the row again, the ring still")
	for _, size in ipairs({ 32, 48 }) do
		K.Options.Write("ActionBars", "stance.size", size)
		env.RunTimers()
		local socket, stance = Rect(st.sockets[1], root), Rect(ns.bars.stance.buttons[1], root)
		assert(Near(socket[3], size) and Near(stance[3], size), "a stance size of " .. size .. " sizes the sockets as the stance button (" .. socket[3] .. ")")
	end
	Clean(env, K, "row")
end

-- Clearance: the row and Earth's open fan (seven choices) at four screen sizes, in each layout and arrangement.
for _, size in ipairs(SIZES) do
	local env, K, ns = New(size)
	local st, Layouts = ns.Totems.state, K.Setup.Layouts
	local root = K.Scale.Root():GetEffectiveScale()
	for _, run in ipairs({ { "DPS", "centred" }, { "Tank", "centred" }, { "Healer", "centred" }, { "DPS", "spread" }, { "Tank", "spread" }, { "Healer", "spread" } }) do
		local name = run[1]
		K.Options.Write("Layout", "arrangement", run[2])
		env.FireEvent("DISPLAY_SIZE_CHANGED")
		env.RunTimers()
		assert(K.Setup.Apply({ layout = name, modules = { ActionBars = true } }))
		env.RunTimers()
		local label = size[1] .. "x" .. size[2] .. " " .. name .. " " .. run[2]
		local W, H = K.Scale.Root():GetWidth(), K.Scale.Root():GetHeight()
		local origin = Rect(K.Scale.Root(), root)
		local function Local(frame)
			local r = Rect(frame, root)
			return { r[1] - origin[1], r[2] - origin[2], r[3], r[4] }
		end
		local pieces = {}
		for _, b in ipairs(st.sockets) do
			pieces[#pieces + 1] = Local(b)
			pieces[#pieces + 1] = Local(b.spire)
		end
		pieces[#pieces + 1] = Local(st.wolf)
		pieces[#pieces + 1] = Local(st.call)
		local positions = Layouts.Positions(name, "frames", K.Scale.Aspect(), K.Scale.Band())
		local units = {}
		for key, position in pairs(positions) do
			local element = Layouts.Element(key)
			if element and key ~= "actionbars.stance" and Layouts.Shown(name, key) ~= false then
				local l, b, r, t = Layouts.Rect(element, position, W, H, "frames")
				local rect = { l, b, r - l, t - b }
				for _, p in ipairs(pieces) do
					assert(Apart(p, rect), label .. ": the totem row overlaps " .. key)
				end
				if key:match("^unitframes%.") then units[#units + 1] = rect end
			end
		end
		for _, p in ipairs(pieces) do
			assert(p[1] >= 0 and p[2] >= 0 and p[1] + p[3] <= W and p[2] + p[4] <= H, label .. ": the totem row stays on screen")
		end
		local earth = st.sockets[1]
		AB.Click(env, earth, "RightButton", false)
		local shown = 0
		for _, f in ipairs(earth.fan.buttons) do
			if f:IsShown() then
				shown = shown + 1
				local c = Local(f)
				assert(c[2] + c[4] <= H, label .. ": Earth's fan stays on screen")
				for _, u in ipairs(units) do
					assert(Apart(c, u), label .. ": Earth's fan clears the unit frames")
				end
			end
		end
		assert(shown == #KNOWN[2] + 1, label .. ": Earth's fan holds none and every known totem")
		AB.Click(env, earth, "RightButton", false)
	end
	Clean(env, K, "clearance " .. size[1])
end

print("actionbars frames totems ok")
