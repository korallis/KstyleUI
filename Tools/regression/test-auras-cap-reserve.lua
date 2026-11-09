-- test-auras-cap-reserve.lua: the Blessings cap never shows the "+00" it measures its count chip by. With two buffs the cap's own count stays hidden or empty through restyles, combat calm in and out, a theme change and a recount, no shown text on the card reads "+00", the rule stops clear of the chip, and thirty buffs still read "+18" on the engine's chip.
local A = dofile("Tools/regression/auras_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local env, K, ns = A.New({ layout = true })
local slots = { HELPFUL = {}, HARMFUL = {} }
env.C_UnitAuras = {
	GetAuraSlots = function(_, filter, maxSlots, continuation)
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
local buffs = Model.Group(settings, "buffs")
local desc = Panel.Group("buffs")
local helpful = A.Container(env, "HELPFUL")
local root = K.Scale.Root()
local cap, counter = desc.card.cap, desc.card.counter
check(counter, "the cap has its engine-counted chip")

local function state(n)
	for i = #slots.HELPFUL, 1, -1 do
		slots.HELPFUL[i] = nil
	end
	for i = 1, n do
		slots.HELPFUL[i] = i
	end
	local capacity = Model.Capacity(buffs, 0)
	local shown = math.min(n, capacity)
	local w, h = Model.ElementSize(buffs, Model.Timer(settings))
	local columns = math.min(shown, buffs.columns)
	local rows = math.ceil(shown / buffs.columns)
	helpful:SetSize(columns > 0 and columns * w + (columns - 1) * buffs.spacing or 0, rows * h + math.max(0, rows - 1) * buffs.rowSpacing)
	A.Counters(ns, { n, 0, 0 })
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	A.W.Settle(env)
end

-- The rule's left end follows the caption's text width, which the stubs do not draw, so its right end is read
-- from its RIGHT anchor: a point on the cap's own right edge, or on the shown count's left edge.
local function ruleRight()
	local rule = cap.frame.rule
	for i = 1, rule:GetNumPoints() do
		local point, rel, relPoint, x = rule:GetPoint(i)
		if point == "RIGHT" then
			check(relPoint == "RIGHT" or relPoint == "LEFT", "the rule's right end sits on a vertical edge")
			local r = assert(Geometry.Rect(rel, root))
			return (relPoint == "RIGHT" and r.right or r.left) + (x or 0)
		end
	end
	error("the rule has no right end")
end

-- The game draws a shown font string's text whatever alpha was set on it before a later SetTextColor, so the
-- only safe cap count is one that is hidden or holds no text.
local function quiet(step)
	local count = cap.frame.count
	local text = count:GetText()
	check(not count:IsShown() or text == nil or text == "", step .. ": the cap's own count is hidden or empty, got " .. tostring(text) .. (count:IsShown() and " shown" or " hidden"))
	for _, object in ipairs(A.Descendants(desc.host)) do
		if object:GetObjectType() == "FontString" and object:IsVisible() and object:GetText() == "+00" then
			error(step .. ": a shown text on the card reads +00", 2)
		end
	end
	check(A.Chip(counter) == nil, step .. ": two buffs fit, so the chip shows no count: " .. tostring(A.Chip(counter)))
	check(ruleRight() <= Geometry.Rect(counter.window, root).left + 0.5, step .. ": the rule stops clear of the count chip: " .. tostring(ruleRight()) .. " vs " .. tostring(Geometry.Rect(counter.window, root).left))
end

state(2)
quiet("two buffs")
K.Widgets.RestyleAll()
quiet("after a restyle of every widget")
cap:Restyle()
quiet("after the cap's own restyle")
env.SetCombat(true)
A.W.Settle(env)
quiet("in combat, calmed")
env.SetCombat(false)
env.RunTimers()
A.W.Settle(env)
quiet("out of combat, back from calm")
check(K.Theme.SetFontScale(1.2) == true, "a new text size is a theme change")
env.RunTimers()
A.W.Settle(env)
quiet("after a theme change")
state(2)
quiet("after a recount")

-- The engine chip still carries the real count: thirty buffs past twelve slots read "+18".
state(30)
check(A.Chip(counter) == "+18", "thirty buffs: the chip counts the eighteen the rows cannot show, got " .. tostring(A.Chip(counter)))
local count = cap.frame.count
check(not count:IsShown() or count:GetText() == nil or count:GetText() == "", "thirty buffs: the cap's own count stays hidden or empty")
K.Widgets.RestyleAll()
check(A.Chip(counter) == "+18", "a restyle keeps +18 on the chip, got " .. tostring(A.Chip(counter)))
state(2)
quiet("back to two buffs")

check(#env._errors == 0, tostring(env._errors[1]))
check(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("auras cap reserve ok")
