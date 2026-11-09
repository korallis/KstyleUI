-- test-meters-fit.lua: the meter's glass fits the rows it shows from a fixed top, and a row is never shorter than its text needs.
local M = dofile("Tools/regression/meters_env.lua")
local W = M.W

local function Session(count)
	local sources = {}
	for i = 1, count do
		sources[i] = {
			name = "Source" .. i, classFilename = "WARRIOR", totalAmount = 1000 - i, amountPerSecond = 10,
			sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0,
		}
	end
	return { combatSources = sources, maxAmount = 1000, totalAmount = 5000, durationSeconds = 30 }
end

local function Show(env, count)
	env._session = Session(count)
	env.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 4)
	env.RunTimers()
end

-- Where the last shown row (or, with none, the first row's room) ends, measured down from the panel's top.
local function RowsBottom(list)
	local row = list.rows[math.max(1, list.count)]
	local y = select(5, row.frame:GetPoint(1))
	return -y + row.frame:GetHeight()
end

local function Unused(list)
	return list.panel:GetHeight() - RowsBottom(list) - list.pad
end

local function TopAnchored(list)
	local panel, holder = list.panel, list.holder
	if panel:GetNumPoints() ~= 2 then
		return false
	end
	local a, b = { panel:GetPoint(1) }, { panel:GetPoint(2) }
	return a[1] == "TOPLEFT" and a[2] == holder and a[3] == "TOPLEFT" and b[1] == "TOPRIGHT" and b[2] == holder and b[3] == "TOPRIGHT"
end

-- In a group: the damage meter shows only in a group by default (test-meters-drill.lua).
local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
env._session = Session(1)
M.Enable(env, K)
local list = ns.Damage.list
local title = { list.title:GetPoint(1) }

-- One source: the glass ends one inset under its row, not at the holder's foot (the judge's B-1: 67 dead units).
assert(list.count == 1, "one source shows")
assert(TopAnchored(list), "the glass hangs from the holder's top, so the title never moves")
assert(math.abs(Unused(list)) <= 1, "one row: no dead band under it, got " .. tostring(Unused(list)))
assert(list.panel:GetHeight() < list.holder:GetHeight(), "one row: the glass is shorter than the holder")

-- Full capacity fills the holder, and the rows still fill it to within a pixel per row.
Show(env, list.capacity + 3)
assert(list.count == list.capacity, "a long session fills the capacity")
assert(W.Near(list.panel:GetHeight(), list.holder:GetHeight()), "a full list fills the holder: " .. tostring(list.panel:GetHeight()))
assert(Unused(list) >= -0.01 and Unused(list) < list.capacity, "a full list leaves less than a pixel per row: " .. tostring(Unused(list)))
local same = { list.title:GetPoint(1) }
assert(same[2] == title[2] and W.Near(same[4], title[4]) and W.Near(same[5], title[5]), "the title stays put as rows come")

-- A shrinking session gives the room back.
Show(env, 2)
assert(list.count == 2 and math.abs(Unused(list)) <= 1, "two rows after a full list: no dead band, got " .. tostring(Unused(list)))
assert(not list.rows[3].frame:IsShown(), "rows past the session hide")
assert(TopAnchored(list), "still hung from the top")

-- No source: one row of room for the note, which sits inside the glass.
Show(env, 0)
assert(list.count == 0 and list.note:IsShown(), "an empty session shows its note")
assert(math.abs(Unused(list)) <= 1, "no source: the glass keeps one row of room, got " .. tostring(Unused(list)))

-- A holder too short for one row: the glass never spills past it.
local fullHeight = list.holder:GetHeight()
list.holder:SetHeight(40)
Show(env, 3)
assert(list.capacity == 0, "a 40-unit holder holds no row")
assert(list.panel:GetHeight() <= list.holder:GetHeight() + 0.01, "the glass stays inside a short holder: " .. tostring(list.panel:GetHeight()))
list.holder:SetHeight(fullHeight)

