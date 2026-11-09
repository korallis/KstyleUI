-- test-unitframes-aura-overflow.lua: every frame's aura rows hold many auras cleanly: the engine sorts them (yours,
-- then priority, then time left), the rows stay inside the footprint the layouts keep for them, and past rows by
-- columns a "+N" chip covers the last socket. The chip is counted by a hidden AuraContainer's own flow layout through
-- anchors alone, so the module never reads a count, a size or an aura; here the stub plays the engine's layout pass.
local U = dofile("Tools/regression/unitframes_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local W = U.W

local EPS = 1e-3

local function overlap(r, s)
	return r.left < s.right - EPS and s.left < r.right - EPS and r.bottom < s.top - EPS and s.bottom < r.top - EPS
end

local function inside(r, s)
	return r.left >= s.left - EPS and r.right <= s.right + EPS and r.bottom >= s.bottom - EPS and r.top <= s.top + EPS
end

local function same(r, s)
	return math.abs(r.left - s.left) < EPS and math.abs(r.right - s.right) < EPS and math.abs(r.bottom - s.bottom) < EPS and math.abs(r.top - s.top) < EPS
end

local function fmt(r)
	return string.format("(%.1f,%.1f-%.1f,%.1f)", r.left, r.bottom, r.right, r.top)
end

local env, K, ns = U.New()
local Frames, Overflow, Settings = ns.Frames, ns.Overflow, ns.Settings
local root = K.Scale.Root()

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function rect(frame)
	local r, why = Geometry.Rect(frame, root)
	assert(r, "no rect: " .. tostring(why))
	return r
end

U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 38, classification = "elite", health = 620, healthMax = 1000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
for i = 1, 5 do
	U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = -1, classification = "worldboss", health = 50, healthMax = 100, reaction = 2, canAttack = true })
end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.RunTimers()
noErrors("setup")

local target = Frames.Get("target").views[1]
local focus = Frames.Get("focus").views[1]
local bosses = Frames.Get("boss").views

-- The engine sorts each row: your auras first, then the priority ones, then by time left -------------------------
for _, view in ipairs({ target, focus, bosses[1] }) do
	local c = view.auras.container
	for _, key in ipairs({ "debuffs", "buffs" }) do
		local group = c._groups[key]
		assert(group.options.sortMethod == env.AuraContainerSortMethod.Expiration, view.kind .. " " .. key .. " are sorted by the engine's expiration rule")
		assert(group.options.sortDirection == env.AuraContainerSortDirection.Normal, "soonest first")
		assert(group.sort and group.sort[1] == env.AuraContainerSortMethod.Expiration, view.kind .. " " .. key .. " keep the sort after settings apply")
	end
end

