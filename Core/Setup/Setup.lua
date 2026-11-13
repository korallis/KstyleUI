-- Setup.lua: the first-run setup's choices, Apply (positions, the layout's module settings, the layout's name, the ornament level and its Edit Mode write, which Try again repeats), and when the setup window opens.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local L = ns.L

local OWNER = "Setup"
local OPEN_DELAY = 2
local DEFAULT_LAYOUT = "DPS"
local DEFAULT_ORNAMENTS = "Full"
local GUIDE_ADDON = "RXPGuides"

local PICKER = {
	{ name = "UnitFrames", label = L["Unit frames"], note = L["Player, target, focus, pet and boss frames."] },
	{ name = "ActionBars", label = L["Action bars"], note = L["Your ability sockets, keybinds and proc glows."] },
	{ name = "Cooldowns", label = L["Cooldown Manager"], note = L["Blizzard's cooldown tracker, over your vitals."] },
	{ name = "GroupFrames", label = L["Group frames"], note = L["Party and raid frames with roles and range fade."] },
	{ name = "Auras", label = L["Buffs and debuffs"], note = L["Your buffs and debuffs on the right rail, under the map."] },
	{ name = "Nameplates", label = L["Nameplates"], note = L["Health, cast bar, threat and debuffs on plates."] },
	{ name = "CombatText", label = L["Combat text"], note = L["Damage and heal numbers on your frames."] },
	{ name = "Minimap", label = L["Minimap"], note = L["A small square map with zone and clock."] },
	{ name = "Chat", label = L["Chat"], note = L["Glass chat with tabs, copy and class colours."] },
	{ name = "Bags", label = L["Bags"], note = L["One combined bag with search and sorting."] },
	{ name = "Tooltips", label = L["Tooltips"], note = L["Glass tooltips with quality and class colours."] },
	{ name = "DataBars", label = L["Data bars"], note = L["XP and reputation bars, micro menu and data strip."] },
	{ name = "Meters", label = L["Meters"], note = L["Damage meter, threat meter and swing timer."] },
	{ name = "Skins", label = L["Window skins"], note = L["KstyleUI styling for Blizzard's windows."] },
	{ name = "QoL", label = L["Quality of life"], note = L["Fast loot, repairs, quest turn-ins and zoom."] },
}

local ORNAMENTS = {
	{ value = "Off", label = L["Off"], note = L["No forged trim. The HUD exactly as it ships."] },
	{ value = "Subtle", label = L["Subtle"], note = L["Thin gilt rails and plain pointed ends on frames, bars and nameplates, with small arrow caps beside the action bars."] },
	{ value = "Full", label = L["Full"], note = L["Forged frames with claws, wings and crests, the portrait band with its pendants and the full action bar tray."] },
}

local choice
local firstRun, kept = false, false

Setup.PICKER = PICKER
Setup.ORNAMENTS = ORNAMENTS

function Setup.Ornament(value)
	for _, entry in ipairs(ORNAMENTS) do
		if entry.value == value then
			return entry
		end
	end
end

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

function Setup.Available(name)
	return registered()[name] == true
end

function Setup.NewChoice()
	local modules = {}
	for _, entry in ipairs(PICKER) do
		modules[entry.name] = Setup.Available(entry.name)
	end
	return { hudStyle = ns.HudStyle.Saved(), layout = DEFAULT_LAYOUT, modules = modules, ornaments = DEFAULT_ORNAMENTS }
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
	local _, rh = Setup.RootSize()
	local positions = Layouts.Get(name, rh)
	for key, size in pairs(Layouts.Sizes(name)) do
		local position = positions[key]
		position.width, position.height = size.width, size.height
	end
	local stored = ns.Store.Layout()
	local Layout = ns.Layout
	local live = Layout and type(Layout.Get) == "function" and type(Layout.Update) == "function"
	local moved, saved = 0, 0
	for key, position in pairs(positions) do
		for _, style in ipairs(Layouts.STYLES) do
			stored[style .. ":" .. key] = nil
		end
		local done = false
		if live and Layout.Get(key) ~= nil then
			local ok, updated = pcall(Layout.Update, key, position, "setup", true)
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
			if position.width then
				entry.width, entry.height = position.width, position.height
			end
			saved = saved + 1
		end
	end
	for _, key in pairs(Layouts.STORY_KEYS) do
		if live and Layout.Get(key) ~= nil and type(Layout.Reset) == "function" then
			Layout.Reset(key)
		else
			stored[key] = nil
		end
	end
	return moved, saved
end

local function lookup(node, path)
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function writeSettings(name)
	local written, skipped = 0, 0
	for _, entry in ipairs(Layouts.Settings(name)) do
		local default
		if Setup.Available(entry.module) then
			default = lookup(ns.Store.Defaults(entry.module), entry.key)
		end
		if default ~= nil and type(default) == type(entry.value) then
			ns.Options.Write(entry.module, entry.key, entry.value)
			written = written + 1
		else
			skipped = skipped + 1
		end
	end
	ns.Options.Write("Layout", "preset", name)
	return written, skipped
