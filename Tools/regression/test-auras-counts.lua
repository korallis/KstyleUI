-- test-auras-counts.lua: the aura rows with many auras at the owner's screen (2383 x 1540 at UI scale 768/1080, on the canvas the live root gives): 0, 2, 8, 24 and 40 buffs beside 12 debuffs. The rows never grow past their cap, the debuff rows hang under the buff rows with a gap, nothing overlaps another element of any preset, the rest reads "+N" on the last cell, counted by the engine's own layout so it stays true in combat, and no count is ever read from the game in a pull.
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

local COUNTS = { 0, 2, 8, 24, 40 }
local DEBUFFS = 12

local env, K, ns = A.New({ width = 2383, height = 1540, uiScale = 768 / 1080 })
K.Modules.Enable("Auras")
env.RunTimers()
local Model, Panel = ns.Model, ns.Panel
local Layouts = K.Setup.Layouts
local settings = K.Store.Module("Auras")
local buffs = Model.Group(settings, "buffs")
local root = K.Scale.Root()
local rw, rh = K.Layout.RootSize()
check(near(rw / rh, 2383 / 1540, 0.01), "the root has the owner's aspect: " .. tostring(rw) .. " x " .. tostring(rh))
local desc, ddesc = Panel.Group("buffs"), Panel.Group("debuffs")
local helpful = A.Container(env, "HELPFUL")
local harmful = A.Container(env, "HARMFUL")

local function rect(object)
	local r, why = Geometry.Rect(object, root)
	check(r, tostring(why))
	return r
end

-- The engine sizes a container to the rows it holds: n tiles in the group's columns, each the element size, on the
-- whole pixels the row's own context snapped them to.
local function size(container, row, n)
	local ctx, group = row.ctx, row.ctx.group
	local shown = math.min(n, Model.Capacity(group, 0))
	local columns = math.min(shown, group.columns)
	local rows = math.ceil(shown / group.columns)
	container:SetSize(columns > 0 and columns * ctx.width + (columns - 1) * ctx.spacing or 0, rows * ctx.height + math.max(0, rows - 1) * ctx.rowSpacing)
end

local function overlap(r, s)
	return r.left < s.right and s.left < r.right and r.bottom < s.top and s.bottom < r.top
end

local function state(n, d)
	size(helpful, desc, n)
	size(harmful, ddesc, d or DEBUFFS)
	A.Counters(ns, { n, 0, d or DEBUFFS })
	env.RunTimers()
end

local function count(chip)
	return (A.Chip(chip))
end

local capacity = Model.Capacity(buffs, 0)
check(capacity == 10, "one row of ten by default")
local slotsAsked = 0
env.C_UnitAuras = {
	GetAuraSlots = function()
		slotsAsked = slotsAsked + 1
		return nil
	end,
}

