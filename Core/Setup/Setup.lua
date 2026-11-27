-- Setup.lua: the first-run setup's choices, Apply (the HUD style, positions, the layout's module settings, the Look, the controls, the interface size, the arrangement, the layout's name and its Edit Mode write, which Try again repeats), and when the setup window opens.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local L = ns.L
ns.Store.RegisterDefaults("OptionsPresentation", { tasks = true, synonyms = true, preview = true, switches = true, samples = true, columns = true, readableText = true })
ns.Options.Register("OptionsPresentation", function() return {
	{ type = "header", label = L["Settings window"] },
	{ type = "toggle", key = "tasks", label = L["Start with tasks"], help = L["Open settings on six common tasks. Off opens the last module page, as before."] },
	{ type = "toggle", key = "synonyms", label = L["Search in player words"], help = L["Find settings with words like kicks, bigger text and healing clicks. Off matches labels and help."] },
	{ type = "toggle", key = "readableText", label = L["Keep settings text readable"], help = L["Keep text above the reading floor when shrinking this window. Off keeps the previous scaling."] },
	{ type = "toggle", key = "preview", label = L["Larger top-aligned previews"], help = L["Grow small previews up to 160% and place them at the top. Off keeps centred previews at 125%."] },
	{ type = "toggle", key = "switches", label = L["Slim bright switches"], help = L["Use slimmer switches with a clearer On colour. Off restores the taller, dimmer switches."] },
	{ type = "toggle", key = "columns", label = L["Aligned settings headings"], help = L["Line up the category, page and preview headings. Off restores the previous column layout."] },
	{ type = "toggle", key = "samples", label = L["Show ornament samples"], help = L["Compare Off, Subtle and Full before choosing. Off keeps the text-only ornament picker."], showWhen = function() return ns.HudStyle.Current() == "frames" end },
} end)
ns.Store.RegisterDefaults("Setup", { closeBehaviour = "apply", replaceLayout = true, layoutPictures = true, readableNotes = true, bigPictures = true, looks = true, controls = true })
ns.Options.Register("Setup", function() return {
	{ type = "header", label = L["Setup"] },
	{ type = "toggle", key = "layoutPictures", label = L["Layout pictures in setup"], help = L["Show DPS, Tank and Healer pictures for your chosen HUD. Off restores the footprint diagram."] },
	{ type = "toggle", key = "bigPictures", label = L["Big pictures in setup"], help = L["One large picture of the layout you point at; arrangements on wide screens. Off: small pictures."] },
	{ type = "toggle", key = "looks", label = L["One-click Looks"], help = L["Forged, Clean and Readable looks in setup and on this page. Off hides them; your settings stay."] },
	{ type = "toggle", key = "controls", label = L["Keyboard or gamepad bars"], help = L["The Keyboard and Gamepad bar choice in setup and on this page. Off hides it; your settings stay."] },
	{ type = "toggle", key = "readableNotes", label = L["Readable setup notes"], help = L["Use wrapping 11-unit notes in setup. Off restores the smaller, single-line module notes."] },
	{ type = "dropdown", key = "closeBehaviour", label = L["Closing the setup window"], help = L["Choose whether first-run Close or Escape leaves your UI alone or applies the setup."], options = {
		{ value = "apply", label = L["Apply the default setup"] },
		{ value = "later", label = L["Do nothing, ask again later"] },
	} },
	{ type = "toggle", key = "replaceLayout", label = L["Choose an Edit Mode replacement"], help = L["When all layouts are full, choose one to replace. Off keeps the previous full-list message."] },
} end)

local OWNER = "Setup"
local OPEN_DELAY = 2
local DEFAULT_LAYOUT = "DPS"
local GUIDE_ADDONS = { RXPGuides = true }

