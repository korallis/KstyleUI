-- test-cooldowns-native-cap.lua: on the restyled path Blizzard's tracked buff icon row stops at the module's grid
-- (columns by rows): items in slots past it fade out and stop taking the mouse, and a "+N" chip in the next slot
-- counts the shown ones, so a high count never runs down the screen (round 6, Grok #1, Muse). Apply sizes the row for
-- the grid and the chip, not for every tracked buff.
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
local function Items()
	local items = {}
	for i = 1, 16 do
		items[i] = { id = 100 + i, icon = 1000 + i, name = "Buff " .. i, left = ACTIVE[i] and 10 + i or nil, total = 30 }
	end
	return items
end

local function Format(seconds)
	return seconds .. "s"
end

local function Boot(path)
	local env, K, ns = C.New({ setup = C.Game })
	K.Options.Write("Cooldowns", "path", path or "reskin")
	C.Enable(env, K)
	local viewer = C.Native(env, "BuffIconCooldownViewer", Entry(), Items(), Format)
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

-- The default grid is six sockets: items 1-6 keep their alpha, 7-16 fade out and stop taking the mouse.
do
	local env, K, ns, viewer = Boot()
	local cap = ns.Cap.Size()
	assert(cap == 6, "the native row stops at the grid's six sockets, got " .. tostring(cap))
	for i, item in ipairs(viewer._items) do
		if i <= cap then
			assert(item:GetAlpha() == 1, "slot " .. i .. " stays visible")
		else
			assert(item:GetAlpha() == 0, "slot " .. i .. " past the grid fades out, alpha " .. tostring(item:GetAlpha()))
			assert(Mouse(item) == false, "slot " .. i .. " past the grid takes no mouse")
		end
	end
	-- Shown past the grid: 7, 9 and 10.
	local chip = Chip(ns)
	assert(Shown(chip), "a chip counts the buffs past the grid")
	assert(chip.text:GetText() == "+3", "the chip counts the three shown buffs past the grid, got " .. tostring(chip.text:GetText()))
	-- The chip stands in the seventh slot, one socket past the last visible one, on the row's open (left) side.
	local c = assert(Geometry.Rect(chip, env.UIParent))
	local s7 = assert(Geometry.Rect(viewer._items[7], env.UIParent))
	assert(W.Near(c.left, s7.left) and W.Near(c.right, s7.right) and W.Near(c.bottom, s7.bottom) and W.Near(c.top, s7.top), "the chip fills the seventh slot")
	local s6 = assert(Geometry.Rect(viewer._items[6], env.UIParent))
	assert(c.right <= s6.left, "the chip stands left of the last visible socket")

	-- An item past the grid that turns inactive drops out of the count on its next shown-state update.
	viewer._items[9]._active = false
	viewer._items[9]:UpdateShownState()
	env.RunTimers()
	assert(chip.text:GetText() == "+2", "an inactive buff leaves the count, got " .. tostring(chip.text:GetText()))
	for _, i in ipairs({ 7, 10 }) do
		viewer._items[i]._active = false
		viewer._items[i]:UpdateShownState()
	end
	env.RunTimers()
	assert(not Shown(chip), "with nothing shown past the grid, the chip hides")

	-- A secret shown state is never compared: the chip says "+" and counts nothing.
	local item = viewer._items[8]
	item.IsShown = function()
		return env.Secret(true)
	end
	item:UpdateShownState()
	env.RunTimers()
	assert(Shown(chip) and chip.text:GetText() == "+", "a secret shown state shows the chip as +, got " .. tostring(chip.text:GetText()))
	item.IsShown = nil

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
	assert(viewer._items[7]:GetAlpha() == 0 and viewer._items[9]:GetAlpha() == 0, "a relayout fades the slots past the grid")
	assert(Chip(ns).text:GetText() == "+3", "a relayout counts again")

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
