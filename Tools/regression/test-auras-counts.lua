-- test-auras-counts.lua: the Blessings card with many auras: 0, 8, 24 and 40 buffs beside 12 debuffs; the card grows by whole rows to its rows cap and stays in the rail column and on screen, debuffs stay visible with dispellable ones first, and the rest of the buffs sit behind a "+N" count that opens the full list on hover.
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

-- The counts: the card asks how many buffs and debuffs the player has, and the count over the rows cap reads
-- "+N" at the right of the cap. Twelve debuffs always; the buffs vary.
local capacity = Model.Capacity(buffs, 0)
check(capacity == 12, "two rows of six buffs by default")
local cap = desc.card.cap
local function state(n)
	fill(slots.HELPFUL, n)
	fill(slots.HARMFUL, 12)
	size(helpful, buffs, n, capacity)
	size(harmful, debuffs, 12, 12)
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
		check(cap.frame.count:IsShown() and cap.frame.count:GetText() == "+" .. over, n .. " buffs: the cap counts the rest: " .. tostring(cap.frame.count:GetText()))
	else
		check(not cap.frame.count:IsShown() or cap.frame.count:GetText() == "", n .. " buffs: no count when every buff shows: " .. tostring(cap.frame.count:GetText()))
	end
end
local two = rect(desc.host)
state(8)
check(near(rect(desc.host).top - rect(desc.host).bottom, two.top - two.bottom), "eight buffs fill two rows as forty do: the card grows by whole rows to its cap, never past it")

-- The "+N" count opens the full list on hover: a glass flyout beside the card holding every buff and debuff on a
-- second pair of engine groups at a compact tile, left of the card and on screen, that closes when the pointer
-- leaves both.
state(40)
check(desc.card.more == nil or not desc.card.more:IsShown(), "the full list waits unbuilt or hidden")
check(desc.card.moreButton:IsShown(), "the count takes the pointer")
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
local flyout = rect(more)
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

-- Thirteen debuffs: the rows show twelve of them, and the count says so, whichever group holds the thirteenth.
fill(slots.HELPFUL, 8)
fill(slots.HARMFUL, 13)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(cap.frame.count:GetText() == "+1", "a debuff past the rows counts: " .. tostring(cap.frame.count:GetText()))
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

-- In combat the counts are secret: the card keeps the count it last knew, and never hides.
env._aurasSecret = true
env.SetCombat(true)
fill(slots.HELPFUL, 0)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(cap.frame.count:GetText() == "+28", "in combat the count stays as last known: " .. tostring(cap.frame.count:GetText()))
check(desc.host:IsShown(), "and the card shows")
env.SetCombat(false)
env._aurasSecret = false
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(cap.frame.count:GetText() == "" or not cap.frame.count:IsShown(), "out of combat the count follows the auras again")

check(#env._errors == 0, tostring(env._errors[1]))
check(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("auras counts ok")
