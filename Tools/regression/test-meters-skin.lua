-- test-meters-skin.lua: the restyle style reskins Blizzard's Damage Meter windows and their spell breakdown windows through hooks and the core's Skin helpers, without scripts, hides, reparenting or new fields on Blizzard's frames.
local M = dofile("Tools/regression/meters_env.lua")
local CoreEnv = M.CoreEnv

local RED = { 1, 0, 0 }
local blizzard = {}
local rowText = {}

local function Track(object)
	blizzard[#blizzard + 1] = object
	return object
end

local function Entry(env, parent, class, display)
	local entry = Track(env.CreateFrame("Button", nil, parent))
	-- Blizzard's default 25-unit row (DamageMeterConstants.lua), its bar inset a unit at the top and bottom in the
	-- Default style (DamageMeterEntry.lua:282).
	entry:SetSize(255, 25)
	local bar = Track(env.CreateFrame("StatusBar", nil, entry))
	bar:SetSize(251, 23)
	bar:SetStatusBarTexture("blizzard-bar")
	Track(bar:GetStatusBarTexture())
	bar.Background = Track(bar:CreateTexture(nil, "BACKGROUND"))
	bar.BackgroundEdge = Track(bar:CreateTexture(nil, "OVERLAY"))
	bar.Name = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	bar.Value = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	rowText[bar.Name], rowText[bar.Value] = true, true
	entry.StatusBar = bar
	entry.classFilename = class
	entry.sourceDisplayType = display
	entry.UpdateStatusBarColor = function(self)
		self.StatusBar:GetStatusBarTexture():SetVertexColor(RED[1], RED[2], RED[3])
	end
	-- Blizzard's own text: AbbreviateLargeNumbers and its formats (DamageMeterEntry.lua:123).
	entry.ShowsValuePerSecondAsPrimary = function(self)
		return self.perSecondFirst == true
	end
	entry.UpdateValue = function(self)
		self.StatusBar.Value:SetText(env.AbbreviateLargeNumbers(self.value or 0) .. " (" .. env.AbbreviateLargeNumbers(self.valuePerSecond or 0) .. ")")
	end
	-- Blizzard's UpdateName writes the name only when it changes (DamageMeterEntry.lua:111-117).
	entry.GetNameText = function(self)
		return self.sourceName
	end
	entry.UpdateName = function(self)
		local text = self:GetNameText()
		if text ~= self.nameText then
			self.nameText = text
			self.StatusBar.Name:SetText(text)
		end
	end
	-- Blizzard's Default style puts the text on the bar's middle (DamageMeterEntry.lua:285-288).
	entry.UpdateStyle = function(self)
		local name, value = self.StatusBar.Name, self.StatusBar.Value
		name:ClearAllPoints()
		value:ClearAllPoints()
		name:SetPoint("LEFT", self.StatusBar, "LEFT", 2, 0)
		value:SetPoint("RIGHT", self.StatusBar, "RIGHT", -3, 0)
	end
	return entry
end

local function Window(env, owner, index)
	local window = Track(env.CreateFrame("Frame", "DamageMeterSessionWindow" .. index, owner))
	window.Header = Track(window:CreateTexture(nil, "BACKGROUND"))
	window.SessionTimer = Track(window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	window.DamageMeterTypeDropdown = { TypeName = Track(window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")) }
	window.SessionDropdown = { SessionName = Track(window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")) }
	local container = Track(env.CreateFrame("Frame", nil, window))
	container.Background = Track(container:CreateTexture(nil, "BACKGROUND"))
	window.MinimizeContainer = container
	local scroll = Track(env.CreateFrame("Frame", nil, container))
	local box = Track(env.CreateFrame("Frame", nil, container))
	window.entries = { Entry(env, box, "WARRIOR", 1), Entry(env, box, "", 2) }
	window.own = Entry(env, container, "HUNTER", 1)
	-- The spell breakdown window Blizzard opens on a click (DamageMeterSourceWindowTemplate).
	local source = Track(env.CreateFrame("Frame", nil, container))
	source.Background = Track(source:CreateTexture(nil, "BACKGROUND"))
	local spellBox = Track(env.CreateFrame("Frame", nil, source))
	local spellScroll = Track(env.CreateFrame("Frame", nil, source))
	local close = Track(env.CreateFrame("Button", nil, source))
	source.entries = { Entry(env, spellBox, "WARRIOR", 1) }
	function spellBox.ForEachFrame(_, fn)
		for _, entry in ipairs(source.entries) do
			fn(entry, {})
		end
	end
	function source.GetScrollBox()
		return spellBox
	end
	function source.GetScrollBar()
		return spellScroll
	end
	function source.GetCloseButton()
		return close
	end
	function source.Refresh() end
	function spellBox.Update() end
	function window.GetSourceWindow()
		return source
	end
	window.source = source
	function box.ForEachFrame(_, fn)
		for _, entry in ipairs(window.entries) do
			fn(entry, {})
		end
	end
	function window.GetScrollBox()
		return box
	end
	function window.GetScrollBar()
		return scroll
	end
	function window.GetLocalPlayerEntry(self)
		return self.own
	end
	function window.InitEntry(_, frame)
		frame:UpdateStatusBarColor()
	end
	function window.Refresh(self)
		for _, entry in ipairs(self.entries) do
			entry:UpdateStatusBarColor()
		end
	end
	return window
end

local function Snapshot()
	local keys = {}
	for i, object in ipairs(blizzard) do
		local set = {}
		for key in pairs(object) do
			set[key] = true
		end
		keys[i] = set
	end
	return keys
end

local HOOKED = { Update = true, SetAlpha = true, SetVertexColor = true, SetColorTexture = true, SetText = true, UpdateStatusBarColor = true, UpdateStyle = true, UpdateName = true, Refresh = true, SetupSessionWindow = true, InitEntry = true, SetMinMaxValues = true, SetValue = true }

-- In a group, so the group-only default (on in both styles) leaves Blizzard's window where Edit Mode put it.
local env, K, ns = M.New({
	game = function(env)
		env._group = { raid = false, size = 2 }
		-- EditModeManagerConstantsDocumentation.lua's DamageMeterStyle.
		env.Enum.DamageMeterStyle = { Default = 0, Thin = 1, Bordered = 2, FullBackground = 3 }
		local owner = Track(env.DamageMeter)
		owner.windows = { Window(env, owner, 1) }
		function owner.GetSessionWindow(self, index)
			return self.windows[index]
		end
		function owner.SetupSessionWindow(self, index)
			self.windows[index] = self.windows[index] or Window(env, self, index)
		end
	end,
})
local owner = env.DamageMeter
local window = owner.windows[1]
local before = Snapshot()

M.Write(env, K, "damage.mode", "skin")
M.Enable(env, K)
assert(ns.DamageSkin.active, "the restyle style is active")
assert(not K.Safe.IsHidden(owner), "Blizzard's meter stays where Edit Mode put it")

-- Blizzard's art fades out and KstyleUI's glass sits behind the window.
assert(window.Header:GetAlpha() == 0, "the header art is hushed")
assert(window.MinimizeContainer.Background:GetAlpha() == 0, "the background art is hushed")
window.Header:SetAlpha(1)
assert(window.Header:GetAlpha() == 0, "Blizzard code cannot bring the art back")
local backdrop
for _, child in ipairs(window._kids) do
	if child.chrome then
		backdrop = child
	end
end
assert(backdrop, "a KstyleUI backdrop is a child of the window")
assert(backdrop.chrome.shapeName == "panel" and backdrop.chrome.fillName == "surface", "the window wears the glass panel, as KstyleUI's own meter window does")

-- Each row wears the own card's row (KSTY-60 item 24: one meter design): Blizzard's fill is hushed, and a flat
-- KstyleUI bar on a buttonFill track fills Blizzard's bar rect in the toned class colour, as BarList draws the
-- card's rows, so Blizzard's name sits inside the fill. The bar lives on a KstyleUI holder frame under Blizzard's
-- bar, so Blizzard's text draws over it.
local function Holder(entry)
	for _, child in ipairs(entry._kids) do
		for _, inner in ipairs(child._kids) do
			if type(inner.SetBarValue) == "function" then
				return child, inner
			end
		end
	end
	return nil
end
local function Pill(entry)
	local _, pill = Holder(entry)
	return pill
end
local function Glow(entry)
	local holder = Holder(entry)
	for _, region in ipairs(holder and holder._regions or {}) do
		local texture = M.Last(region, "SetTexture")
		if texture and texture[1] == K.Tokens.Texture("pill") then
			return region
		end
	end
	return nil
end
local entry = window.entries[1]
local fill = entry.StatusBar:GetStatusBarTexture()
assert(fill:GetAlpha() == 0, "Blizzard's full-height fill is hushed: the KstyleUI bar carries the value")
assert(entry.StatusBar.Background:GetAlpha() == 0, "the bar's shadow art is hushed")
for _, child in ipairs(entry.StatusBar._kids) do
	assert(not (child.chrome and child.chrome.fillName == "buttonFill" and child.chrome.shapeName == "tile"), "no full-row tile: the own meter's rows have none")
end
local pill = Pill(entry)
assert(pill, "a KstyleUI status bar is a child of each row's bar")
local holder = Holder(entry)
assert(holder:GetFrameLevel() < entry.StatusBar:GetFrameLevel(), "the holder sits under Blizzard's bar")
assert(pill:GetFrameLevel() < entry.StatusBar:GetFrameLevel(), "and so does the drawn bar, so Blizzard's name and value draw over the fill")
assert(pill.barEdge ~= nil, "no outside keyline, and the lit top edge the card's rows keep (KSTY-60 item 4)")
assert(pill.backgroundName == "slotWell", "the pill's track is the own meter's rows' well")
assert(pill.textureKey == ns.Get("damage.texture"), "the pill takes KstyleUI's bar texture")
local points = {}
for _, call in ipairs(pill._calls) do
	if call.method == "SetPoint" then
		points[call.args[1]] = call.args[2]
	end
end
-- What a row's text needs above its bar: its taller font and the own card's air between text and bar.
local function Needs(row)
	local _, name = row.StatusBar.Name:GetFont()
	local _, value = row.StatusBar.Value:GetFont()
	return math.max(name, value) + K.Tokens.Size("gapTiny")
end
local function Lane(row)
	return row.StatusBar:GetHeight() - Pill(row):GetHeight()
end
-- The drawn bar snaps to whole pixels, so the lane may come up to half a pixel short.
local half = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(pill) / 2
assert(points.BOTTOMLEFT == holder and points.BOTTOMRIGHT == holder and pill:GetHeight() <= K.Widgets.Snap(pill, K.Tokens.Size("barHeight")) + 1e-6, "the bar keeps Blizzard's width, sits at the row's foot and is at most the nameplate health height")
assert(Lane(entry) >= Needs(entry) - half, "a default row leaves its text a lane above the bar: " .. Lane(entry) .. " units for " .. Needs(entry))
-- As on the own card, the name and the value sit above the bar, never on a fill (a white name on a priest's white bar).
do
	local lift = pill:GetHeight() + K.Tokens.Size("gapTiny") - half
	local np, nrel, nrp, _, ny = entry.StatusBar.Name:GetPoint(1)
	local vp, vrel, vrp, _, vy = entry.StatusBar.Value:GetPoint(1)
	assert(np == "BOTTOMLEFT" and nrel == entry.StatusBar and nrp == "BOTTOMLEFT" and ny >= lift, "the name sits just above the bar")
	assert(vp == "BOTTOMRIGHT" and vrel == entry.StatusBar and vrp == "BOTTOMRIGHT" and vy >= lift, "and so does the value")
	-- Blizzard sets a row up again after acquiring it, and on a style change; the text goes back above the bar.
	entry:UpdateStyle()
	assert(select(1, entry.StatusBar.Name:GetPoint(1)) == "BOTTOMLEFT", "a row Blizzard lays out again keeps its text above the bar")
	-- Blizzard's Thin style already puts the text above its bar, which it anchors to the name: the skin leaves it.
	entry.style = env.Enum.DamageMeterStyle.Thin
	entry:UpdateStyle()
	assert(select(1, entry.StatusBar.Name:GetPoint(1)) == "LEFT", "the Thin style keeps Blizzard's anchors")
	entry.style = nil
	entry:UpdateStyle()
	-- Medallions names are caps, as the card's; a secret name passes untouched.
	local name = entry.StatusBar.Name
	local function Named(text)
		entry.sourceName = text
		entry:UpdateName()
		return name:GetText()
	end
	assert(Named("Kragar") == "KRAGAR", "a Medallions row name is caps: " .. tostring(name:GetText()))
	-- Blizzard runs UpdateName on every row update and writes only a changed name; so does the skin.
	local writes = M.Calls(name, "SetText")
	for _ = 1, 100 do entry:UpdateName() end
	writes = M.Calls(name, "SetText") - writes
	assert(writes == 0, "100 unchanged Blizzard name updates wrote the name " .. writes .. " more times; write only a changed name (KstyleUI_Meters/DamageSkin.lua Rename)")
	-- Blizzard's names carry an atlas and colour codes (DamageMeterEntry.lua:554, :694); caps leaves the markup alone.
	local marked = Named("1. |A:AllianceSymbol:0:0|a Kragar")
	assert(marked == "1. |A:AllianceSymbol:0:0|a KRAGAR", "caps keeps the atlas markup: " .. marked)
	marked = Named("Wrath (|cffc79c6eKragar|r)")
	assert(marked == "WRATH (|cffc79c6eKRAGAR|r)", "caps keeps the colour codes: " .. marked)
	-- Turning the row style off, or switching to Frames, gives the row Blizzard's own name back.
	Named("Kragar")
	M.Write(env, K, "nameplateRows", false)
	assert(name:GetText() == "Kragar", "nameplate rows off restore Blizzard's name: " .. tostring(name:GetText()))
	M.Write(env, K, "nameplateRows", true)
	assert(name:GetText() == "KRAGAR", "and on caps it again: " .. tostring(name:GetText()))
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(name:GetText() == "Kragar", "Frames restores Blizzard's name: " .. tostring(name:GetText()))
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(env.issecretvalue(Named(env.Secret("Kragar"))), "a secret name reaches the row untouched")
	entry.sourceName, entry.nameText = nil, nil
end
local glow = Glow(entry)
assert(glow == nil, "no lens glow draws behind the pill: the restyled rows are the own meter's flat capsule")
assert(M.Last(entry.StatusBar.Name, "SetFont"), "names take KstyleUI's font")
assert(M.Last(entry.StatusBar.Value, "SetFont")[1] == K.Tokens.Font("number"), "values use the shared number role")

-- The value text is written by the formatter KstyleUI's own card uses, so every meter view reads "284.2K · 30%"
-- (the Captain on #311's merge renders: one view still read "284.2k"). A secret amount stays the game's
-- abbreviation with no share; a death keeps Blizzard's time.
do
	local function Shown()
		return M.Last(entry.StatusBar.Value, "SetText")[1]
	end
	entry.value, entry.valuePerSecond, entry.sessionTotalValue = 284200, 9473, 947300
	entry:UpdateValue()
	assert(Shown() == "284.2K \194\183 30%", "Blizzard's row reads as the card's: " .. tostring(Shown()))
	entry.perSecondFirst = true
	entry:UpdateValue()
	assert(Shown() == "9.4K \194\183 30%", "a per-second meter leads with the rate: " .. tostring(Shown()))
	entry.perSecondFirst = nil
	entry.value, entry.sessionTotalValue = env.Secret(284200), env.Secret(947300)
	entry:UpdateValue()
	assert(env.issecretvalue(Shown()) and not env.Reveal(Shown()):find("%", 1, true), "a secret amount shows without a share")
	entry.perSecondFirst, entry.valuePerSecond = true, env.Secret(9473)
	entry:UpdateValue()
	assert(env.issecretvalue(Shown()), "a secret rate leads a per-second row without a boolean test on it")
	entry.perSecondFirst, entry.valuePerSecond = nil, 9473
	entry.value, entry.sessionTotalValue = 284200, 947300
	entry.deathRecapID = 7
	entry:UpdateValue()
	assert(Shown() == "284.2K (9.47K)", "a death row keeps Blizzard's own text: " .. tostring(Shown()))
	entry.value, entry.valuePerSecond, entry.sessionTotalValue, entry.deathRecapID = nil, nil, nil, nil
end

-- The pill follows Blizzard's range and value, straight through the setters, so a secret value passes.
entry.StatusBar:SetMinMaxValues(0, 500)
entry.StatusBar:SetValue(125)
assert(M.Last(pill, "SetMinMaxValues")[2] == 500, "the pill takes Blizzard's range")
assert(M.Last(pill, "SetValue")[1] == 125, "the pill takes Blizzard's value")
local secret = env.Secret(99)
entry.StatusBar:SetValue(secret)
assert(M.Last(pill, "SetValue")[1] == secret, "a secret value reaches the pill untouched")

-- Colours: the class colour toned as the card's, at full alpha.
local r, g, b = ns.BarColor("damage", "WARRIOR", nil, nil, true)
window:Refresh()
local colour = pill.colorRGBA
assert(colour[1] == r and colour[2] == g and colour[3] == b, "after Blizzard colours the bar, the class colour wins on the pill")
assert(colour[4] == 1, "the pill is the class colour at full alpha, as BarList's rows: " .. tostring(colour[4]))
entry:UpdateStatusBarColor()
colour = pill.colorRGBA
assert(colour[1] == r and colour[2] == g and colour[3] == b, "a colour update outside a refresh keeps the class colour")
local creaturePill = Pill(window.entries[2])
local hr, hg, hb = ns.BarColor("damage", nil, "hostile")
colour = creaturePill.colorRGBA
assert(colour[1] == hr and colour[2] == hg and colour[3] == hb, "an enemy without a class takes the hostile colour")
assert(Pill(window.own), "the player's pinned entry is restyled")

-- The header is the card's section cap (diamond, caps title, rule, count at the right), drawn by KstyleUI over
-- Blizzard's hushed type name and timer, which it mirrors through hooks on their SetText.
local cap
for _, child in ipairs(window._kids) do
	for _, inner in ipairs(child._kids or {}) do
		if inner.gem and inner.rule and inner.label and inner.count then
			cap = inner
		end
	end
end
assert(cap, "a KstyleUI section cap heads the window")
assert(window.DamageMeterTypeDropdown.TypeName:GetAlpha() == 0 and window.SessionTimer:GetAlpha() == 0, "Blizzard's type name and timer are hushed")
window.DamageMeterTypeDropdown.TypeName:SetAlpha(1)
assert(window.DamageMeterTypeDropdown.TypeName:GetAlpha() == 0, "Blizzard code cannot bring the type name back")
local typeName = window.DamageMeterTypeDropdown.TypeName
local hushes = #typeName._calls
for _ = 1, 10 do typeName:SetAlpha(0) end
local more = #typeName._calls - hushes - 10
assert(more == 0, "Blizzard setting the hushed type name to 0 ten times made " .. more .. " more writes; hush again only when the new alpha is not 0 (KstyleUI_Meters/DamageSkin.lua Rehush)")
-- Blizzard refreshes the window on every combat-session update; with nothing changed the skin restyles nothing but the bars' colours.
window:Refresh()
local refreshed = {}
for _, f in ipairs(env._frames) do
	refreshed[f] = #f._calls
	for _, region in ipairs(f._regions) do refreshed[region] = #region._calls end
end
window:Refresh()
local rewrites = {}
for o, start in pairs(refreshed) do
	for i = start + 1, #o._calls do
		local method = o._calls[i].method
		if not (method:find("^Get") or method:find("^Is") or method:find("^Has") or method:find("^Can")) then rewrites[#rewrites + 1] = method end
	end
end
table.sort(rewrites)
assert(#rewrites <= 4, "an unchanged window refresh wrote " .. #rewrites .. " times (" .. table.concat(rewrites, " ") .. "); restyle the cap once per style generation and place it only when its room changes (KstyleUI_Meters/DamageSkin.lua RestyleWindow, PlaceCap)")
window.DamageMeterTypeDropdown.TypeName:SetText("Damage Done")
assert(tostring(M.Last(cap.label, "SetText")[1]):upper() == "DAMAGE DONE", "the cap's title follows Blizzard's type name")
assert(select(1, cap.label:GetFont()) == K.Tokens.Font("caps"), "in the caps face, as the card's heading")
-- In the own card's title colour too (BarList's TextColor "capsGold": steel in Medallions, gold in Frames).
for _, style in ipairs({ "frames", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local lr, lg, lb = cap.label:GetTextColor()
	local cr, cg, cb = K.Widgets.Rgba("capsGold")
	assert(lr == cr and lg == cg and lb == cb, style .. ": the cap's title is the own card's title colour, got " .. tostring(lr) .. "," .. tostring(lg) .. "," .. tostring(lb) .. "; paint it after the cap paints (KstyleUI_Meters/DamageSkin.lua NewCap)")
end
window.SessionTimer:SetText("1:40")
assert(cap.counted and M.Last(cap.count, "SetText")[1] == "1:40", "the count at the right is Blizzard's fight timer")
window.SessionTimer:SetText("")
assert(not cap.counted, "an empty timer leaves no count")
local secretTimer = env.Secret("0:12")
window.SessionTimer:SetText(secretTimer)
assert(M.Last(cap.count, "SetText")[1] == secretTimer and #env._errors == 0, "a secret timer passes straight to the count")
window.SessionTimer:SetText("1:40")
local mr, mg, mb = K.Tokens.Color("muted")
local sessionColour = M.Last(window.SessionDropdown.SessionName, "SetTextColor")
assert(sessionColour and sessionColour[1] == mr and sessionColour[2] == mg and sessionColour[3] == mb, "the fight's name is muted, as the card's aside")

-- The spell breakdown window wears the same glass, and its spell rows the same pills.
do
	local source = window.source
	assert(source.Background:GetAlpha() == 0, "the spell window's art is hushed")
	local glass
	for _, child in ipairs(source._kids) do
		if child.chrome then
			glass = child
		end
	end
	assert(glass and glass.chrome.shapeName == "panel", "the spell window wears the glass panel")
	local spellPill = Pill(source.entries[1])
	assert(spellPill and spellPill.backgroundName == "slotWell", "a spell row gets the own meter's pill")
	local sr, sg, sb = ns.BarColor("damage", "WARRIOR", nil, nil, true)
	local c = spellPill.colorRGBA
	assert(c[1] == sr and c[2] == sg and c[3] == sb, "a spell row takes its source's class colour")
	local later = Entry(env, source, "WARRIOR", 1)
	source.entries[#source.entries + 1] = later
	source:Refresh()
	assert(Pill(later), "a spell row shown later is restyled when Blizzard refreshes the window")
	local scrolled = Entry(env, source, "WARRIOR", 1)
	source.entries[#source.entries + 1] = scrolled
	source:GetScrollBox():Update()
	assert(Pill(scrolled), "a spell row the scroll box acquires on a scroll is restyled after its update")
	-- A row first styled in combat reads a secret range and value from Blizzard's bar: they pass straight to the pill.
	local secretRow = Entry(env, source, "WARRIOR", 1)
	secretRow.StatusBar:SetMinMaxValues(0, env.Secret(900))
	secretRow.StatusBar:SetValue(env.Secret(450))
	source.entries[#source.entries + 1] = secretRow
	source:Refresh()
	assert(env.issecretvalue(M.Last(Pill(secretRow), "SetValue")[1]), "a secret value reaches the new pill untouched")
end

-- Rows the scroll box acquires later are restyled when Blizzard initialises them.
local late = Entry(env, window, "MAGE", 1)
window:InitEntry(late, {})
assert(late.StatusBar.Background:GetAlpha() == 0, "a row acquired later loses Blizzard's shadow art")
assert(Pill(late) and Pill(late).textureKey == ns.Get("damage.texture"), "a row acquired later gets the pill with KstyleUI's texture")

-- A setting change restyles every entry.
M.Write(env, K, "damage.colorSource", "custom")
local cr, cg, cb = ns.BarColor("damage")
colour = pill.colorRGBA
assert(colour[1] == cr and colour[2] == cg and colour[3] == cb, "the custom colour reaches the pills")

-- Windows Blizzard opens later are restyled too.
owner:SetupSessionWindow(2)
local second = owner.windows[2]
assert(second.Header:GetAlpha() == 0, "a window opened later is restyled")

-- Nothing scripted, hidden or reparented; no new field but the hooked methods. Only a row's name and value move.
local after = Snapshot()
for i, object in ipairs(blizzard) do
	for _, method in ipairs({ "SetScript", "Hide", "SetParent", "ClearAllPoints", "SetPoint" }) do
		assert(rowText[object] and method:find("Point") or M.Calls(object, method) == 0, "the skin called " .. method .. " on a Blizzard object")
	end
	for key in pairs(after[i]) do
		if before[i] and not before[i][key] and type(key) == "string" and key:sub(1, 1) ~= "_" then
			assert(HOOKED[key] and type(object[key]) == "function", "the skin wrote the field " .. key .. " onto a Blizzard object")
		end
	end
end

-- Edit Mode sets a row 15 to 40 units tall (EditModeSettingDisplayInfo.lua:1377), and the Default style insets the bar
-- a unit at its top and bottom (DamageMeterEntry.lua:282). Either the text gets a lane above the bar that its font
-- fits, or the bar fills Blizzard's bar under Blizzard's own anchors; in the Thin style the bar stays inside its rect.
for _, style in ipairs({ "medallions", "frames" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local bar = entry.StatusBar
	for _, height in ipairs({ 40, 25, 16, 15 }) do
		entry:SetSize(255, height)
		bar:SetSize(251, height - 2)
		-- In combat Blizzard's bar holds a secret value, so its geometry reads secret: lay the row out so, measure plainly.
		entry:UpdateStyle()
		env.SecretAnchoring(false)
		local raised = select(1, bar.Name:GetPoint(1)) == "BOTTOMLEFT"
		local label = style .. " " .. height .. "-unit row: "
		assert(raised or height < 25, label .. "a row at Blizzard's default height or taller keeps its text above the bar")
		if raised then
			assert(Lane(entry) >= Needs(entry) - half, label .. "the text lane is " .. Lane(entry) .. " units for a line of " .. Needs(entry))
		else
			assert(math.abs(pill:GetHeight() - bar:GetHeight()) < 1, label .. "with no lane the bar fills Blizzard's bar under its text: " .. pill:GetHeight())
		end
		env.SecretAnchoring(true)
	end
	local _, size = bar.Name:GetFont()
	entry:SetSize(255, 25)
	bar:SetSize(251, 25 - size - 1)
	entry.style = env.Enum.DamageMeterStyle.Thin
	entry:UpdateStyle()
	env.SecretAnchoring(false)
	assert(pill:GetHeight() <= bar:GetHeight() + 0.01, style .. " Thin row: the drawn bar stays inside Blizzard's bar, under the name: " .. pill:GetHeight() .. " in " .. bar:GetHeight())
	env.SecretAnchoring(true)
	entry.style = nil
	bar:SetSize(251, 23)
	entry:UpdateStyle()
end
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()

-- Leaving the restyle style asks for a reload, and the hooks stop recolouring.
M.Write(env, K, "damage.mode", "window")
local placings = M.Calls(pill, "ClearAllPoints")
entry:UpdateStyle()
assert(M.Calls(pill, "ClearAllPoints") == placings, "with the skin off, Blizzard laying a row out places no KstyleUI bar")
assert(CoreEnv.Printed(env, "/reload"), "leaving the restyle asks for a reload")
local calls = M.Calls(pill, "SetStatusBarColor")
entry:UpdateStatusBarColor()
assert(M.Calls(pill, "SetStatusBarColor") == calls, "with the skin off the pill no longer follows Blizzard's colour")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- No DamageMeter on this client: the restyle logs and does nothing.
local env2, K2 = M.New({ noBlizzard = true })
M.Enable(env2, K2)
M.Write(env2, K2, "damage.mode", "skin")
assert(M.Logged(env2, "DamageMeter is missing"), "a missing DamageMeter is logged")
assert(#env2._errors == 0, "no Lua error: " .. tostring(env2._errors[1]))

print("meters skin ok")