local PICKER = {
	{ name = "UnitFrames", label = L["Unit frames"], note = L["Player, target, focus, pet and boss frames."] },
	{ name = "ActionBars", label = L["Action bars"], note = L["Your ability sockets, keybinds and proc glows."] },
	{ name = "Cooldowns", label = L["Cooldown Manager"], note = L["Blizzard's cooldown tracker, over your vitals."] },
	{ name = "GroupFrames", label = L["Group frames"], note = L["Party and raid frames with roles and range fade."] },
	{ name = "Auras", label = L["Buffs and debuffs"], note = L["Your buffs and debuffs, under the map."] },
	{ name = "Nameplates", label = L["Nameplates"], note = L["Health, cast bar, threat and debuffs on plates."] },
	{ name = "CombatText", label = L["Combat text"], note = L["Damage and heal numbers on your frames."] },
	{ name = "Minimap", label = L["Minimap"], note = L["A small round map with zone and clock."] },
	{ name = "Chat", label = L["Chat"], note = L["Glass chat with tabs, copy and class colours."] },
	{ name = "Bags", label = L["Bags"], note = L["One combined bag with search and sorting."] },
	{ name = "Tooltips", label = L["Tooltips"], note = L["Glass tooltips with quality and class colours."] },
	{ name = "DataBars", label = L["Data bars"], note = L["XP, reputation, micro menu and data strip."] },
	{ name = "Meters", label = L["Meters"], note = L["Damage meter, threat meter and swing timer."] },
	{ name = "Skins", label = L["Window skins"], note = L["KstyleUI styling for Blizzard's windows."] },
	{ name = "QoL", label = L["Quality of life"], note = L["Fast loot, repairs, quest turn-ins and zoom."] },
}

local choice
local firstRun, kept = false, false

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

function Setup.Available(name)
	return registered()[name] == true
end

function Setup.NewChoice(current)
	local modules, overlapping = {}, {}
	local addons, settings = Setup.Integrations.Addons(), {}
	for _, addon in ipairs(addons) do
		for _, row in ipairs(addon.rows) do
			if row.key == "enabled" then overlapping[row.module] = true end
		end
	end
	for _, entry in ipairs(PICKER) do
		local overlaps = overlapping[entry.name] == true or #Setup.Integrations.Detected(entry.name) > 0
		modules[entry.name] = Setup.Available(entry.name) and (entry.name == "Skins" or entry.name == "DataBars" or entry.name == "Meters" or not overlaps)
		if current and (overlaps or entry.name == "Skins") and Setup.Available(entry.name) then modules[entry.name] = ns.Modules.IsEnabled(entry.name) end
	end
	for _, addon in ipairs(addons) do
		for _, row in ipairs(addon.rows) do
			if row.key ~= "enabled" then
				local value = ns.Options.Read(row.module, row.key)
				if not current and (row.module == "DataBars" or row.module == "Meters" or row.module == "Integrations") then value = row.recommended end
				settings[row.module .. "." .. row.key] = value
			end
		end
	end
	return { hudStyle = ns.HudStyle.Saved(), layout = DEFAULT_LAYOUT, modules = modules, addons = addons, addonSettings = settings }
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
	local positions = Layouts.Positions(name, "frames", ns.Scale.Aspect(), ns.Scale.Band())
	local defaults = Layouts.Positions("DPS", "frames", ns.Scale.Aspect(), ns.Scale.Band())
	positions["databars.strip"] = Layouts.Default("databars.strip")
	defaults["databars.strip"] = Layouts.Default("databars.strip")
	for key, size in pairs(Layouts.Sizes(name)) do
		local position = positions[key]
		position.width, position.height = size.width, size.height
	end
	local stored = ns.Store.Layout()
	local Layout = ns.Layout
	local live = Layout and type(Layout.Get) == "function" and type(Layout.Update) == "function"
	local moved, saved = 0, 0
	for key, position in pairs(positions) do
		stored["medallions:" .. key] = nil
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
			local default = defaults[key]
			if position.anchor ~= default.anchor or position.x ~= default.x or position.y ~= default.y then
				entry.anchor, entry.x, entry.y = position.anchor, position.x, position.y
			else
				entry.anchor, entry.x, entry.y = nil, nil, nil
			end
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
			local value = entry.value
			if entry.module == "DataBars" and entry.key == "strip.menus" then
				value = value and ns.Store.Module("DataBars").strip.placement ~= "rail"
			end
			ns.Options.Write(entry.module, entry.key, value)
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
	for addon in pairs(GUIDE_ADDONS) do
		local ok, loaded = pcall(addons.IsAddOnLoaded, addon)
		if ok and loaded == true then
			return true
		end
	end
	return false
end

Setup.GuideLoaded = GuideLoaded

function Setup.RegisterGuide(addon)
	if type(addon) == "string" then
		GUIDE_ADDONS[addon] = true
	end
end

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
	local story = Layouts.Story(name, rh, guide, rw)
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

local function WriteEditMode(name, replace)
	Setup.EditMode.Waiting(name)
	ns.Combat.Queue(function()
		Setup.EditMode.Write(name, Setup.Story(name, GuideLoaded()), replace)
		EditModeChanged()
	end)
end