end

local function GuideLoaded()
	local addons = C_AddOns
	if type(addons) ~= "table" or type(addons.IsAddOnLoaded) ~= "function" then
		return false
	end
	local ok, loaded = pcall(addons.IsAddOnLoaded, GUIDE_ADDON)
	return ok and loaded == true
end

Setup.GuideLoaded = GuideLoaded

function Setup.RootSize()
	local Layout = ns.Layout
	if Layout and type(Layout.RootSize) == "function" then
		return Layout.RootSize()
	end
	local root = ns.Scale.Root()
	return root:GetWidth(), root:GetHeight()
end

local function Band(spec, rw, rh)
	local Layout = ns.Layout
	local left, bottom, width, height
	if Layout and type(Layout.Rect) == "function" then
		left, bottom, width, height = Layout.Rect(spec.key)
	end
	if not left then
		local right, top
		left, bottom, right, top = Layouts.Rect(spec, spec, rw, rh)
		width, height = right - left, top - bottom
	end
	return { left = left, bottom = bottom, right = left + width, top = bottom + height }
end

function Setup.Story(name, guide)
	local rw, rh = Setup.RootSize()
	local story = Layouts.Story(name, rh, guide)
	if not story then
		return nil
	end
	return { guide = story.guide and Band(story.guide, rw, rh), tracker = Band(story.quests, rw, rh) }
end

local function EditModeChanged()
	if type(Setup.EditModeChanged) == "function" then
		ns.Call(Setup.EditModeChanged)
	end
end

local function WriteEditMode(name)
	Setup.EditMode.Waiting(name)
	ns.Combat.Queue(function()
		Setup.EditMode.Write(name, Setup.Story(name, GuideLoaded()))
		EditModeChanged()
	end)
end

function Setup.RetryEditMode()
	local name = Setup.EditMode.Last().name or Setup.Choice().layout
	if not Layouts.Get(name) then
		return false
	end
	WriteEditMode(name)
	EditModeChanged()
	return true
end

local applying = false

ns.Callbacks.Register("HudStyleChanged", "Setup", function()
	local layout = ns.Layout
	local name = layout and layout.Setting and layout.Setting("preset")
	if applying or not name or Setup.EditMode.ActiveName() ~= name then
		return
	end
	ns.Combat.Queue(function()
		Setup.EditMode.Restyle(name, Setup.Story(name, GuideLoaded()))
	end)
end)

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
	local written, skipped = writeSettings(picked.layout)
	local ornaments = Setup.Ornament(picked.ornaments) and picked.ornaments
	if ornaments then
		ns.Options.Write("Widgets", "ornaments", ornaments)
	end
	local hudStyle = (picked.hudStyle == "frames" or picked.hudStyle == "orbs") and picked.hudStyle
	if hudStyle then
		applying = true
		ns.Call(ns.Options.Write, "HudStyle", "style", hudStyle)
		applying = false
	end
	WriteEditMode(picked.layout)
	Setup.MarkSeen()
	log("applied layout " .. picked.layout .. ": " .. moved .. " elements moved now, " .. saved .. " saved for the reload, "
		.. written .. " module settings written, " .. skipped .. " skipped for modules that did not load; ornaments: " .. (ornaments or "unchanged") .. "; HUD style: " .. (hudStyle or "unchanged") .. "; on: "
		.. (#on > 0 and table.concat(on, ", ") or "none") .. "; off: " .. (#off > 0 and table.concat(off, ", ") or "none"))
	return true
end

function Setup.Open(first)
	if not ns.Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return false
	end
	firstRun, kept = first == true, false
	choice = Setup.NewChoice()
	local show = Setup.ShowWindow
	if type(show) ~= "function" then
		ns.Print(L["The first-run setup is not available yet."])
		return false
	end
	ns.Call(show)
	return true
end

function Setup.IsFirstRun()
	return firstRun
end

function Setup.Keep()
	kept = true
end

function Setup.Closed(applied)
	local defaults = firstRun and not applied and not kept
	firstRun, kept = false, false
	Setup.MarkSeen()
	if defaults then
		local picked = Setup.Choice()
		if Setup.Apply(picked) then
			log("the first-run setup closed without Apply: applied " .. picked.layout .. " with the modules it had on and " .. tostring(picked.ornaments) .. " ornaments")
			ns.Print(string.format(L["KstyleUI applied the %s layout. Type /reload to finish, or /kstyle setup to change it."], Layouts.Label(picked.layout)))
			return
		end
	end
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
			Setup.Open(true)
		end
	end)
end)