for _, name in ipairs(Layouts.Names()) do
	local layout = Layouts.Get(name)
	for _, key in ipairs({ "auras.buffs", "auras.debuffs" }) do
		local position = layout[key]
		check(K.Layout.Update(key, { anchor = position.anchor, x = position.x, y = position.y }))
	end
	env.RunTimers()
	local others = {}
	local canvasH = Layouts.HEIGHT
	local canvasW = canvasH * rw / rh
	local dx, dy = canvasW - rw, canvasH - rh
	for _, element in ipairs(Layouts.ELEMENTS) do
		local key = element.key
		if key ~= "auras.buffs" and key ~= "auras.debuffs" then
			local w, h = Layouts.Footprint(name, key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h }, layout[key], canvasW, canvasH)
			others[key] = { left = l, bottom = b, right = r, top = t }
		end
	end
	for _, n in ipairs(COUNTS) do
		state(n)
		local label = string.format("%s, %d buffs and %d debuffs", name, n, DEBUFFS)
		check(desc.host:IsShown() and ddesc.host:IsShown(), label .. ": both rows show")
		local bh, dh = rect(desc.holder), rect(ddesc.holder)
		local brows, drows = rect(helpful), rect(harmful)
		check(brows.right <= bh.right + 0.5 and brows.top <= bh.top + 0.5 and brows.left >= bh.left - 0.5 and brows.bottom >= bh.bottom - 0.5, label .. ": the buff rows stay inside their element")
		check(drows.right <= dh.right + 0.5 and drows.top <= dh.top + 0.5 and drows.left >= dh.left - 0.5 and drows.bottom >= dh.bottom - 0.5, label .. ": the debuff rows stay inside their element")
		check(near(brows.right, bh.right) and near(brows.top, bh.top), label .. ": the rows end at the element's top right, beside the minimap's edge, whatever they hold")
		check(near(drows.right, brows.right), label .. ": the debuff row ends at the same x as the buff row")
		check(dh.top <= bh.bottom - 7, label .. ": the debuff rows hang a gap under the buff rows (8, less a pixel of snapping)")
		for _, r in ipairs({ bh, dh }) do
			check(r.left >= -0.5 and r.right <= rw + 0.5 and r.bottom >= -0.5 and r.top <= rh + 0.5, label .. ": on screen")
		end
		local function lift(r)
			return { left = r.left + dx, right = r.right + dx, bottom = r.bottom + dy, top = r.top + dy }
		end
		for key, other in pairs(others) do
			local lb, ld = lift(bh), lift(dh)
			check(not overlap(lb, other), string.format("%s: the buff rows (%.0f,%.0f-%.0f,%.0f) overlap %s (%.0f,%.0f-%.0f,%.0f)", label, lb.left, lb.bottom, lb.right, lb.top, key, other.left, other.bottom, other.right, other.top))
			check(not overlap(ld, other), string.format("%s: the debuff rows (%.0f,%.0f-%.0f,%.0f) overlap %s", label, ld.left, ld.bottom, ld.right, ld.top, key))
		end
		local over = math.max(0, n - capacity)
		if over > 0 then
			check(count(desc.chip) == "+" .. (over + 1), label .. ": the last cell counts the rest: " .. tostring(count(desc.chip)))
			local window = rect(desc.chip.window)
			check(near(window.right, bh.right) and near(window.bottom, bh.bottom + desc.ctx.foot) and near(window.top, bh.top), label .. ": the count is the last cell's tile, the row's right end, level with the row")
		else
			check(count(desc.chip) == nil, label .. ": no count when every buff shows: " .. tostring(count(desc.chip)))
		end
		check(count(ddesc.chip) == "+3", label .. ": twelve debuffs read +3 on the tenth cell: " .. tostring(count(ddesc.chip)))
	end
end
check(slotsAsked == 0, "the rows never ask the game for an aura count")

-- Text lands on whole physical pixels (#210): the timer and count go through Widgets.ApplyFont, so at the owner's
-- 1.426 px per unit an 11-unit timer snaps to a whole pixel count and its shadow is one physical pixel, not one unit.
do
	local Widgets = K.Widgets
	local entry = desc.buttons[1]
	local ruler = Widgets.FontString(desc.host, "OVERLAY")
	Widgets.ApplyFont(ruler, (K.Tokens.Font("body")), 11, "")
	local _, want = ruler:GetFont()
	local wx, wy = ruler:GetShadowOffset()
	local _, timerSize = entry.timer:GetFont()
	local sx, sy = entry.timer:GetShadowOffset()
	check(near(want, Widgets.FontSize(entry.timer, 11), 1e-6) and not near(want, 11, 1e-6), "the snapped size differs from the raw 11 on this screen: " .. tostring(want))
	check(near(timerSize, want, 1e-6), "the timer takes the snapped size, got " .. tostring(timerSize) .. " for " .. tostring(want))
	check(near(sx, wx, 1e-6) and near(sy, wy, 1e-6), "and the one-pixel shadow, got " .. tostring(sx) .. ", " .. tostring(sy) .. " for " .. tostring(wx) .. ", " .. tostring(wy))
	local _, countSize = entry.count:GetFont()
	check(near(countSize, Widgets.FontSize(entry.count, 10), 1e-6), "the count snaps too, got " .. tostring(countSize))
end

-- In a restricted pull the counts stay live: the engine's layout carries them, so the number follows the auras.
env.SetCombat(true)
env._aurasSecret = true
state(40)
check(count(desc.chip) == "+31", "in the pull the last cell counts the thirty past the row, and itself: " .. tostring(count(desc.chip)))
state(20)
check(count(desc.chip) == "+11", "buffs fall away in the pull: +11, never the +31 from before: " .. tostring(count(desc.chip)))
state(10)
check(count(desc.chip) == nil, "and the count goes when the row holds them all")
state(8, 30)
check(count(ddesc.chip) == "+21", "thirty debuffs: twenty-one on the last cell: " .. tostring(count(ddesc.chip)))
env.SetCombat(false)
env._aurasSecret = false
state(0, 0)
check(count(desc.chip) == nil and count(ddesc.chip) == nil, "out of combat with nothing to count, no count")

check(#env._errors == 0, tostring(env._errors[1]))
check(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("auras counts ok")
