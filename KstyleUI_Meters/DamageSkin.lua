-- DamageSkin.lua: restyles Blizzard's Damage Meter windows in place, through the core's Skin helpers and hooks, for the damage meter's restyle style and fallback.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Logic = ns.Logic

local MAX_WINDOWS = 3
local WINDOW_NAME = "DamageMeterSessionWindow"

local DamageSkin = { active = false, applied = false }
ns.DamageSkin = DamageSkin

local WEAK = { __mode = "k" }
local windows = setmetatable({}, WEAK)
local entries = setmetatable({}, WEAK)
local generation = 1
local ownerHooked = false
local reloadAsked = false

local function Owner()
	return _G.DamageMeter
end

local function Recolor(entry)
	if not DamageSkin.active then
		return
	end
	local bar = entry.StatusBar
	local texture = bar and bar:GetStatusBarTexture()
	if not texture then
		return
	end
	local displays = Enum and Enum.DamageMeterSourceDisplayType
	local display = entry.sourceDisplayType
	local reaction = "friendly"
	if displays and not Logic.IsSecret(display) and display == displays.Enemy then
		reaction = "hostile"
	end
	local class = entry.classFilename
	if Logic.IsSecret(class) or type(class) ~= "string" or class == "" then
		class = entry.unitClassFilename
	end
	texture:SetVertexColor(ns.BarColor("damage", class, reaction))
end

local function StyleEntry(entry)
	if type(entry) ~= "table" or not DamageSkin.active then
		return
	end
	local bar = entry.StatusBar
	if type(bar) ~= "table" or type(bar.GetStatusBarTexture) ~= "function" then
		return
	end
	local styled = entries[entry]
	if styled == nil then
		local fill = bar:GetStatusBarTexture()
		K.Skin.Strip(bar, { keep = fill and { [fill] = true } or nil })
		K.Skin.Backdrop(bar, { shape = "tile", fill = "buttonFill", shadow = false })
		if type(entry.UpdateStatusBarColor) == "function" then
			hooksecurefunc(entry, "UpdateStatusBarColor", Recolor)
		end
	end
	if styled ~= generation then
		entries[entry] = generation
		bar:SetStatusBarTexture(ns.Get("damage.texture"))
		if bar.Name then
			ns.ApplyFont(bar.Name, "damage")
		end
		if bar.Value then
			ns.ApplyFont(bar.Value, "damage")
		end
	end
	Recolor(entry)
end

local function StyleText(text)
	if type(text) == "table" and type(text.SetFont) == "function" then
		ns.ApplyFont(text, "damage", "titleSize")
	end
end

local function RestyleWindow(window)
	if not DamageSkin.active or type(window) ~= "table" then
		return
	end
	StyleText(window.SessionTimer)
	StyleText(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName)
	StyleText(window.SessionDropdown and window.SessionDropdown.SessionName)
	local box = type(window.GetScrollBox) == "function" and window:GetScrollBox()
	if type(box) == "table" and type(box.ForEachFrame) == "function" then
		box:ForEachFrame(StyleEntry)
	end
	local own = type(window.GetLocalPlayerEntry) == "function" and window:GetLocalPlayerEntry()
	if own then
		StyleEntry(own)
	end
end

local function OnInitEntry(_, entry)
	StyleEntry(entry)
end

local function StyleWindow(window)
	if type(window) ~= "table" then
		return
	end
	if not windows[window] then
		windows[window] = true
		K.Skin.Strip(window, { children = { "MinimizeContainer" } })
		K.Skin.Backdrop(window, { shape = "panel" })
		local scroll = type(window.GetScrollBar) == "function" and window:GetScrollBar()
		if scroll then
			K.Skin.ScrollBar(scroll)
		end
		if type(window.Refresh) == "function" then
			hooksecurefunc(window, "Refresh", RestyleWindow)
		end
		if type(window.InitEntry) == "function" then
			hooksecurefunc(window, "InitEntry", OnInitEntry)
		end
	end
	RestyleWindow(window)
end

local function Window(owner, index)
	if type(owner.GetSessionWindow) == "function" then
		local ok, window = pcall(owner.GetSessionWindow, owner, index)
		if ok and window then
			return window
		end
	end
	return _G[WINDOW_NAME .. index]
end

local function OnSetup(owner, index)
	if DamageSkin.active then
		StyleWindow(Window(owner, index))
	end
end

function DamageSkin.Restyle()
	if not DamageSkin.active then
		return
	end
	generation = generation + 1
	for window in pairs(windows) do
		RestyleWindow(window)
	end
	for entry in pairs(entries) do
		StyleEntry(entry)
	end
end

function DamageSkin.Activate()
	DamageSkin.active = true
	local owner = Owner()
	if owner == nil then
		ns.LogOnce("noDamageMeter", "Blizzard's DamageMeter is missing on this client; there is nothing to restyle")
		return
	end
	if not ownerHooked and type(owner.SetupSessionWindow) == "function" then
		ownerHooked = true
		hooksecurefunc(owner, "SetupSessionWindow", OnSetup)
	end
	for i = 1, MAX_WINDOWS do
		local window = Window(owner, i)
		if window then
			StyleWindow(window)
		end
	end
	DamageSkin.applied = true
	DamageSkin.Restyle()
	ns.LogOnce("damageSkin", "Blizzard's Damage Meter is restyled in place")
end

function DamageSkin.Deactivate()
	if not DamageSkin.active then
		return
	end
	DamageSkin.active = false
	if DamageSkin.applied and not reloadAsked then
		reloadAsked = true
		K.Print(L["Blizzard's Damage Meter keeps KstyleUI's look until you reload. Type /reload to finish."])
		K.Callbacks.Fire("ReloadNeeded", ns.MODULE)
	end
end
