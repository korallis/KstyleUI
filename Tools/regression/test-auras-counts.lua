-- test-auras-counts.lua: the Blessings card with many auras: 0, 8, 24 and 40 buffs beside 12 debuffs; the card grows by whole rows to its rows cap and stays in the rail column and on screen, debuffs stay visible with dispellable ones first, and the rest sit behind a "+N" in the cap, counted by the engine's own layout so it stays true in combat, with the full list a hover or a click away even while the counts are secret.
local A = dofile("Tools/regression/auras_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.5)
end

local function same(r, q)
	return near(r.left, q.left) and near(r.right, q.right) and near(r.bottom, q.bottom) and near(r.top, q.top)
end

local env, K, ns = A.New({ layout = true })
local slots = { HELPFUL = {}, HARMFUL = {} }
env.C_UnitAuras = {
	GetAuraSlots = function(unit, filter, maxSlots, continuation)
		check(unit == "player", "the card counts the player's auras")
		local list = slots[filter] or {}
		local from = (continuation or 0) + 1
		local out, last = {}, math.min(#list, from + (maxSlots or #list) - 1)
		for i = from, last do
			out[#out + 1] = list[i]
		end
		return last < #list and last or nil, unpack(out)
	end,
}
K.Modules.Enable("Auras")
env.RunTimers()
local Model, Panel = ns.Model, ns.Panel
local settings = K.Store.Module("Auras")
local buffs, debuffs = Model.Group(settings, "buffs"), Model.Group(settings, "debuffs")
local root = K.Scale.Root()
local screen = Geometry.Rect(root, root)

local desc, ddesc = Panel.Group("buffs"), Panel.Group("debuffs")
local helpful = A.Container(env, "HELPFUL")
local harmful = A.Container(env, "HARMFUL")

local function fill(list, n)
	for i = #list, 1, -1 do
		list[i] = nil
	end
	for i = 1, n do
		list[i] = i
	end
end

-- The engine sizes a container to the rows it holds: n tiles in the group's columns, each the element size.
local function size(container, group, n, capacity)
	local shown = math.min(n, capacity)
	local timer = Model.Timer(settings)
	local w, h = Model.ElementSize(group, timer)
	local columns = math.min(shown, group.columns)
	local rows = math.ceil(shown / group.columns)
	container:SetSize(columns > 0 and columns * w + (columns - 1) * group.spacing or 0, rows * h + math.max(0, rows - 1) * group.rowSpacing)
end

local function rect(object)
	local r, why = Geometry.Rect(object, root)
	check(r, tostring(why))
	return r
end

-- Debuffs stay visible and come dispellable first: the debuff container runs two groups on the engine, the
-- dispellable types first, each sorted by the engine's unit-frame debuff order (boss and priority debuffs,
-- then your own first), and two rows by default, so twelve debuffs show whole.
check(debuffs.rows == 2 and debuffs.columns == 6, "twelve debuffs show by default: two rows of six, got " .. debuffs.rows .. " x " .. debuffs.columns)
check(debuffs.sort == "priority", "debuffs sort by priority by default")
check(Model.Sort("priority") == "UnitFrameDebuff", "priority is the engine's unit-frame debuff order")
check(#harmful._order == 2 and harmful._order[1] == "dispel" and harmful._order[2] == "debuffs", "the debuff container runs a dispellable group, then the rest: " .. table.concat(harmful._order, ","))
local dispel, rest = harmful._groups.dispel, harmful._groups.debuffs
check(dispel.candidateFilters and dispel.candidateFilters.includeDispelTypes and dispel.candidateFilters.includeDispelTypes.Magic, "the first group admits the dispellable types")
check(rest.candidateFilters and rest.candidateFilters.excludeDispelTypes and rest.candidateFilters.excludeDispelTypes.Magic, "the second group leaves them out")
check(dispel.maxFrameCount >= 12 and rest.maxFrameCount >= 12, "each debuff group may show every debuff of the default rows")
check(dispel.layout and dispel.layout.groupSpacing == dispel.layout.elementSpacing, "the groups flow on as one row sequence")

-- The counts: the cap's "+N" is counted by hidden containers on the engine, one pair per row group (buffs, then
-- the dispellable debuffs, then the rest), so the count is what the rows do not show and no count is ever read.
-- Twelve debuffs always, none of them dispellable here; the buffs vary.
local capacity = Model.Capacity(buffs, 0)
check(capacity == 12, "two rows of six buffs by default")
local cap = desc.card.cap
local counter = desc.card.counter
check(counter and #counter.pairs == 3, "the cap counts three groups: buffs, dispellable debuffs and the rest")
check(counter.pairs[1].a._groups.count.filter == "HELPFUL" and counter.pairs[3].a._groups.count.filter == "HARMFUL", "with the rows' own filters")
check(counter.pairs[2].a._groups.count.candidateFilters.includeDispelTypes.Magic, "the dispellable pair counts what the dispellable row takes")
local function count()
	return (A.Chip(counter))
end
local function state(n, d, dispellable)
	d = d or 12
	fill(slots.HELPFUL, n)
	fill(slots.HARMFUL, d)
	size(helpful, buffs, n, capacity)
	size(harmful, debuffs, d, 12)
	A.Ghosts(counter, { n, dispellable or 0, d - (dispellable or 0) })
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
end
local rail = K.Setup.Layouts.Element("auras.buffs")
for _, n in ipairs({ 0, 8, 24, 40 }) do
	state(n)
	local host = rect(desc.host)
	check(desc.host:IsShown(), n .. " buffs beside twelve debuffs: the card shows")
	check(near(host.right - host.left, rail.width), n .. " buffs: the card keeps the rail width: " .. tostring(host.right - host.left))
	check(host.bottom >= screen.bottom - 0.5 and host.top <= screen.top + 0.5, n .. " buffs: the card stays on screen: " .. tostring(host.bottom))
	for _, object in ipairs({ helpful, harmful, ddesc.dock, cap.frame }) do
		local r = rect(object)
		check(r.left >= host.left - 0.5 and r.right <= host.right + 0.5 and r.bottom >= host.bottom - 0.5 and r.top <= host.top + 0.5,
			n .. " buffs: the card's contents stay inside the card: " .. tostring(r.left) .. ".." .. tostring(r.right) .. ", " .. tostring(r.bottom) .. ".." .. tostring(r.top) .. " in " .. tostring(host.left) .. ".." .. tostring(host.right) .. ", " .. tostring(host.bottom) .. ".." .. tostring(host.top))
	end
	if n == 0 then
		check(not desc.card.rule:IsShown() and near(rect(ddesc.dock).top, rect(helpful).bottom), "no buffs: the debuff rows start where the buff rows would, with no hairline over nothing")
	else
		check(near(rect(ddesc.dock).top, rect(helpful).bottom - 17), n .. " buffs: the debuff rows hang under the buff rows and the hairline")
	end
	local over = math.max(0, n - capacity)
	if over > 0 then
		check(count() == "+" .. over, n .. " buffs: the cap counts the rest: " .. tostring(count()))
	else
		check(count() == nil, n .. " buffs: no count when every buff shows: " .. tostring(count()))
	end
	check(cap.frame.count:GetAlpha() == 0, "the cap's own count only keeps the rule clear of the engine's labels")
	local window, capRect = rect(counter.window), rect(cap.frame)
	check(near(window.right, capRect.right) and window.left > (capRect.left + capRect.right) / 2, n .. " buffs: the count sits at the cap's right end, clear of the title")
end
local two = rect(desc.host)
state(8)
check(near(rect(desc.host).top - rect(desc.host).bottom, two.top - two.bottom), "eight buffs fill two rows as forty do: the card grows by whole rows to its cap, never past it")

-- The cap opens the full list on hover: a glass flyout beside the card holding every buff and debuff on a second
-- pair of engine groups at a compact tile, left of the card and on screen, that closes when the pointer leaves
-- both. It is built with the card, so it opens in combat, where no container may be made.
state(40)
check(desc.card.more and not desc.card.more:IsShown(), "the full list is built and waits hidden")
check(desc.card.moreButton:IsShown() and same(rect(desc.card.moreButton), rect(cap.frame)), "the whole cap takes the pointer, count or no count")
A.W.Enter(desc.card.moreButton)
env.RunTimers()
local more = desc.card.more
check(more and more:IsShown(), "hovering the count opens the full list")
local full = A.Container(env, "HELPFUL", 2)
check(full and full ~= helpful, "the full list runs its own buff container")
local fullHarm = A.Container(env, "HARMFUL", 2)
check(fullHarm and fullHarm ~= harmful, "and its own debuff container")
local fullGroup = full._groups.buffs
check(fullGroup.maxFrameCount >= 40, "the full list holds at least forty buffs: " .. tostring(fullGroup.maxFrameCount))
check(fullGroup.layout.elementWidth < buffs.iconSize, "at a compact tile: " .. tostring(fullGroup.layout.elementWidth))
-- The engine sizes the full list's containers to their rows; the flyout's glass follows them by anchors alone.
local function rows(container, n)
	local layout = container._groups[container._order[1]].layout
	local columns = Model.MORE.columns
	local r = math.ceil(n / columns)
	container:SetSize(math.min(n, columns) * layout.elementWidth + (math.min(n, columns) - 1) * layout.elementSpacing, r * layout.elementHeight + math.max(0, r - 1) * layout.lineSpacing)
end
rows(full, 40)
rows(fullHarm, 12)
local flyout = rect(more)
local tall = flyout.top - flyout.bottom
check(near(rect(full).top, flyout.top - 20 - K.Widgets.SECTION_CAP_HEIGHT - 8) and rect(fullHarm).bottom > flyout.bottom, "the buffs start under the list's own cap, and the debuffs end inside the glass")
check(more._template == "DisableUntrustedLayoutScriptsTemplate", "the flyout follows the engine's containers, so it carries the layout template")
rows(fullHarm, 20)
check(rect(more).top - rect(more).bottom > tall, "a debuff row gained, in combat or out, grows the glass with it")
rows(fullHarm, 12)
-- The full list wears the card's language: its own cap and the same "+N", past its own caps.
local moreCounter = desc.card.moreCounter
check(desc.card.moreCap.frame:IsShown() and moreCounter and moreCounter.window:IsShown(), "the full list has its own cap and count")
A.Ghosts(moreCounter, { 40, 0, 12 })
check(A.Chip(moreCounter) == nil, "forty buffs and twelve debuffs all show in the full list: no count")
A.Ghosts(moreCounter, { Model.MORE.buffs + 4, 0, 12 })
check(A.Chip(moreCounter) == "+4", "past its own cap the full list counts the rest as the card does: " .. tostring(A.Chip(moreCounter)))
-- The screen clamp moves the glass and its contents together: the clamped frame is the one they all hang from, and
-- its clamp rect reaches as far down as the fullest list could.
local function last(frame, method)
	local found
	for _, call in ipairs(frame._calls) do
		if call.method == method then
			found = call.args
		end
	end
	return found
end
local sheet = desc.card.moreSheet
check(select(2, more:GetPoint(1)) == sheet and select(2, desc.card.moreCap.frame:GetPoint(1)) == sheet, "the glass and the list's cap hang from one frame")
check(last(sheet, "SetClampedToScreen") and last(sheet, "SetClampedToScreen")[1] == true, "that frame is the one the screen clamps")
check(not last(more, "SetClampedToScreen"), "the glass is not clamped on its own, so it never leaves its contents behind")
local insets = last(sheet, "SetClampRectInsets")
check(insets and insets[4] < -(tall + 100), "the clamp reaches below the frame by the fullest list's height: " .. tostring(insets and insets[4]))
flyout = rect(more)
check(flyout.right <= rect(desc.host).left + 0.5, "the full list opens left of the card, toward the screen's centre")
check(flyout.left >= screen.left - 0.5 and flyout.bottom >= screen.bottom - 0.5 and flyout.top <= screen.top + 0.5, "and stays on screen")
check(near(flyout.top, rect(desc.host).top), "level with the card's top")
A.W.Leave(desc.card.moreButton)
check(more:IsShown(), "leaving the count keeps the list open for a moment")
env.RunTimers()
check(not more:IsShown(), "and it closes once the pointer has left")
A.W.Enter(desc.card.moreButton)
A.W.Leave(desc.card.moreButton)
A.W.Enter(more)
env.RunTimers()
check(more:IsShown(), "moving onto the list keeps it open")
A.W.Leave(more)
env.RunTimers()
check(not more:IsShown(), "leaving the list closes it")

-- Thirteen debuffs: each debuff group holds its rows, so the count is what each group could not show.
state(8, 13)
check(count() == "+1", "a debuff past the rows counts: " .. tostring(count()))
state(8, 13, 3)
check(count() == nil, "three dispellable and ten others fit their groups: nothing is hidden, so no count: " .. tostring(count()))
state(8, 30, 14)
check(count() == "+6", "two past the dispellable group and four past the rest: +6, got " .. tostring(count()))
state(40, 36)
check(count() == "+52", "twenty-eight buffs and twenty-four debuffs past the rows: the count reaches +52 and never drops out, got " .. tostring(count()))
state(40)

-- Dispellable first switches off and on without a reload: the dispellable group stands down and the rest takes
-- every debuff, then both come back with their filters.
K.Options.Write("Auras", "debuffs.dispelFirst", false)
env.RunTimers()
check(dispel.enabled == false and rest.enabled == true, "off: the dispellable group stands down")
check(rest.candidateFilters == nil, "and the rest group admits every debuff")
K.Options.Write("Auras", "debuffs.dispelFirst", true)
env.RunTimers()
check(dispel.enabled == true and rest.candidateFilters and rest.candidateFilters.excludeDispelTypes, "on: both groups and their filters return")

-- The full list follows the settings: a new timer size reaches its groups' layout and buttons.
K.Options.Write("Auras", "timer.size", 16)
env.RunTimers()
local fullLayout = full._groups.buffs.layout
check(fullLayout.elementHeight > fullGroup.layout.elementWidth, "the full list's tiles grow for the larger timer: " .. tostring(fullLayout.elementHeight))
check(near(fullLayout.elementHeight, Model.MORE.iconSize + Model.TimerArea(Model.Timer(K.Store.Module("Auras"))), 1), "to the compact tile plus the new timer area")
K.Options.Write("Auras", "timer.size", 12)
env.RunTimers()

-- Undocked, the debuffs are their own element and the cap counts buffs alone.
K.Options.Write("Auras", "card.docked", false)
env.RunTimers()
check(counter.pairs[2].a._groups.count.enabled == false and counter.pairs[3].a._groups.count.enabled == false, "undocked: the debuff pairs stand down")
state(14, 30, 14)
check(count() == "+2", "undocked: only the two buffs past the rows count: " .. tostring(count()))
K.Options.Write("Auras", "card.docked", true)
env.RunTimers()
state(40)

-- In a restricted pull the counts are secret: the cap keeps counting through the engine's layout, never a stale
-- number, and the full list still opens and pins. From eight buffs and no debuffs to forty and twelve.
state(8, 0)
check(count() == nil, "eight buffs fit: no count")
local slotsAsked = 0
local getSlots = env.C_UnitAuras.GetAuraSlots
env.C_UnitAuras.GetAuraSlots = function(...)
	slotsAsked = slotsAsked + 1
	return getSlots(...)
end
env.SetCombat(true)
env._aurasSecret = true
state(40, 12)
check(slotsAsked == 0, "the card asks the game for no count in combat")
check(count() == "+28", "in the pull the cap counts the twenty-eight buffs the rows cannot show: " .. tostring(count()))
check(desc.host:IsShown() and ddesc.host:IsShown(), "and the card and its debuff rows show")
state(20, 12)
check(count() == "+8", "buffs fall away in the pull: +8, never the +28 from before: " .. tostring(count()))
state(10, 12)
check(count() == nil, "and the count goes when the rows hold them all")
state(40, 12)
A.W.Enter(desc.card.moreButton)
check(more:IsShown(), "hovering the cap opens the full list in combat")
A.W.Click(desc.card.moreButton)
A.W.Leave(desc.card.moreButton)
env.RunTimers()
check(more:IsShown() and desc.card.pinned, "a click pins it: leaving the cap keeps it open")
A.W.Click(desc.card.moreButton)
env.RunTimers()
check(not more:IsShown() and not desc.card.pinned, "a second click unpins and closes it")
A.W.Click(desc.card.moreButton)
check(more:IsShown(), "a click alone opens and pins it")
A.W.Click(desc.card.moreButton)
env.SetCombat(false)
env._aurasSecret = false
state(0, 0)
check(count() == nil, "out of combat with nothing to count, no count")

check(#env._errors == 0, tostring(env._errors[1]))
check(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("auras counts ok")
