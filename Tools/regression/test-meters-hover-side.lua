-- test-meters-hover-side.lua: a source row's spell split opens inside the meter card, under the hovered row, spanning the row's width, and above a row near the card's bottom, so it never leaves the window on either rail; the card's own tooltip still opens toward the middle of the screen.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Spell(id, total, perSecond)
	return {
		spellID = id, totalAmount = total, amountPerSecond = perSecond, creatureName = "", overkillAmount = 0,
		isAvoidable = false, isDeadly = false,
		combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 },
	}
end

local env, K, ns = M.New({ game = function(e)
	e._group = { raid = false, size = 2 }
	e._spells[100] = { name = "Mortal Strike", icon = "Interface\\Icons\\ability_warrior_savageblow" }
end })
local sources = {}
for i, name in ipairs({ "Kragar", "Valerin", "Sylaen", "Thargor", "Lunara", "Brakk" }) do
	sources[i] = { name = name, classFilename = "WARRIOR", totalAmount = 3000 - i * 100, amountPerSecond = 30 - i, sourceDisplayType = 1, isLocalPlayer = i == 2, deathRecapID = 0, deathTimeSeconds = 0, sourceGUID = "Player-" .. name }
	env._sources["Player-" .. name] = { combatSpells = { Spell(100, 1800, 18), Spell(100, 900, 9), Spell(100, 300, 3) }, maxAmount = 1800, totalAmount = 3000 }
end
env._session = { combatSources = sources, maxAmount = 2900, totalAmount = 15900, durationSeconds = 30 }
M.Enable(env, K)
M.Tick(env)
local list = ns.Damage.list
local panel = list.panel
local root = K.Scale.Root()
assert(list.count == 6, "six sources show: " .. tostring(list.count))

local function Rect(frame)
	local rect, why = Geometry.Rect(frame, root)
	assert(rect, tostring(why))
	return rect
end

local function Hover(where, i)
	panel:ClearAllPoints()
	panel:SetSize(318, 190)
	panel:SetPoint(where, root, where, where == "RIGHT" and -28 or 28, 0)
	list.holder:ClearAllPoints()
	list.holder:SetSize(318, 190)
	list.holder:SetPoint(where, root, where, where == "RIGHT" and -28 or 28, 0)
	local row = list.rows[i].frame
	row._scripts.OnEnter(row)
	env.RunTimers()
	local split = list.split
	assert(split and split.frame:IsShown(), "the hovered row opens its split")
	assert(not K.Widgets.Tooltip():IsOwned(row), "and no tooltip")
	local s, r, p = Rect(split.frame), Rect(row), Rect(panel)
	-- The rows the split covers are held hidden while it is open, so nothing bleeds through its glass, and
	-- they come back when it closes.
	local covered, peeking = 0, 0
	for j = 1, list.count do
		if j ~= i then
			local other = Rect(list.rows[j].frame)
			local under = other.top <= s.top + 0.01 and other.bottom >= s.bottom - 0.01
			local crossing = not under and other.top > s.bottom and other.bottom < s.top
			if list.rows[j].frame:IsShown() then
				assert(not under, "a row under the split is hidden: row " .. j)
				if crossing then
					peeking = peeking + 1
				end
			else
				covered = covered + 1
			end
		end
	end
	assert(covered >= 3, "the split covers whole rows: " .. covered)
	assert(peeking == 0, "no row peeks out half-hidden under the split's edge")
	row._scripts.OnLeave(row)
	env.RunTimers()
	assert(not split.frame:IsShown(), "the split closes when the pointer leaves")
	for j = 1, list.count do
		assert(list.rows[j].frame:IsShown(), "every row shows again: row " .. j)
	end
	return s, r, p
end

for _, where in ipairs({ "RIGHT", "LEFT" }) do
	local s, r, p = Hover(where, 1)
	assert(s.left >= p.left - 0.01 and s.right <= p.right + 0.01, where .. ": the split stays inside the card's width: " .. s.left .. ".." .. s.right .. " in " .. p.left .. ".." .. p.right)
	assert(math.abs(s.left - r.left) < 0.01 and math.abs(s.right - r.right) < 0.01, where .. ": and spans the row's width")
	assert(s.top <= r.bottom + 0.01 and s.top > r.bottom - 8, where .. ": the first row's split hangs under the row: " .. s.top .. " vs " .. r.bottom)
	assert(s.bottom >= p.bottom - 0.01, where .. ": inside the card's bottom")
	local s6, r6 = Hover(where, list.count)
	assert(s6.bottom >= r6.top - 0.01 and s6.bottom < r6.top + 8, where .. ": the last row's split opens above the row, so it stays in the window: " .. s6.bottom .. " vs " .. r6.top)
	assert(s6.top <= p.top + 0.01, where .. ": inside the card's top")
