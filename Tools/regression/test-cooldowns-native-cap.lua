-- test-cooldowns-native-cap.lua: on the restyled path Blizzard's tracked buff icon row stops at the module's grid
-- (columns by rows): its sockets go to the first active buffs in Blizzard's order, an inactive slot taking none, items
-- past the last of them fade out and stop taking the mouse, and a "+N" chip in the next slot counts the active ones
-- it hides, so a high count never runs down the screen (round 6, Grok #1, Muse) and an active buff never hides
-- behind the chip while a socket is free (round 7, Opus #2). Apply sizes the row for the grid and the chip, not for
-- every tracked buff.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W
local Geometry = dofile("Tools/regression/geometry.lua")

local FORBIDDEN = { SetScript = true, Hide = true, SetParent = true, SetPoint = true, ClearAllPoints = true, SetSize = true, SetScale = true }

local function Entry()
	-- One row hung from its bottom right, growing left (Orientation 0, IconDirection 0), at 100 % with a 4 + 8 gap.
	return {
		anchorInfo = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMLEFT", offsetX = 800, offsetY = 226 },
		settings = { { setting = 0, value = 0 }, { setting = 2, value = 0 }, { setting = 3, value = 5 }, { setting = 4, value = 12 } },
	}
end

-- 16 tracked buffs: 1-4, 6, 7, 9 and 10 active.
local ACTIVE = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true, [9] = true, [10] = true }
local function Rows(count, active)
	local items = {}
	for i = 1, count do
		items[i] = { id = 100 + i, icon = 1000 + i, name = "Buff " .. i, left = active[i] and 10 + i or nil, total = 30 }
	end
	return items
end

local function Items()
	return Rows(16, ACTIVE)
end

local function Set(...)
	local set = {}
	for _, i in ipairs({ ... }) do
		set[i] = true
	end
	return set
end

local function Span(from, to)
	local list = {}
	for i = from, to do
		list[#list + 1] = i
	end
	return list
end

local function Format(seconds)
	return seconds .. "s"
end

-- Boot(path, items, hide): hide is the viewer's Edit Mode Hide When Inactive, on unless false.
local function Boot(path, items, hide)
	local env, K, ns = C.New({ setup = C.Game })
	K.Options.Write("Cooldowns", "path", path or "reskin")
	C.Enable(env, K)
	env._viewers.BuffIconCooldownViewer._hideWhenInactive = hide
	local viewer = C.Native(env, "BuffIconCooldownViewer", Entry(), items or Items(), Format)
	env.RunTimers()
	return env, K, ns, viewer
end

local function Chip(ns)
	return ns.Cap.Chip()
end

local function Mouse(item)
	local call = W.LastCall(item, "SetMouseMotionEnabled")
	return call and call[1]
end

local function Shown(frame)
	return frame ~= nil and frame:IsShown() == true
end

-- Visible(viewer, slots, label): each slot keeps alpha 1 and is not stopped from taking the mouse.
local function Visible(viewer, slots, label)
	for _, i in ipairs(slots) do
		local item = viewer._items[i]
		assert(item:GetAlpha() == 1, label .. ": slot " .. i .. " stays visible, alpha " .. tostring(item:GetAlpha()))
		assert(Mouse(item) ~= false, label .. ": slot " .. i .. " still takes the mouse")
	end
end

-- Folded(viewer, slots, label): each slot fades to alpha 0 and takes no mouse.
local function Folded(viewer, slots, label)
	for _, i in ipairs(slots) do
		local item = viewer._items[i]
		assert(item:GetAlpha() == 0, label .. ": slot " .. i .. " fades out, alpha " .. tostring(item:GetAlpha()))
		assert(Mouse(item) == false, label .. ": slot " .. i .. " takes no mouse")
	end
end

-- InSlot(env, viewer, chip, slot): the chip fills that slot exactly.
local function InSlot(env, viewer, chip, slot)
	local c = assert(Geometry.Rect(chip, env.UIParent))
	local s = assert(Geometry.Rect(viewer._items[slot], env.UIParent))
	return W.Near(c.left, s.left) and W.Near(c.right, s.right) and W.Near(c.bottom, s.bottom) and W.Near(c.top, s.top)
end

-- Hover(env, ns) -> the chip tooltip's lines, after pointing at it.
local function Hover(env, ns)
	local chip = Chip(ns)
	env.GameTooltip.lines = {}
	chip:GetScript("OnEnter")(chip)
	local out = {}
	for _, line in ipairs(env.GameTooltip.lines or {}) do
		out[#out + 1] = line.left
	end
	return out
end

local function Names(lines, from)
	return table.concat(lines, "|", from)
end

-- The default grid is six sockets, and they go to the first six active buffs: 1-4, 6 and 7. Slot 5 is inactive, so
-- Blizzard hides it and it takes no socket; 8-16 fade out and stop taking the mouse.
do
	local env, K, ns, viewer = Boot()
	local cap = ns.Cap.Size()
	assert(cap == 6, "the native row stops at the grid's six sockets, got " .. tostring(cap))
	Visible(viewer, Span(1, 7), "six active buffs and the inactive slot between them")
	Folded(viewer, Span(8, 16), "past the sixth active buff")
	-- Active past the sixth: 9 and 10.
	local chip = Chip(ns)
	assert(Shown(chip), "a chip counts the active buffs past the sixth")
	assert(chip.text:GetText() == "+2", "the chip counts the two active buffs it hides, got " .. tostring(chip.text:GetText()))
	-- The chip stands in the eighth slot, one socket past the last visible one, on the row's open (left) side.
	assert(InSlot(env, viewer, chip, 8), "the chip fills the eighth slot")
	local c = assert(Geometry.Rect(chip, env.UIParent))
	local s7 = assert(Geometry.Rect(viewer._items[7], env.UIParent))
	assert(c.right <= s7.left, "the chip stands left of the last visible socket")
	assert(Names(Hover(env, ns), 2) == "Spell 109|Spell 110", "the chip lists the hidden active buffs, got " .. Names(Hover(env, ns), 2))

	-- An item past the sixth that turns inactive drops out of the count on its next shown-state update.
	viewer._items[9]._active = false
	viewer._items[9]:UpdateShownState()
	env.RunTimers()
	assert(chip.text:GetText() == "+1", "an inactive buff leaves the count, got " .. tostring(chip.text:GetText()))
	for _, i in ipairs({ 7, 10 }) do
		viewer._items[i]._active = false
		viewer._items[i]:UpdateShownState()
	end
	env.RunTimers()
	assert(not Shown(chip), "with five active buffs the chip hides")
	Visible(viewer, Span(1, 6), "five active buffs keep the grid's six sockets")
	Folded(viewer, Span(7, 16), "past the grid with nothing active there")

	-- A secret shown state is never compared, and with it the module cannot tell which slots hold a buff, so it
	-- caps nothing: the whole row shows as Blizzard draws it and the chip hides.
	local item = viewer._items[8]
	item.IsShown = function()
		return env.Secret(true)
	end
	item:UpdateShownState()
	env.RunTimers()
	assert(not Shown(chip), "a secret shown state hides the chip")
	Visible(viewer, Span(1, 16), "a secret shown state releases the row")
	item.IsShown = nil
	item:UpdateShownState()
	env.RunTimers()
	Folded(viewer, Span(7, 16), "a readable shown state caps the row again")

	-- A wider grid shows more sockets: eight columns keep 7 and 8, and the chip moves to the ninth slot.
	K.Options.Write("Cooldowns", "buffs.columns", 8)
	env.RunTimers()
	assert(viewer._items[7]:GetAlpha() == 1 and viewer._items[8]:GetAlpha() == 1, "a wider grid shows slots 7 and 8 again")
	assert(Mouse(viewer._items[7]) == true, "a slot shown again takes the mouse for its tooltip")
	assert(viewer._items[9]:GetAlpha() == 0, "slot 9 is past the eight-socket grid")

	-- A relayout (Blizzard's RefreshLayout re-acquires the items) applies the cap again.
	K.Options.Write("Cooldowns", "buffs.columns", 6)
	C.Native(env, "BuffIconCooldownViewer", Entry(), Items(), Format)
	env.RunTimers()
	assert(viewer._items[7]:GetAlpha() == 1, "a relayout keeps the sixth active buff")
	assert(viewer._items[8]:GetAlpha() == 0 and viewer._items[9]:GetAlpha() == 0, "a relayout fades the slots past it")
	assert(Chip(ns).text:GetText() == "+2", "a relayout counts again")

	-- Edit Mode's Show Tooltips off for the viewer turns the chip's tooltip off too (codex review).
	viewer:SetTooltipsShown(false)
	env.RunTimers()
	local mouse = W.LastCall(Chip(ns), "EnableMouse")
	assert(mouse and mouse[1] == false, "with the viewer's tooltips off the chip takes no mouse")
	env.GameTooltip.shown = false
	Chip(ns):GetScript("OnEnter")(Chip(ns))
	assert(not env.GameTooltip.shown, "and opens no tooltip")
	viewer:SetTooltipsShown(true)
	env.RunTimers()

	C.Clean(env, FORBIDDEN)
end

-- Twelve tracked, slots 1-6 inactive and 7-10 active (round 7, Opus #2): Blizzard keeps the six empty slots, so the
-- four active buffs sit in slots 7-10. All four show, and with only four active no chip stands anywhere.
do
	local env, _, ns, viewer = Boot("reskin", Rows(12, Set(7, 8, 9, 10)))
	Visible(viewer, Span(7, 10), "the four active buffs past six empty slots")
	assert(not Shown(Chip(ns)), "four active buffs need no chip")
	-- A fifth active buff, in slot 12, shows too: five active buffs fit the six sockets, wherever their slots are.
	viewer._items[12]._active = true
	viewer._items[12]:UpdateShownState()
	env.RunTimers()
	Visible(viewer, { 7, 8, 9, 10, 12 }, "five active buffs")
	assert(not Shown(Chip(ns)), "five active buffs need no chip")
	C.Clean(env, FORBIDDEN)
end

-- Twelve tracked, 1-10 active: the first six show and a +4 chip in slot 7 lists 7-10, never the inactive 11 and 12.
do
	local env, _, ns, viewer = Boot("reskin", Rows(12, Set(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)))
	Visible(viewer, Span(1, 6), "the first six of ten active buffs")
	Folded(viewer, Span(7, 12), "past the sixth active buff")
	local chip = Chip(ns)
	assert(Shown(chip) and chip.text:GetText() == "+4", "ten active buffs show six and +4, got " .. tostring(chip.text:GetText()))
	assert(InSlot(env, viewer, chip, 7), "the chip fills the seventh slot")
	local lines = Hover(env, ns)
	assert(lines[1] == "4 more tracked buffs", "the hover names the hidden count, got " .. tostring(lines[1]))
	assert(Names(lines, 2) == "Spell 107|Spell 108|Spell 109|Spell 110", "the hover lists the hidden active buffs, got " .. Names(lines, 2))
	C.Clean(env, FORBIDDEN)
end

-- Inactive slots mixed in: 1-6 and 8 and 10 active, 7, 9, 11 and 12 not. The chip counts and lists 8 and 10 only.
do
	local env, _, ns = Boot("reskin", Rows(12, Set(1, 2, 3, 4, 5, 6, 8, 10)))
	local chip = Chip(ns)
	assert(Shown(chip) and chip.text:GetText() == "+2", "two hidden active buffs, got " .. tostring(chip.text:GetText()))
	assert(Names(Hover(env, ns), 2) == "Spell 108|Spell 110", "the hover skips the inactive slots, got " .. Names(Hover(env, ns), 2))
end

-- Secret auras: aura data turns secret in a boss fight, and Blizzard's item answers IsActive with a secret for half the
-- row. The module never compares it: an item Blizzard shows takes a socket. 2, 4, 5, 8-12 active, 1, 3, 6, 7 not.
do
	local env, _, ns, viewer = Boot("reskin", Rows(12, Set(2, 4, 5, 8, 9, 10, 11, 12)))
	env._cdm.secretAuras = true
	for i, item in ipairs(viewer._items) do
		if i % 2 == 1 then
			item.IsActive = function(self)
				return env.Secret(self._active)
			end
		end
	end
	viewer:Layout()
	env.RunTimers()
	Visible(viewer, Span(1, 10), "the first six active buffs and the empty slots between them")
	Folded(viewer, { 11, 12 }, "past the sixth active buff")
	local chip = Chip(ns)
	assert(Shown(chip) and chip.text:GetText() == "+2", "secret auras still count from the shown state, got " .. tostring(chip.text:GetText()))
	assert(InSlot(env, viewer, chip, 11), "the chip fills the eleventh slot")
	assert(Names(Hover(env, ns), 2) == "Spell 111|Spell 112", "the hover lists 11 and 12, got " .. Names(Hover(env, ns), 2))
	C.Clean(env, FORBIDDEN)
end

-- Hide When Inactive off: Blizzard shows every tracked buff, active or not. IsActive decides the sockets, so an
-- inactive icon takes none and the active 7-10 show; slots 11 and 12 fold, and no chip stands.
do
	local env, _, ns, viewer = Boot("reskin", Rows(12, Set(7, 8, 9, 10)), false)
	assert(viewer._items[1]:IsShown(), "with Hide When Inactive off Blizzard shows an inactive buff")
	Visible(viewer, Span(1, 10), "the active buffs and the inactive icons before them")
	Folded(viewer, { 11, 12 }, "inactive icons past the last active buff")
	assert(not Shown(Chip(ns)), "four active buffs need no chip")
	C.Clean(env, FORBIDDEN)
end

-- Hide When Inactive off and IsActive secret (codex review): Blizzard shows every icon, so the shown state cannot tell
-- an active buff from an inactive one either. The module caps nothing: the whole row shows and no chip stands.
do
	local env, _, ns, viewer = Boot("reskin", Rows(12, Set(7, 8, 9, 10)), false)
	for _, item in ipairs(viewer._items) do
		item.IsActive = function(self)
			return env.Secret(self._active)
		end
	end
	viewer:Layout()
	env.RunTimers()
	Visible(viewer, Span(1, 12), "with nothing to tell active from inactive the row")
	assert(not Shown(Chip(ns)), "and no chip")
	-- Readable activity caps the row again.
	for _, item in ipairs(viewer._items) do
		item.IsActive = function(self)
			return self._active ~= false
		end
	end
	viewer:Layout()
	env.RunTimers()
	Folded(viewer, { 11, 12 }, "readable activity caps the row again")
	C.Clean(env, FORBIDDEN)
end

-- Hide When Inactive off with two active buffs: the row keeps its six sockets, so inactive icons never run on.
do
	local _, _, ns, viewer = Boot("reskin", Rows(16, Set(1, 2)), false)
	Visible(viewer, Span(1, 6), "the grid's six sockets")
	Folded(viewer, Span(7, 16), "inactive icons past the grid")
	assert(not Shown(Chip(ns)), "no active buff is hidden, so no chip")
end

-- Apply sizes Blizzard's row for the grid and its chip: sixteen tracked buffs are seven slots, not sixteen; a
-- short list keeps its own count.
do
	local _, K, ns = Boot()
	local count = ns.Data.Count
	ns.Data.Count = function(group)
		return group == "buffs" and 16 or 6
	end
	assert(K.Setup.EditMode.Tracked("buffs") == 7, "Apply lays the restyled row out for six sockets and the chip, got " .. tostring(K.Setup.EditMode.Tracked("buffs")))
	assert(K.Setup.EditMode.Tracked("bars") == 6, "the bars keep their count")
	ns.Data.Count = function()
		return 4
	end
	assert(K.Setup.EditMode.Tracked("buffs") == 4, "four tracked buffs need four slots")
	-- A mirror that failed and fell back to the restyle is capped too, so Apply counts the capped row (codex review).
	ns.Data.Count = function()
		return 16
	end
	local restyles = ns.Path.Restyles
	ns.Path.Restyles = function()
		return false
	end
	ns.Path.Fail("buffs", "a test failure")
	assert(ns.Path.Get("buffs") == "reskin", "the failed mirror restyles")
	assert(K.Setup.EditMode.Tracked("buffs") == 7, "a fallen-back row counts as capped, got " .. tostring(K.Setup.EditMode.Tracked("buffs")))
	ns.Path.Restyles = restyles
	ns.Data.Count = count
end

-- The KstyleUI icons path draws its own row; Blizzard's faded viewer keeps every item as it is.
do
	local _, _, ns, viewer = Boot("mirror")
	assert(viewer._items[9]:GetAlpha() == 1, "the mirror path leaves Blizzard's items alone")
	assert(not Shown(Chip(ns)), "the mirror path shows no native chip")
end

print("ok")