-- The sigil holds one row of fourteen 28-unit sockets, each timer in its own lane under the tile: 14 of your debuffs
-- before the chip. Round 4 (Fable #3) raised the floor from 24 units; two rows of 28 would need 60 units under the
-- sigil, past the 52 the layouts keep there, so the row grew wider instead of taller.
assert(Settings.Value("target", "auraRows") == 1 and Settings.Value("target", "auraColumns") == 14 and Settings.Value("target", "auraSize") == 28,
	"the sigil's debuffs are one row of fourteen 28-unit sockets")
assert(target.auras.container._groups.debuffs.max == 14, "fourteen sockets, then the chip")
-- A boss card holds one row of four 22-unit sockets beside it: three of your debuffs and the chip, big enough to
-- tell which is which, the timer in a corner badge instead of across the icon (round 3: Opus #5, Grok #1).
assert(Settings.Value("boss", "auraRows") == 1 and Settings.Value("boss", "auraColumns") == 4, "a boss card holds one row of four sockets")
assert(Settings.Value("boss", "auraSize") >= 20, "each boss socket is at least 20 units, got " .. Settings.Value("boss", "auraSize"))
assert(bosses[1].auras.container._groups.debuffs.max == 4, "four on each boss card")

-- Every aura row stays inside the footprint the DPS layout keeps for its frame, at its full rows by columns ------
do
	local Layouts = K.Setup.Layouts
	local layout = Layouts.Get("DPS")
	local rw, rh = root:GetWidth(), root:GetHeight()
	local function footprint(key)
		local w, h = Layouts.Footprint("DPS", key)
		local l, b, r, t = Layouts.Rect({ width = w, height = h }, layout[key], rw, rh)
		return { left = l, bottom = b, right = r, top = t }
	end
	local checks = { { target, "unitframes.target" }, { focus, "unitframes.focus" } }
	for i = 1, 5 do
		checks[#checks + 1] = { bosses[i], "unitframes.boss" }
	end
	for _, check in ipairs(checks) do
		local view, key = check[1], check[2]
		assert(view.auras.host:IsShown(), view.unit .. "'s aura row shows")
		local host, room = rect(view.auras.host), footprint(key)
		assert(inside(host, room), view.unit .. "'s aura rows " .. fmt(host) .. " stay inside " .. key .. "'s footprint " .. fmt(room))
		assert(not overlap(host, rect(view.button)), view.unit .. "'s aura rows sit beside the frame, not on it")
	end
	-- The boss row hangs beside its own card, never into the next one, and never over the card's name or bar.
	for i = 1, 5 do
		local host, card = rect(bosses[i].auras.host), rect(bosses[i].button)
		assert(host.top <= card.top + EPS and host.bottom >= card.bottom - EPS, "boss" .. i .. "'s row stays beside its card " .. fmt(host) .. " " .. fmt(card))
		assert(host.top - host.bottom < 2 * Settings.Value("boss", "auraSize"), "boss" .. i .. "'s debuffs are one row")
		for _, part in ipairs({ bosses[i].name, bosses[i].health }) do
			assert(not overlap(host, rect(part)), "boss" .. i .. "'s debuffs leave its name and bar clear")
		end
	end
	-- The timer is a corner badge on the tile's bottom right, over a dark plate, so most of the icon shows.
	local entry = bosses[1].auras.buttons[1]
	assert(entry, "the boss row has aura buttons")
	local point, rel, relPoint = entry.timer:GetPoint(1)
	assert(point == "BOTTOMRIGHT" and rel == entry.skin and relPoint == "BOTTOMRIGHT", "the boss timer sits in the tile's bottom right corner: " .. tostring(point))
	assert(entry.badge and entry.badge:IsShown(), "on a dark badge")
end
noErrors("bounds")

-- The overflow chip ------------------------------------------------------------------------------------------------
-- Fill(view, lines) sizes the engine's container as its flow layout does when the group fills `lines` rows.
local function Fill(view, lines)
	local a = view.auras
	local size = a.host:GetWidth() >= 0 and K.Widgets.Snap(a.host, Settings.Value(view.kind, "auraSize"))
	local spacing = K.Widgets.Snap(a.host, Settings.Value(view.kind, "auraSpacing"))
	local columns = Settings.Value(view.kind, "auraColumns")
	local lineGap = a.container._groups.debuffs.layout.lineSpacing
	a.container:SetSize(columns * size + (columns - 1) * spacing, lines * size + (lines - 1) * lineGap)
end

-- Engine(chip, n) plays the hidden container's flow layout for n auras: one element of one unit per line, each line
-- PITCH cells tall, never fewer than one unit (AnchorUtil.ApplyFlowLayout's floor).
local function Engine(chip, n)
	local cell = chip.window._width
	chip.ghost:SetSize(1, math.max(1, n * cell * Overflow.PITCH))
end

local function Read(chip)
	local win, strip = rect(chip.window), rect(chip.strip)
	local face = strip.bottom <= win.bottom + EPS and strip.top >= win.top - EPS
	local shown = {}
	for i, label in ipairs(chip.labels) do
		local r = rect(label)
		if overlap(r, win) then
			assert(same(r, win), "a label in the window fills it exactly " .. fmt(r) .. " " .. fmt(win))
			shown[#shown + 1] = chip.texts[i]:GetText()
		end
	end
	return face, overlap(strip, win), shown, win
end

do
	-- The two-row case, as a player sets it: two rows of ten.
	K.Options.Write("UnitFrames", "target.auraRows", 2)
	K.Options.Write("UnitFrames", "target.auraColumns", 10)
	local a = target.auras
	local chip = a.overflow.debuffs
	assert(chip and chip.window:IsShown(), "the sigil's debuffs carry an overflow chip")
	assert(not a.overflow.buffs.window:IsShown(), "the buffs' chip is off while the sigil shows no buffs")
	Fill(target, 2)
	local host = rect(a.host)
	local cap = target.auras.container._groups.debuffs.max
	for _, n in ipairs({ 0, 3, 10, 16, cap }) do
		Engine(chip, n)
		local face, touch, shown = Read(chip)
		assert(not face and not touch and #shown == 0, n .. " debuffs fit the rows: no chip, no sliver of it")
	end
	for _, case in ipairs({ { cap + 1, "+2" }, { cap + 4, "+5" }, { cap + Overflow.LABELS, "+" .. (Overflow.LABELS + 1) } }) do
		Engine(chip, case[1])
		local face, _, shown, win = Read(chip)
		assert(face, case[1] .. " debuffs: the chip's glass covers the last socket")
		assert(#shown == 1 and shown[1] == case[2], case[1] .. " debuffs read " .. case[2] .. ", got " .. tostring(shown[1]) .. " of " .. #shown)
		assert(inside(win, host), "the chip sits on the last socket, inside the row " .. fmt(win) .. " " .. fmt(host))
		local cell = chip.window._width
		assert(math.abs(win.right - host.right) < EPS and math.abs(win.bottom - (host.top - 2 * cell - K.Widgets.Snap(a.host, 2))) < EPS,
			"on the second row's last socket " .. fmt(win))
	end
	assert(chip.window:GetFrameLevel() > a.host:GetFrameLevel() + 5, "the chip draws over the sockets and their text")
	assert(chip.chrome.ownFill and chip.chrome.fillColor[4] == 1, "the chip's glass is opaque, so the socket under it never shows through")
	for _, button in ipairs(chip.ghost._groups.count.buttons) do
		local mouse = W.LastCall(button, "EnableMouse")
		assert(mouse and mouse[1] == false, "the counting container's buttons never take the mouse")
	end
	assert(chip.ghostHost:GetAlpha() == 0, "the counting container draws nothing")
	-- Once a container has a group, the engine refuses an anchor onto it from a frame without the
	-- UntrustedLayoutScriptExecution aspect (Blizzard_CustomAuraContainer.lua), and the stub does too: every frame of
	-- the chip's chain opts in with DisableUntrustedLayoutScriptsTemplate.
	for _, frame in ipairs({ chip.window, chip.strip, chip.face, unpack(chip.labels) }) do
		assert(frame._template == "DisableUntrustedLayoutScriptsTemplate", "a chip frame anchored along the engine's containers carries the layout template")
	end
	assert(chip.ghost._unit == "target" and chip.ghost._groups.count.filter == "HARMFUL|PLAYER", "it counts what the row shows")
	assert(chip.ghost._line == 1, "one element per line, so its height is the count")
	K.Options.Write("UnitFrames", "target.auraRows", 1)
	K.Options.Write("UnitFrames", "target.auraColumns", 14)
end
noErrors("chip")

-- Debuffs and buffs: the buffs' last row ends on the container's far edge, wherever the debuffs stopped -----------
do
	K.Options.Write("UnitFrames", "focus.auraFilter", "both")
	local a = focus.auras
	local chip = a.overflow.buffs
	assert(chip.window:IsShown() and a.overflow.debuffs.window:IsShown(), "both rows carry a chip")
	assert(chip.ghost._groups.count.filter == "HELPFUL", "the buffs' chip counts buffs")
	local columns = Settings.Value("focus", "auraColumns")
	local size, spacing = K.Widgets.Snap(a.host, Settings.Value("focus", "auraSize")), K.Widgets.Snap(a.host, Settings.Value("focus", "auraSpacing"))
	a.container:SetSize(columns * size + (columns - 1) * spacing, 2 * size + spacing)
	Engine(chip, columns + 2)
	local face, _, shown, win = Read(chip)
	local box = rect(a.container)
	assert(face and shown[1] == "+3", "ten buffs on eight sockets read +3")
	assert(math.abs(win.bottom - box.bottom) < EPS and math.abs(win.right - box.right) < EPS, "on the buffs' last socket " .. fmt(win) .. " " .. fmt(box))
	K.Options.Write("UnitFrames", "focus.auraFilter", "mine")
	assert(not chip.window:IsShown(), "back to your debuffs only, the buffs' chip goes")
end
noErrors("both")

-- No count is read: the module never asks the engine's containers for their size or place ------------------------
do
	local traps = { "GetSize", "GetWidth", "GetHeight", "GetRect", "GetTop", "GetBottom", "GetLeft", "GetRight", "GetNumPoints" }
	local containers = {}
	for _, view in ipairs({ target, focus, bosses[1] }) do
		containers[#containers + 1] = view.auras.container
		for _, key in ipairs({ "debuffs", "buffs" }) do
			containers[#containers + 1] = view.auras.overflow[key].ghost
		end
	end
	for _, c in ipairs(containers) do
		for _, name in ipairs(traps) do
			c[name] = function()
				error("the module read an aura container's geometry (" .. name .. ")")
			end
		end
	end
	K.Options.Write("UnitFrames", "target.auraColumns", 8)
	K.Options.Write("UnitFrames", "boss.auraSize", 20)
	K.Options.Write("UnitFrames", "focus.auraRows", 2)
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	noErrors("no reads")
	assert(target.auras.overflow.debuffs.ghost._groups.count.max == 8 * Settings.Value("target", "auraRows") + Overflow.LABELS, "a new cap reaches the counting container")
	K.Options.Write("UnitFrames", "target.auraColumns", 14)
	K.Options.Write("UnitFrames", "boss.auraSize", 22)
	K.Options.Write("UnitFrames", "focus.auraRows", 1)
end

-- A targeted boss folds its chip with its debuffs ------------------------------------------------------------------
do
	local b1 = bosses[1]
	env._units.target = env._units.boss1
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(b1.body:GetAlpha() < 0.5, "the targeted boss folds to its chip")
	for _, part in ipairs(ns.Auras.Parts(b1)) do
		assert(part:GetAlpha() < 0.5, "its aura row and overflow chips step back with it")
	end
	assert(#ns.Auras.Parts(b1) == 3, "the container and both chips fold")
	env._units.target = nil
	env.FireEvent("PLAYER_TARGET_CHANGED")
	for _, part in ipairs(ns.Auras.Parts(b1)) do
		assert(part:GetAlpha() > 0.5, "and come back when it is no longer your target")
	end
end
noErrors("fold")

-- The module stopping stops the counting containers too --------------------------------------------------------
K.Modules.Disable("UnitFrames")
assert(target.auras.overflow.debuffs.ghost._enabled == false, "the counting container stops with the module")
K.Modules.Enable("UnitFrames")
assert(target.auras.overflow.debuffs.ghost._enabled == true, "and starts again with it")
noErrors("module")

-- Without a second engine container, the row still works and the devlog says why --------------------------------
do
	local made = 0
	local nenv, NK, nns = U.New({ setup = function(e)
		local create = e.CreateFrame
		e.CreateFrame = function(frameType, ...)
			if frameType == "AuraContainer" then
				made = made + 1
				if made % 3 ~= 1 then
					error("no more containers")
				end
			end
			return create(frameType, ...)
		end
	end })
	local view = nns.Frames.Get("focus").views[1]
	assert(view.auras.container and next(view.auras.overflow) == nil, "the row builds without its chips")
	local logged = false
	for _, entry in ipairs(NK.Store.Data().devlog) do
		logged = logged or (entry.module == "UnitFrames" and entry.message:find("overflow chip", 1, true) ~= nil)
	end
	assert(logged, "a missing counting container is logged")
	assert(#nenv._errors == 0 and NK.ErrorCount() == 0, "and raises nothing: " .. tostring(nenv._errors[1]))
end

print("unitframes aura overflow ok")
