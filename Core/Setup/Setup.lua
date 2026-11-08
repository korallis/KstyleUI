-- Setup.lua: the first-run setup's choices, Apply, and when the setup window opens.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local L = ns.L

local OWNER = "Setup"
local OPEN_DELAY = 2
local DEFAULT_LAYOUT = "DPS"
local ICON_ADDON = "KstyleUI_IconsColour"

local PICKER = {
	{ name = "UnitFrames", label = L["Unit frames"], note = L["Player, target, focus, pet and boss frames."] },
	{ name = "ActionBars", label = L["Action bars"], note = L["Two compact rows with keybinds and proc glows."] },
	{ name = "Cooldowns", label = L["Cooldown Manager"], note = L["Blizzard's cooldown tracker in your HUD band."] },
	{ name = "GroupFrames", label = L["Group frames"], note = L["Party and raid frames with roles and range fade."] },
	{ name = "Auras", label = L["Buffs and debuffs"], note = L["Your buffs and debuffs, under the minimap."] },
	{ name = "Nameplates", label = L["Nameplates"], note = L["Health, cast bar, threat and debuffs on plates."] },
	{ name = "CombatText", label = L["Combat text"], note = L["Damage and heal numbers on your frames."] },
	{ name = "Minimap", label = L["Minimap"], note = L["A square minimap with zone, clock and buttons."] },
	{ name = "Chat", label = L["Chat"], note = L["Glass chat with tabs, copy and class colours."] },
	{ name = "Bags", label = L["Bags"], note = L["One combined bag with search and sorting."] },
	{ name = "Tooltips", label = L["Tooltips"], note = L["Glass tooltips with quality and class colours."] },
	{ name = "DataBars", label = L["Data bars"], note = L["XP and reputation bars, micro menu and data strip."] },
	{ name = "Meters", label = L["Meters"], note = L["Damage meter, threat meter and swing timer."] },
	{ name = "Skins", label = L["Window skins"], note = L["KstyleUI styling for Blizzard's windows."] },
	{ name = "Icons", label = L["Custom icons"], note = L["KstyleUI's own ability icons in your class colour."] },
}

local choice

Setup.PICKER = PICKER

local function log(message)
	ns.DevTest.Log(OWNER, message)
end

local function registered()
	local out = {}
	for _, name in ipairs(ns.Modules.List()) do
		out[name] = true
	end
	return out
end

local function iconsInstalled()
	local AddOns = C_AddOns
	if not (AddOns and type(AddOns.DoesAddOnExist) == "function") then
		return true
	end
	local ok, exists = pcall(AddOns.DoesAddOnExist, ICON_ADDON)
	return not ok or exists == true
end

function Setup.Available(name)
	if not registered()[name] then
		return false
	end
	if name == "Icons" then
		return iconsInstalled()
	end
	return true
end

function Setup.NewChoice()
	local modules = {}
	for _, entry in ipairs(PICKER) do
		modules[entry.name] = Setup.Available(entry.name)
	end
	return { layout = DEFAULT_LAYOUT, modules = modules }
end

function Setup.Choice()
	if not choice then
		choice = Setup.NewChoice()
	end
	return choice
end

function Setup.MarkSeen()
	local Store = ns.Store
	if Store.IsLoaded() then
		Store.Account().setupSeen = true
	end
end

local function writeLayout(name)
	local positions = Layouts.Get(name)
	local stored = ns.Store.Layout()
	local Layout = ns.Layout
	local live = Layout and type(Layout.Get) == "function" and type(Layout.Update) == "function"
	local moved, saved = 0, 0
	for key, position in pairs(positions) do
		local done = false
		if live and Layout.Get(key) ~= nil then
			local ok, updated = pcall(Layout.Update, key, position, "setup")
			done = ok and updated == true
			if not done then
				log("Layout.Update(" .. key .. ") refused the position (" .. tostring(updated) .. "); saved it for the reload instead")
			end
		end
		if done then
			moved = moved + 1
		else
			local entry = stored[key]
			if type(entry) ~= "table" then
				entry = {}
				stored[key] = entry
			end
			entry.anchor, entry.x, entry.y = position.anchor, position.x, position.y
			saved = saved + 1
		end
	end
	return moved, saved
end

function Setup.Apply(picked)
	local Store = ns.Store
	if not Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return false
	end
	if type(picked) ~= "table" or not Layouts.Get(picked.layout) then
		log("Apply refused an unknown layout " .. tostring(picked and picked.layout))
		return false
	end
	local on, off = {}, {}
	local modules = type(picked.modules) == "table" and picked.modules or {}
	for _, entry in ipairs(PICKER) do
		local name = entry.name
		if Setup.Available(name) then
			local value = modules[name] == true
			ns.Options.Write(name, "enabled", value)
			local list = value and on or off
			list[#list + 1] = name
		end
	end
	local moved, saved = writeLayout(picked.layout)
	Setup.MarkSeen()
	log("applied layout " .. picked.layout .. ": " .. moved .. " elements moved now, " .. saved .. " saved for the reload; on: "
		.. (#on > 0 and table.concat(on, ", ") or "none") .. "; off: " .. (#off > 0 and table.concat(off, ", ") or "none"))
	return true
end

function Setup.Open()
	if not ns.Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return false
	end
	choice = Setup.NewChoice()
	local show = Setup.ShowWindow
	if type(show) ~= "function" then
		ns.Print(L["The first-run setup is not available yet."])
		return false
	end
	ns.Call(show)
	return true
end

function Setup.Closed(applied)
	Setup.MarkSeen()
	if not applied then
		ns.Print(L["You can run the setup again at any time with /kstyle setup."])
	end
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", function()
	ns.Events.Unregister(OWNER, "PLAYER_LOGIN")
	local Store = ns.Store
	if not Store.IsLoaded() or Store.Account().setupSeen then
		return
	end
	log("first login on this account: the setup opens")
	C_Timer.After(OPEN_DELAY, function()
		if not Store.Account().setupSeen and not (Setup.IsShown and Setup.IsShown()) then
			Setup.Open()
		end
	end)
end)