end

-- A middle row of a full card has no room for the whole split on either side: the split takes the side with
-- more room, lists what fits there (the count line goes first, then the last spells), never covers the cap or
-- leaves the card, and never hides the row the pointer is on.
for _, i in ipairs({ 3, 4 }) do
	list.holder:ClearAllPoints()
	list.holder:SetSize(318, 190)
	list.holder:SetPoint("LEFT", root, "LEFT", 28, 0)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", list.holder, "TOPLEFT", 0, 0)
	panel:SetPoint("TOPRIGHT", list.holder, "TOPRIGHT", 0, 0)
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	assert(list.count == 6 and list.rows[6].frame:IsShown(), "a full card of six rows")
	local row = list.rows[i].frame
	row._scripts.OnEnter(row)
	env.RunTimers()
	local split = list.split
	assert(split.frame:IsShown(), "row " .. i .. " opens its split")
	local s, p = Rect(split.frame), Rect(panel)
	local contentTop = p.top - K.Widgets.Snap(panel, list:Top())
	assert(s.top <= contentTop + 0.01, "row " .. i .. ": the split stays under the cap: " .. s.top .. " vs " .. contentTop)
	assert(s.bottom >= p.bottom + list.pad - 0.01, "row " .. i .. ": and inside the card's bottom: " .. s.bottom .. " vs " .. p.bottom)
	assert(p.bottom >= Rect(list.holder).bottom - 0.01, "row " .. i .. ": the card grows no further than its holder")
	assert(row:IsShown(), "row " .. i .. ": the hovered row stays shown")
	local listed = 0
	for _, line in ipairs(split.lines) do
		if line.frame:IsShown() then
			listed = listed + 1
		end
	end
	assert(listed >= 1 and listed <= 3, "row " .. i .. ": lists what fits: " .. listed)
	row._scripts.OnLeave(row)
	env.RunTimers()
	for j = 1, list.count do
		assert(list.rows[j].frame:IsShown(), "row " .. i .. ": every row shows again after: " .. j)
	end
end

-- A card that hugs three rows grows to hold the split under its first row while the split is open, instead of
-- the split leaving the glass, and hugs its rows again when it closes. A refresh of the rows while the split is
-- open keeps the covered rows hidden and the card grown.
do
	list.holder:ClearAllPoints()
	list.holder:SetSize(318, 190)
	list.holder:SetPoint("LEFT", root, "LEFT", 28, 0)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", list.holder, "TOPLEFT", 0, 0)
	panel:SetPoint("TOPRIGHT", list.holder, "TOPRIGHT", 0, 0)
	env._session = { combatSources = { sources[1], sources[2], sources[3] }, maxAmount = 2900, totalAmount = 8400, durationSeconds = 30 }
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	assert(list.count == 3, "three sources")
	local hugged = Rect(panel)
	local row = list.rows[1].frame
	row._scripts.OnEnter(row)
	env.RunTimers()
	local s, p = Rect(list.split.frame), Rect(panel)
	assert(s.bottom >= p.bottom - 0.01 and s.top <= p.top + 0.01, "the split stays inside the card: " .. s.bottom .. " vs " .. p.bottom)
	assert(p.bottom < hugged.bottom - 1, "the card grew to hold it: " .. p.bottom .. " vs " .. hugged.bottom)
	assert(p.bottom >= Rect(list.holder).bottom - 0.01, "and no further than its holder")
	assert(not list.rows[2].frame:IsShown() and not list.rows[3].frame:IsShown(), "the rows under the split are hidden")
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
	assert(list.split.frame:IsShown(), "a refresh keeps the split open")
	assert(not list.rows[2].frame:IsShown(), "and the rows under it hidden")
	assert(math.abs(Rect(panel).bottom - p.bottom) < 0.01, "and the card grown")
	row._scripts.OnLeave(row)
	env.RunTimers()
	assert(math.abs(Rect(panel).bottom - hugged.bottom) < 0.01, "the card hugs its rows again when the split closes")
	assert(list.rows[2].frame:IsShown() and list.rows[3].frame:IsShown(), "and the rows show again")
end

local tip = K.Widgets.Tooltip()
panel:ClearAllPoints()
panel:SetSize(318, 190)
panel:SetPoint("RIGHT", root, "RIGHT", -28, 0)
list.panel._scripts.OnEnter(list.panel)
env.RunTimers()
if tip:IsOwned(list.panel) then
	assert(tip.anchor == "LEFT", "the card's own tooltip opens inward")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("test-meters-hover-side: ok")
