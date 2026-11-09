-- test-cooldowns-overflow.lua: on the mirror path, many active tracked buffs keep every socket readable: the icon
-- row shows its whole grid and a "+N" chip grows it by one socket on its left, away from the essential cooldowns;
-- the bars show their count and a "+N" bar grows the stack by one slot on top, clear of the buff row under it;
-- active buffs come first in the Cooldown Manager's order, and hovering a chip lists the hidden buffs and time left.
local C = dofile("Tools/regression/cooldowns_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local EPS = 1e-3

local function inside(r, s)
	return r.left >= s.left - EPS and r.right <= s.right + EPS and r.bottom >= s.bottom - EPS and r.top <= s.top + EPS
end

local function apart(r, s)
	return r.right <= s.left + EPS or s.right <= r.left + EPS or r.top <= s.bottom + EPS or s.top <= r.bottom + EPS
end

local function mouse(frame)
	local call = C.W.LastCall(frame, "EnableMouse")
	return call ~= nil and call[1] == true
end

local function near(a, b)
	return math.abs(a - b) < EPS
end

local BUFFS, BARS = 12, 5
local cooldowns = C.Sample()
for i = 1, BUFFS do
	cooldowns[500 + i] = { spellID = 5000 + i, category = C.CATEGORY.TrackedBuff, selfAura = true, hasAura = true }
end
for i = 1, BARS do
	cooldowns[600 + i] = { spellID = 6000 + i, category = C.CATEGORY.TrackedBar, selfAura = true, hasAura = true }
end

local env, K, ns = C.New({ setup = C.Game, cooldowns = cooldowns })
local cdm = env._cdm
local function activate(spell, instance, left)
	cdm.auras[spell] = { auraInstanceID = instance }
	if left then
		-- Forever's duration objects are userdata (LuaDurationObjectAPIDocumentation.lua, ObjectType "Userdata").
		local duration = newproxy(true)
		getmetatable(duration).__index = {
			GetRemainingDuration = function()
				return left
			end,
		}
		cdm.auraDurations[instance] = duration
	end
end
for i = 1, 10 do
	activate(5000 + i, 700 + i, 20 + i)
end
for i = 1, BARS do
	activate(6000 + i, 800 + i)
end
K.Options.Write("Cooldowns", "path", "mirror")
C.Enable(env, K)
assert(ns.Path.Get("buffs") == "mirror" and ns.Path.Get("bars") == "mirror", "a forced mirror runs the buff groups")
local root = K.Scale.Root()
local function rect(frame)
	local r, why = Geometry.Rect(frame, root)
	assert(r, "no rect: " .. tostring(why))
	return r
end

local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
local cfg = buffs.cfg
local capacity = ns.Grid.Capacity(cfg)
assert(capacity == 6, "the tracked buff icons hold six")

-- Ten active buffs: all six sockets show a buff, and a +4 chip sits one socket left of the row ---------------------
assert(buffs.count == capacity, "the row shows its grid, not more: " .. buffs.count)
local holder = rect(buffs.holder)
for i = 1, capacity do
	assert(buffs.icons[i]:IsShown() and inside(rect(buffs.icons[i]), holder), "socket " .. i .. " shows inside the row's footprint")
	assert(buffs.icons[i].entry.spell == 5000 + i, "socket " .. i .. " holds the Cooldown Manager's " .. i .. "th buff")
end
local chip = buffs.chip
assert(chip and chip:IsShown(), "a +N chip shows")
assert(chip.text:GetText() == "+4", "ten buffs on six sockets read +4, got " .. tostring(chip.text:GetText()))
local chipRect, first = rect(chip), rect(buffs.icons[1])
for i = 1, capacity do
	assert(apart(chipRect, rect(buffs.icons[i])), "the chip covers no buff: socket " .. i)
end
assert(near(first.left, holder.left), "a full row starts at the holder's left edge")
assert(near(chipRect.right, holder.left - cfg.spacing) and near(chipRect.top, first.top) and near(chipRect.bottom, first.bottom), "the chip is one more socket on the row's left, one gap away")
assert(near(chipRect.right - chipRect.left, cfg.size), "and a whole socket wide")
assert(near(holder.left - chipRect.left, cfg.size + cfg.spacing), "so the row grows by exactly one socket")
local bw, bh = buffs.holder:GetSize()
assert(bw == 195 and bh == 30, "the holder keeps its 195 by 30 footprint")

-- Hovering the chip lists the hidden buffs, in order, with their time left -----------------------------------------
do
	local tip = env.GameTooltip
	assert(mouse(chip), "the chip takes the pointer while tooltips are on")
	chip:GetScript("OnEnter")(chip)
	assert(tip.shown and tip.owner == chip, "hovering the chip opens a tooltip on it")
	assert(tip.lines[1].left == K.L["%d more tracked buffs"]:format(4), "titled with the hidden count, got " .. tostring(tip.lines[1] and tip.lines[1].left))
	for i = 1, 4 do
		local line = tip.lines[1 + i]
		assert(line and line.left == "Spell " .. (5006 + i), "line " .. i .. " names hidden buff " .. (5006 + i) .. ", got " .. tostring(line and line.left))
		assert(line.right == string.format("%ds", 26 + i), "with its time left in the 24s format, got " .. tostring(line.right))
	end
	chip:GetScript("OnLeave")(chip)
	assert(not tip.shown, "leaving the chip closes it")
end

-- More buffs count up; fewer clear the chip ------------------------------------------------------------------------
activate(5011, 711)
activate(5012, 712)
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
assert(chip:IsShown() and chip.text:GetText() == "+6", "twelve read +6, got " .. tostring(chip.text:GetText()))
for i = 7, 12 do
	cdm.auras[5000 + i] = nil
end
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
assert(buffs.count == 6 and not chip:IsShown(), "six fit: no chip")

-- Settings changes keep the count the row was asked for ----------------------------------------------------------
for i = 7, 10 do
	activate(5000 + i, 700 + i)
end
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
K.Options.Write("Cooldowns", "buffs.columns", 4)
assert(buffs.count == 4 and chip:IsShown() and chip.text:GetText() == "+6", "four columns read +6 after a settings change, got " .. tostring(chip.text:GetText()))
K.Options.Write("Cooldowns", "buffs.columns", 6)
assert(chip.text:GetText() == "+4", "and +4 again at six")

-- The priority: active buffs first, in the Cooldown Manager's order, then the inactive ones the player keeps -------
do
	K.Options.Write("Cooldowns", "buffs.inactive", true)
	cdm.auras[5001], cdm.auras[5002] = nil, nil
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	env.RunTimers()
	assert(buffs.icons[1].entry.spell == 5003, "the first socket holds the first active buff, got " .. tostring(buffs.icons[1].entry.spell))
	assert(buffs.icons[6].entry.spell == 5008, "the sixth holds the sixth active buff")
	assert(chip.text:GetText() == "+8", "two active and six inactive buffs (the sample's own two among them) hide behind +8, got " .. tostring(chip.text:GetText()))
	K.Options.Write("Cooldowns", "buffs.inactive", false)
	activate(5001, 701)
	activate(5002, 702)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	env.RunTimers()
end

-- Five active bars on two: both bars show, and a +3 bar sits one gap above the stack -------------------------
assert(bars.count == 2, "two bars show")
local barChip = bars.chip
assert(barChip and barChip:IsShown(), "a +N more chip shows")
-- Round 5, Muse D8: one overflow idiom; the bar chip reads "+3" as the icon rows' chips do.
assert(barChip.text:GetText() == "+3", "five bars on two read +3, as the icon rows' chips read, got " .. tostring(barChip.text:GetText()))
local barsHolder = rect(bars.holder)
local top, barChipRect = rect(bars.bars[1]), rect(barChip)
for i = 1, 2 do
	assert(inside(rect(bars.bars[i]), barsHolder) and apart(barChipRect, rect(bars.bars[i])), "bar " .. i .. " shows in full, uncovered")
end
assert(near(top.top, barsHolder.top), "the first bar heads the stack, as the mockup lists Battle Shout over Enrage")
assert(near(barChipRect.bottom, barsHolder.top + bars.cfg.spacing) and near(barChipRect.left, top.left) and near(barChipRect.right, top.right), "the chip is one more bar slot on top of the stack, one gap away")
assert(barChip.chrome.ownFill and barChip.chrome.fillColor[4] == 1, "an opaque tile")
local rw, rh = bars.holder:GetSize()
assert(rw == 195 and rh == 43, "the bars keep their 195 by 43 footprint")
do
	local tip = env.GameTooltip
	barChip:GetScript("OnEnter")(barChip)
	assert(tip.owner == barChip and tip.lines[1].left == K.L["%d more tracked bars"]:format(3), "the bars' chip lists its three hidden bars")
	assert(tip.lines[2].left == "Spell 6003" and tip.lines[4].left == "Spell 6005", "in order")
	barChip:GetScript("OnLeave")(barChip)
end

-- Tooltips off: the chips let the pointer through ------------------------------------------------------------------
K.Options.Write("Cooldowns", "tooltips", false)
assert(not mouse(chip) and not mouse(barChip), "with tooltips off the chips take no pointer")
K.Options.Write("Cooldowns", "tooltips", true)

-- The essential cooldowns' footprint is never reached --------------------------------------------------------------
local essential = rect(ns.Mirror.Row("essential").holder)
assert(apart(rect(chip), essential) and apart(rect(barChip), essential) and apart(holder, essential), "the buffs never reach the essential cooldowns")

-- The essential and utility rows never wear the chip: a cooldown past the grid is the player's layout choice -------
local row = ns.Row.New(root, "essential", ns.Settings.current.essential)
row:SetCount(9)
assert(row.chip == nil, "cooldown rows carry no chip")

-- The mirror stopping clears the chips ---------------------------------------------------------------------------
K.Modules.Disable("Cooldowns")
assert(not chip:IsShown() and not barChip:IsShown(), "no chips once the module stops")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

print("cooldowns overflow ok")
