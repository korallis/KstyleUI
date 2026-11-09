-- test-cooldowns-overflow.lua: on the mirror path, many active tracked buffs stay inside their footprints: the icon
-- row shows its grid and its last socket reads "+N" for the rest; the bars show their count and the last bar's slot
-- reads "+N more"; nothing grows past the holder toward the essential cooldowns.
local C = dofile("Tools/regression/cooldowns_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local EPS = 1e-3

local function inside(r, s)
	return r.left >= s.left - EPS and r.right <= s.right + EPS and r.bottom >= s.bottom - EPS and r.top <= s.top + EPS
end

local function same(r, s)
	return math.abs(r.left - s.left) < EPS and math.abs(r.right - s.right) < EPS and math.abs(r.bottom - s.bottom) < EPS and math.abs(r.top - s.top) < EPS
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
local function activate(spell, instance)
	cdm.auras[spell] = { auraInstanceID = instance }
end
for i = 1, 10 do
	activate(5000 + i, 700 + i)
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
local capacity = ns.Grid.Capacity(buffs.cfg)
assert(capacity == 6, "the tracked buff icons hold six")

-- Ten active buffs: six sockets, the sixth reads +5 ---------------------------------------------------------------
assert(buffs.count == capacity, "the row shows its grid, not more: " .. buffs.count)
local chip = buffs.chip
assert(chip and chip:IsShown(), "a +N chip shows")
assert(chip.text:GetText() == "+5", "ten buffs on six sockets read +5, got " .. tostring(chip.text:GetText()))
local holder = rect(buffs.holder)
local last = rect(buffs.icons[capacity])
assert(same(rect(chip), last), "the chip covers the last socket")
assert(inside(rect(chip), holder), "inside the row's footprint")
assert(chip:GetFrameLevel() > buffs.icons[capacity]:GetFrameLevel(), "over the icon")
assert(chip.chrome.ownFill and chip.chrome.fillColor[4] == 1, "the chip is opaque, so the icon and its countdown never show through")
for i = 1, buffs.count do
	assert(inside(rect(buffs.icons[i]), holder), "socket " .. i .. " stays inside the row's footprint")
end
local bw, bh = buffs.holder:GetSize()
assert(bw == 195 and bh == 30, "the row keeps its 195 by 30 footprint")

-- More buffs count up; fewer clear the chip ------------------------------------------------------------------------
activate(5011, 711)
activate(5012, 712)
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
assert(chip:IsShown() and chip.text:GetText() == "+7", "twelve read +7, got " .. tostring(chip.text:GetText()))
for i = 6, 12 do
	cdm.auras[5000 + i] = nil
end
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
assert(buffs.count == 5 and not chip:IsShown(), "five fit: no chip")

-- Settings changes keep the count the row was asked for ----------------------------------------------------------
for i = 6, 10 do
	activate(5000 + i, 700 + i)
end
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()
K.Options.Write("Cooldowns", "buffs.columns", 4)
assert(buffs.count == 4 and chip:IsShown() and chip.text:GetText() == "+7", "four columns read +7 after a settings change, got " .. tostring(chip.text:GetText()))
K.Options.Write("Cooldowns", "buffs.columns", 6)
assert(chip.text:GetText() == "+5", "and +5 again at six")

-- Five active bars on two: the second slot reads +4 more ---------------------------------------------------------
assert(bars.count == 2, "two bars show")
local barChip = bars.chip
assert(barChip and barChip:IsShown(), "a +N more chip shows")
assert(barChip.text:GetText() == K.L["+%d more"]:format(4), "five bars on two read +4 more, got " .. tostring(barChip.text:GetText()))
assert(same(rect(barChip), rect(bars.bars[2])), "on the last bar's slot")
assert(barChip.chrome.ownFill and barChip.chrome.fillColor[4] == 1, "an opaque tile, so the bar under it never shows through")
assert(inside(rect(barChip), rect(bars.holder)), "inside the bars' footprint")
local rw, rh = bars.holder:GetSize()
assert(rw == 195 and rh == 43, "the bars keep their 195 by 43 footprint")

-- The essential cooldowns' footprint is never reached --------------------------------------------------------------
local essential = rect(ns.Mirror.Row("essential").holder)
local function apart(r, s)
	return r.right <= s.left + EPS or s.right <= r.left + EPS or r.top <= s.bottom + EPS or s.top <= r.bottom + EPS
end
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
