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
	bar.Name = Track(bar:CreateFontString(nil, "OVERLAY"))
	bar.Value = Track(bar:CreateFontString(nil, "OVERLAY"))
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
	window.SessionTimer = Track(window:CreateFontString(nil, "OVERLAY"))
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

local HOOKED = { SetAlpha = true, UpdateStatusBarColor = true, Refresh = true, SetupSessionWindow = true, InitEntry = true }

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

-- Entries take KstyleUI's texture, font and colours.
local entry = window.entries[1]
local fill = entry.StatusBar:GetStatusBarTexture()
assert(fill:GetAlpha() == 1, "the bar fill stays")
assert(entry.StatusBar.Background:GetAlpha() == 0, "the bar's shadow art is hushed")
assert(M.Last(fill, "SetTexture")[1] == ns.Get("damage.texture"), "the bar takes KstyleUI's texture")
assert(M.Last(entry.StatusBar.Name, "SetFont"), "names take KstyleUI's font")
local r, g, b = K.Theme.ClassColor("WARRIOR")
window:Refresh()
local colour = M.Last(fill, "SetVertexColor")
assert(colour[1] == r and colour[2] == g and colour[3] == b, "after Blizzard colours the bar, the class colour wins")
entry:UpdateStatusBarColor()
colour = M.Last(fill, "SetVertexColor")
assert(colour[1] == r and colour[2] == g and colour[3] == b, "a colour update outside a refresh keeps the class colour")
local creature = window.entries[2].StatusBar:GetStatusBarTexture()
local hr, hg, hb = K.Tokens.Color("hostile")
colour = M.Last(creature, "SetVertexColor")
assert(colour[1] == hr and colour[2] == hg and colour[3] == hb, "an enemy without a class takes the hostile colour")
assert(M.Last(window.own.StatusBar:GetStatusBarTexture(), "SetVertexColor"), "the player's pinned entry is restyled")

-- Rows the scroll box acquires later are restyled when Blizzard initialises them.
local late = Entry(env, window, "MAGE", 1)
window:InitEntry(late, {})
assert(late.StatusBar.Background:GetAlpha() == 0, "a row acquired later loses Blizzard's shadow art")
assert(M.Last(late.StatusBar:GetStatusBarTexture(), "SetTexture")[1] == ns.Get("damage.texture"), "a row acquired later takes KstyleUI's texture")

-- A setting change restyles every entry.
M.Write(env, K, "damage.colorSource", "custom")
local custom = ns.Get("damage.color")
colour = M.Last(fill, "SetVertexColor")
assert(colour[1] == custom.r and colour[2] == custom.g and colour[3] == custom.b, "the custom colour reaches Blizzard's bars")

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
local calls = M.Calls(fill, "SetVertexColor")
entry:UpdateStatusBarColor()
assert(M.Calls(fill, "SetVertexColor") == calls + 1, "with the skin off only Blizzard colours the bar")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- No DamageMeter on this client: the restyle logs and does nothing.
local env2, K2 = M.New({ noBlizzard = true })
M.Enable(env2, K2)
M.Write(env2, K2, "damage.mode", "skin")
assert(M.Logged(env2, "DamageMeter is missing"), "a missing DamageMeter is logged")
assert(#env2._errors == 0, "no Lua error: " .. tostring(env2._errors[1]))

print("meters skin ok")