-- A large font on a short row: the row grows to hold its text line clear of the class pill, and capacity counts
-- the rows at the height they are drawn.
M.Write(env, K, "damage.fontSize", 20)
M.Write(env, K, "damage.rowHeight", 10)
Show(env, 12)
local row = list.rows[1]
local _, size = row.name:GetFont()
local bar, pill = row.frame:GetHeight(), row.bar:GetHeight()
assert(bar - pill - ns.BarList.PILL_GAP >= size, "a " .. tostring(size) .. " font sits clear of the pill in a " .. tostring(bar) .. "-unit row")
local spacing = K.Widgets.Snap(list.panel, ns.Get("damage.spacing"))
local room = list.holder:GetHeight() - K.Widgets.Snap(list.panel, list:Top()) - list.pad
assert(list.capacity * (bar + spacing) - spacing <= room + 0.01, "the rows counted fit at their drawn height: " .. list.capacity .. " x " .. tostring(bar) .. " in " .. tostring(room))
assert(list.capacity == 0 or RowsBottom(list) <= list.panel:GetHeight() - list.pad + 0.01, "the last row ends inside the glass")

assert(#env._errors == 0 and K.ErrorCount() == 0, "fitting raises no errors")

-- On a high-density screen a border is several pixels: a row rounded up gives back one pixel, not a border, so it
-- never falls below its minimum and a full list leaves less than a pixel per row.
do
	local hiEnv, hiK, hiNs = M.New({ width = 3456, height = 2234, game = function(e) e._group = { raid = false, size = 2 } end })
	hiEnv._session = Session(30)
	M.Enable(hiEnv, hiK)
	local hi = hiNs.Damage.list
	assert(hiK.Scale.Border() > hiK.Scale.Pixel(1) * 1.5, "this screen draws a border several pixels wide")
	for _, height in ipairs({ 385, 300, 211, 130 }) do
		hi.holder:SetHeight(height)
		Show(hiEnv, 30)
		local pixel = hiK.Scale.Pixel(1) / hiK.Widgets.ScaleFactor(hi.panel)
		assert(hi.rows[1].frame:GetHeight() >= hi:MinRow() - 0.01, height .. ": a row is never shorter than its minimum, got " .. tostring(hi.rows[1].frame:GetHeight()) .. " for " .. hi:MinRow())
		assert(Unused(hi) >= -0.01 and Unused(hi) < hi.capacity * pixel + 0.01, height .. ": a full list leaves under a pixel per row, got " .. tostring(Unused(hi)))
	end
end

-- The fight switch is length-safe (round 4, S6: in German, French or Spanish the words Now / Last / All run past
-- the card). The switch is measured from the stub's glyph widths as the game measures it; when the three words do
-- not fit beside the title they drop to the selected word alone, and with the title off the words must fit the
-- card's content width on their own.
do
	local D = dofile("Tools/regression/databars_env.lua")
	local env2, K2, ns2 = M.New({
		setup = function(e)
			e._textWidth = D.TextWidth
		end,
		game = function(e)
			e._group = { raid = false, size = 2 }
		end,
	})
	M.Enable(env2, K2)
	local switchList = ns2.Damage.list
	local function Plain()
		return (tostring(M.Last(switchList.column, "SetText")[1]):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
	end
	Show(env2, 3)
	assert(Plain():find("Now", 1, true) and Plain():find("All", 1, true), "English words fit the default card: " .. Plain())
	-- Long words, as a locale table gives them.
	local words = { "Gegenwaertig", "Vorheriger Kampf", "Insgesamt" }
	switchList:SetSwitch(words, 1, {})
	local shown = Plain()
	assert(not shown:find("Insgesamt", 1, true) and shown:find("Gegenwaertig", 1, true), "words too long for the cap drop to the selected word alone: " .. shown)
	local aside, capTitle = switchList.column:GetStringWidth(), switchList.title:GetStringWidth()
	assert(aside and capTitle and aside + capTitle <= switchList.barWidth, "what shows fits beside the title: " .. tostring(aside) .. " + " .. tostring(capTitle) .. " in " .. tostring(switchList.barWidth))
	-- With the title off, the words alone must fit the content width, on a narrow card too.
	M.Write(env2, K2, "damage.title", false)
	local wide = switchList.barWidth
	switchList.barWidth = 120
	switchList:SetSwitch({ "Gegenwaertig", "Vorheriger Kampf", "Insgesamt und alles" }, 3, {})
	shown = Plain()
	aside = switchList.column:GetStringWidth()
	assert(aside and aside <= switchList.barWidth + 0.01, "with the title off the switch still fits a narrow card: " .. tostring(aside) .. " in " .. tostring(switchList.barWidth) .. " (" .. shown .. ")")
	assert(shown:find("Insgesamt", 1, true) and not shown:find("Gegenwaertig", 1, true), "the selected word is what stays: " .. shown)
	switchList.barWidth = wide
	M.Write(env2, K2, "damage.title", true)
	-- Short forms step in before the selected word alone.
	switchList:SetSwitch({ "Gegenwaertig", "Vorheriger", "Insgesamt" }, 2, { "Jetzt", "Zuletzt", "Alle" })
	shown = Plain()
	assert(shown:find("Zuletzt", 1, true) and shown:find("Jetzt", 1, true), "short forms show when the long words do not fit: " .. shown)
	-- A title too long for the cap (the German "Verursachter Schaden" on a narrow card) gives way to the selected
	-- word: the title is held to the room left of the word, so the two never cross; a title that fits keeps its
	-- natural width.
	switchList.barWidth = 150
	switchList:SetTitle("VERURSACHTER SCHADEN")
	switchList:SetSwitch({ "Jetzt", "Zuvor", "Alle" }, 1, {})
	local titleW, asideW = switchList.title:GetWidth(), switchList.column:GetStringWidth()
	assert(titleW and titleW > 0 and titleW + asideW <= switchList.barWidth + 0.01, "the title is held clear of the selected word: " .. tostring(titleW) .. " + " .. tostring(asideW) .. " in " .. switchList.barWidth)
	switchList.barWidth = wide
	switchList:SetTitle("DAMAGE DONE")
	switchList:SetSwitch({ "Now", "Last", "All" }, 1, {})
	assert((switchList.title:GetWidth() or 0) == 0 or switchList.title:GetWidth() >= switchList.title:GetUnboundedStringWidth() - 0.01, "a title that fits keeps its natural width")
	assert(switchList.title:IsShown(), "and shows")
	-- No room at all for the title beside the selected word (a card narrower than the word and the reserve): the
	-- title hides rather than spreading at its natural width across the switch (codex review).
	switchList.barWidth = 60
	switchList:SetSwitch({ "Gegenwaertig", "Zuvor", "Alle" }, 1, {})
	assert(not switchList.title:IsShown(), "with no room left the title hides")
	switchList.barWidth = wide
	-- A restyle fits the switch again from its words: a card that shrinks drops to the selected word, one that
	-- grows back shows every word (codex review).
	switchList:SetSwitch({ "Now", "Last", "All" }, 1, {})
	assert(Plain():find("All", 1, true), "every word on the wide card")
	switchList.holder:SetSize(90, switchList.holder:GetHeight())
	switchList:Restyle()
	assert(not Plain():find("All", 1, true) and Plain():find("Now", 1, true), "a card that shrinks drops to the selected word on restyle: " .. Plain())
	switchList.holder:SetSize(wide + 2 * switchList.pad, switchList.holder:GetHeight())
	switchList:Restyle()
	assert(Plain():find("All", 1, true), "a card that grows shows every word again: " .. Plain())
	assert(switchList.title:IsShown(), "and the title shows")
end

print("meters fit: passed")
