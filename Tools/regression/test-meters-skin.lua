-- test-meters-skin.lua: the restyle style reskins Blizzard's Damage Meter windows through hooks and the core's Skin helpers, without scripts, hides, reparenting or new fields on Blizzard's frames.
local M = dofile("Tools/regression/meters_env.lua")
local CoreEnv = M.CoreEnv

local RED = { 1, 0, 0 }
local blizzard = {}

local function Track(object)
	blizzard[#blizzard + 1] = object
	return object
end

local function Entry(env, parent, class, display)
	local entry = Track(env.CreateFrame("Button", nil, parent))
	local bar = Track(env.CreateFrame("StatusBar", nil, entry))
	bar:SetStatusBarTexture("blizzard-bar")
	Track(bar:GetStatusBarTexture())
	bar.Background = Track(bar:CreateTexture(nil, "BACKGROUND"))
	bar.BackgroundEdge = Track(bar:CreateTexture(nil, "OVERLAY"))
	bar.Name = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	bar.Value = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	entry.StatusBar = bar
	entry.classFilename = class
	entry.sourceDisplayType = display
	entry.UpdateStatusBarColor = function(self)
		self.StatusBar:GetStatusBarTexture():SetVertexColor(RED[1], RED[2], RED[3])
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

local HOOKED = { SetAlpha = true, UpdateStatusBarColor = true, Refresh = true, SetupSessionWindow = true, InitEntry = true, SetMinMaxValues = true, SetValue = true }

local env, K, ns = M.New({
	game = function(env)
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

-- Each row wears the own meter's row: Blizzard's full-height fill is hushed, and a 4-unit KstyleUI pill on a
-- buttonFill track sits at the row's foot with the glowing class colour, as BarList draws its rows.
-- The pill and its glow live on a KstyleUI holder frame one level above Blizzard's bar.
local function Holder(entry)
	for _, child in ipairs(entry.StatusBar._kids) do
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
assert(fill:GetAlpha() == 0, "Blizzard's full-height fill is hushed: the pill carries the value")
assert(entry.StatusBar.Background:GetAlpha() == 0, "the bar's shadow art is hushed")
for _, child in ipairs(entry.StatusBar._kids) do
	assert(not (child.chrome and child.chrome.fillName == "buttonFill" and child.chrome.shapeName == "tile"), "no full-row tile: the own meter's rows have none")
end
local pill = Pill(entry)
assert(pill, "a KstyleUI status bar is a child of each row's bar")
assert(pill.opts.height == K.Widgets.Snap(pill, ns.BarList.PILL_HEIGHT), "the pill is the own meter's 4-unit pill, snapped, got " .. tostring(pill.opts.height))
assert(pill.backgroundName == "buttonFill", "the pill's track is the button body, as the own meter's rows")
assert(pill.textureKey == ns.Get("damage.texture"), "the pill takes KstyleUI's bar texture")
local points = {}
for _, call in ipairs(pill._calls) do
	if call.method == "SetPoint" then
		points[call.args[1]] = call.args[2]
	end
end
assert(points.BOTTOMLEFT == entry.StatusBar and points.BOTTOMRIGHT == entry.StatusBar, "the pill runs along the row's foot")
local glow = Glow(entry)
assert(glow, "a pill glow draws behind the pill")
assert(M.Last(glow, "SetBlendMode")[1] == "ADD", "the glow is additive, as the own meter's")
assert(M.Last(entry.StatusBar.Name, "SetFont"), "names take KstyleUI's font")
assert(M.Last(entry.StatusBar.Value, "SetFont"), "values take KstyleUI's font")

-- The pill follows Blizzard's range and value, straight through the setters, so a secret value passes.
entry.StatusBar:SetMinMaxValues(0, 500)
entry.StatusBar:SetValue(125)
assert(M.Last(pill, "SetMinMaxValues")[2] == 500, "the pill takes Blizzard's range")
assert(M.Last(pill, "SetValue")[1] == 125, "the pill takes Blizzard's value")
local secret = env.Secret(99)
entry.StatusBar:SetValue(secret)
assert(M.Last(pill, "SetValue")[1] == secret, "a secret value reaches the pill untouched")

-- Colours: the class colour on the pill at full alpha and on the glow at the own meter's glow alpha.
local r, g, b = K.Theme.ClassColor("WARRIOR")
window:Refresh()
local colour = pill.colorRGBA
assert(colour[1] == r and colour[2] == g and colour[3] == b, "after Blizzard colours the bar, the class colour wins on the pill")
assert(colour[4] == 1, "the pill is the class colour at full alpha, as BarList's rows: " .. tostring(colour[4]))
local glowColour = M.Last(glow, "SetVertexColor")
assert(glowColour[1] == r and glowColour[2] == g and glowColour[3] == b and glowColour[4] < 0.5, "the glow is the class colour, faint")
entry:UpdateStatusBarColor()
colour = pill.colorRGBA
assert(colour[1] == r and colour[2] == g and colour[3] == b, "a colour update outside a refresh keeps the class colour")
local creaturePill = Pill(window.entries[2])
local hr, hg, hb = K.Tokens.Color("hostile")
colour = creaturePill.colorRGBA
assert(colour[1] == hr and colour[2] == hg and colour[3] == hb, "an enemy without a class takes the hostile colour")
assert(Pill(window.own), "the player's pinned entry is restyled")

-- The header reads as the own meter's cap: the type name in the tracked caption face in gilt, the session and timer muted.
local captionPath = K.Tokens.Font("caption")
assert(M.Last(window.DamageMeterTypeDropdown.TypeName, "SetFont")[1] == captionPath, "the type name takes the caption face, as the own meter's cap title")
local gr, gg, gb = K.Tokens.Color("giltLit")
local typeColour = M.Last(window.DamageMeterTypeDropdown.TypeName, "SetTextColor")
assert(typeColour and typeColour[1] == gr and typeColour[2] == gg and typeColour[3] == gb, "the type name is gilt, as the own meter's cap title")
local mr, mg, mb = K.Tokens.Color("muted")
local timerColour = M.Last(window.SessionTimer, "SetTextColor")
assert(timerColour and timerColour[1] == mr and timerColour[2] == mg and timerColour[3] == mb, "the timer is muted, as the own meter's aside")

-- Rows the scroll box acquires later are restyled when Blizzard initialises them.
local late = Entry(env, window, "MAGE", 1)
window:InitEntry(late, {})
assert(late.StatusBar.Background:GetAlpha() == 0, "a row acquired later loses Blizzard's shadow art")
assert(Pill(late) and Pill(late).textureKey == ns.Get("damage.texture"), "a row acquired later gets the pill with KstyleUI's texture")

-- A setting change restyles every entry.
M.Write(env, K, "damage.colorSource", "custom")
local custom = ns.Get("damage.color")
colour = pill.colorRGBA
assert(colour[1] == custom.r and colour[2] == custom.g and colour[3] == custom.b, "the custom colour reaches the pills")

-- Windows Blizzard opens later are restyled too.
owner:SetupSessionWindow(2)
local second = owner.windows[2]
assert(second.Header:GetAlpha() == 0, "a window opened later is restyled")

-- Nothing scripted, hidden or reparented; no new field but the hooked methods.
local after = Snapshot()
for i, object in ipairs(blizzard) do
	for _, method in ipairs({ "SetScript", "Hide", "SetParent", "ClearAllPoints", "SetPoint" }) do
		assert(M.Calls(object, method) == 0, "the skin called " .. method .. " on a Blizzard object")
	end
	for key in pairs(after[i]) do
		if before[i] and not before[i][key] and type(key) == "string" and key:sub(1, 1) ~= "_" then
			assert(HOOKED[key] and type(object[key]) == "function", "the skin wrote the field " .. key .. " onto a Blizzard object")
		end
	end
end

-- Leaving the restyle style asks for a reload, and the hooks stop recolouring.
M.Write(env, K, "damage.mode", "window")
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