function Setup.RetryEditMode()
	local name = Setup.EditMode.Last().name or Setup.Choice().layout
	if not Layouts.Get(name) then
		return false
	end
	WriteEditMode(name, Setup.Choice().replaceLayout)
	EditModeChanged()
	return true
end

local applying = false

local function Restyle(stamped)
	local layout = ns.Layout
	local name = layout and layout.Setting and layout.Setting("preset")
	if applying or not name or Setup.EditMode.ActiveName() ~= name then
		return
	end
	ns.Combat.Queue(function()
		Setup.EditMode.Restyle(name, Setup.Story(name, GuideLoaded()), stamped)
	end)
end

ns.Callbacks.Register("HudStyleChanged", "Setup", function() Restyle() end)
ns.Callbacks.Register("SettingChanged", "Setup", function(_, module, key)
	if Layouts.LiftSetting(module, key) then Restyle() end
end)

local function Screen()
	if type(GetPhysicalScreenSize) == "function" then return GetPhysicalScreenSize() end
end

local aspect, band, lane, factor = ns.Scale.Aspect(), ns.Scale.Band(), nil, Setup.EditMode.Factor()
local rootWidth, rootHeight
local screenWidth, screenHeight = Screen()
ns.Callbacks.Register("ScaleChanged", "Setup", function()
	local width, k = Setup.EditMode.WarningLane(), Setup.EditMode.Factor()
	local rw, rh = Setup.RootSize()
	local sw, sh = Screen()
	local rescaled = math.abs(k - factor) > 1e-3 or (rootWidth and (math.abs(rw - rootWidth) > 0.5 or math.abs(rh - rootHeight) > 0.5))
	local resized = sw ~= screenWidth or sh ~= screenHeight
	factor, rootWidth, rootHeight, screenWidth, screenHeight = k, rw, rh, sw, sh
	if rescaled or ns.Scale.Aspect() ~= aspect or ns.Scale.Band() ~= band or (lane and width ~= lane) then
		aspect, band = ns.Scale.Aspect(), ns.Scale.Band()
		Restyle(rescaled and not resized)
	end
	lane = width
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
	local backed, why = ns.Profiles.Backup(L["Before setup"])
	if not backed then
		ns.Print(tostring(why))
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
	for path, value in pairs(picked.addonSettings or {}) do
		local module, key = path:match("^([^%.]+)%.(.+)$")
		ns.Options.Write(module, key, value)
	end
	local setup = ns.Store.Module("Setup")
	if setup.looks and picked.look then Setup.Looks.Apply(picked.look) end
	if setup.controls and picked.controls then Setup.Looks.ApplyControls(picked.controls) end
	if picked.uiScale then Setup.Looks.ApplySize(picked.uiScale) end
	if setup.layoutPictures and setup.bigPictures and ns.Scale.ARRANGEMENT[picked.arrangement] and picked.arrangement ~= ns.Scale.Arrangement() then ns.Options.Write("Layout", "arrangement", picked.arrangement) end
	local hudStyle = ns.HudStyle.Valid(picked.hudStyle) and picked.hudStyle
	if hudStyle then
		applying = true
		ns.Call(ns.Options.Write, "HudStyle", "style", hudStyle)
		applying = false
	end
	WriteEditMode(picked.layout, picked.replaceLayout)
	local nameplates = Store.Defaults("Nameplates")
	if nameplates and type(nameplates.personalResource) == "boolean" then
		ns.Options.Write("Nameplates", "personalResource", false)
	end
	Setup.MarkSeen()
	log("applied layout " .. picked.layout .. ": " .. moved .. " elements moved now, " .. saved .. " saved for the reload, "
		.. written .. " module settings written, " .. skipped .. " skipped for modules that did not load; HUD style: " .. (hudStyle or "unchanged") .. "; on: "
		.. (#on > 0 and table.concat(on, ", ") or "none") .. "; off: " .. (#off > 0 and table.concat(off, ", ") or "none"))
	return true
end

function Setup.Open(first)
	if not ns.Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return false
	end
	firstRun, kept = first == true, false
	choice = Setup.NewChoice(first ~= true)
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
	local first, keep = firstRun, kept
	firstRun, kept = false, false
	if first and not applied and not keep and ns.Store.Module("Setup").closeBehaviour == "apply" then
		if Setup.Apply(Setup.Choice()) then
			ns.Print(string.format(L["KstyleUI applied the %s layout. Type /reload to finish, or /kstyle setup to change it."], Layouts.Label(Setup.Choice().layout)))
			return
		end
	end
	if applied or keep or not first then Setup.MarkSeen() end
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
